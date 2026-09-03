# app/otp_msg91.py
import os
import re
import time
import requests

MSG91_SEND_OTP_URL = "https://control.msg91.com/api/v5/otp"
MSG91_VERIFY_OTP_URL = "https://control.msg91.com/api/v5/otp/verify"
MSG91_RETRY_OTP_URL = "https://control.msg91.com/api/v5/otp/retry"

# In-memory rate limiting and attempt tracking
_rate_limits = {}
_attempt_tracker = {}

def normalize_indian_phone(raw_phone):
    """
    Normalizes mobile numbers into MSG91 format (91XXXXXXXXXX)
    Accepts: '9876543210', '+919876543210', '919876543210', '09876543210'
    Returns: tuple (normalized_for_msg91: '919876543210', e164_format: '+919876543210')
    """
    if not raw_phone:
        return None, None
    digits = re.sub(r'\D', '', str(raw_phone).strip())
    
    # 10-digit local number (e.g. 9876543210)
    if len(digits) == 10:
        return f"91{digits}", f"+91{digits}"
    # 11-digit with leading 0 (e.g. 09876543210)
    elif len(digits) == 11 and digits.startswith('0'):
        ten_digits = digits[1:]
        return f"91{ten_digits}", f"+91{ten_digits}"
    # 12-digit starting with 91 (e.g. 919876543210)
    elif len(digits) == 12 and digits.startswith('91'):
        return digits, f"+{digits}"
    
    return None, None

def send_msg91_otp(raw_phone):
    """
    Dispatches production SMS OTP via MSG91 official Send OTP v5 API.
    Does NOT generate local OTPs or expose secrets to client.
    """
    msg91, e164 = normalize_indian_phone(raw_phone)
    if not msg91:
        return {
            "success": False,
            "message": "Invalid mobile number. Please enter a valid 10-digit Indian mobile number."
        }, 400

    now = time.time()
    last_sent = _rate_limits.get(msg91, 0)
    if (now - last_sent) < 30:
        remaining = int(30 - (now - last_sent))
        return {
            "success": False,
            "message": f"Please wait {remaining}s before requesting a new OTP.",
            "cooldown_remaining": remaining
        }, 429

    auth_key = os.environ.get('MSG91_AUTH_KEY', '').strip()
    template_id = os.environ.get('MSG91_TEMPLATE_ID', '').strip()
    otp_expiry = os.environ.get('MSG91_OTP_EXPIRY', '5').strip() # minutes (or seconds per MSG91 config)
    otp_length = os.environ.get('MSG91_OTP_LENGTH', '6').strip()

    if not auth_key or not template_id:
        # Honest reporting: MSG91 is unconfigured on server
        return {
            "success": False,
            "message": "MSG91 SMS provider is not configured on the production server (Missing MSG91_AUTH_KEY or MSG91_TEMPLATE_ID in environment variables)."
        }, 503

    headers = {
        "authkey": auth_key,
        "Content-Type": "application/json"
    }
    
    payload = {
        "template_id": template_id,
        "mobile": msg91,
        "otp_expiry": otp_expiry,
        "otp_length": int(otp_length) if otp_length.isdigit() else 6
    }

    try:
        response = requests.post(MSG91_SEND_OTP_URL, json=payload, headers=headers, timeout=10)
        data = response.json() if response.content else {}
        
        # Check MSG91 response status
        if response.status_code == 200 and (data.get('type') == 'success' or 'successfully' in data.get('message', '').lower()):
            _rate_limits[msg91] = now
            # Reset attempts
            _attempt_tracker[msg91] = 0
            return {
                "success": True,
                "message": f"OTP sent successfully via SMS to {e164}.",
                "phone": e164
            }, 200
        else:
            err_msg = data.get('message') or data.get('error') or f"MSG91 error code {response.status_code}"
            return {
                "success": False,
                "message": f"Failed to deliver SMS: {err_msg}"
            }, 400
    except requests.exceptions.Timeout:
        return {
            "success": False,
            "message": "SMS provider timed out while attempting to dispatch SMS. Please try again."
        }, 504
    except Exception as e:
        return {
            "success": False,
            "message": f"SMS provider request failed: {str(e)}"
        }, 502

def verify_msg91_otp(raw_phone, otp_code):
    """
    Verifies SMS OTP with MSG91 official Verify OTP v5 API.
    """
    msg91, e164 = normalize_indian_phone(raw_phone)
    if not msg91:
        return {
            "success": False,
            "message": "Invalid mobile number."
        }, 400

    otp = str(otp_code or '').strip()
    if not otp or len(otp) != 6:
        return {
            "success": False,
            "message": "Please enter the complete 6-digit OTP code."
        }, 400

    # Rate limiting on failed verification attempts
    attempts = _attempt_tracker.get(msg91, 0)
    if attempts >= 5:
        return {
            "success": False,
            "message": "Too many failed attempts for this number. Please request a new OTP."
        }, 429

    auth_key = os.environ.get('MSG91_AUTH_KEY', '').strip()
    if not auth_key:
        return {
            "success": False,
            "message": "MSG91 SMS provider is not configured on the production server (Missing MSG91_AUTH_KEY)."
        }, 503

    params = {
        "mobile": msg91,
        "otp": otp,
        "authkey": auth_key
    }

    try:
        response = requests.get(MSG91_VERIFY_OTP_URL, params=params, timeout=10)
        data = response.json() if response.content else {}

        if response.status_code == 200 and (data.get('type') == 'success' or 'success' in data.get('message', '').lower()):
            # Verification successful
            _attempt_tracker.pop(msg91, None)
            return {
                "success": True,
                "message": "OTP verified successfully.",
                "phone": e164,
                "msg91_phone": msg91
            }, 200
        else:
            _attempt_tracker[msg91] = attempts + 1
            remaining = 5 - (attempts + 1)
            err_msg = data.get('message', 'Incorrect OTP code. Please check your SMS and try again.')
            return {
                "success": False,
                "message": f"{err_msg} ({remaining} attempts remaining)."
            }, 400
    except requests.exceptions.Timeout:
        return {
            "success": False,
            "message": "SMS provider timed out during verification. Please check your connection."
        }, 504
    except Exception as e:
        return {
            "success": False,
            "message": f"Verification failed: {str(e)}"
        }, 502

def retry_msg91_otp(raw_phone):
    """
    Retries SMS delivery via MSG91 Retry API.
    """
    msg91, e164 = normalize_indian_phone(raw_phone)
    if not msg91:
        return {
            "success": False,
            "message": "Invalid mobile number."
        }, 400

    now = time.time()
    last_sent = _rate_limits.get(msg91, 0)
    if (now - last_sent) < 30:
        remaining = int(30 - (now - last_sent))
        return {
            "success": False,
            "message": f"Please wait {remaining}s before resending OTP.",
            "cooldown_remaining": remaining
        }, 429

    auth_key = os.environ.get('MSG91_AUTH_KEY', '').strip()
    if not auth_key:
        return {
            "success": False,
            "message": "MSG91 SMS provider is not configured on the production server."
        }, 503

    params = {
        "mobile": msg91,
        "retrytype": "text",
        "authkey": auth_key
    }

    try:
        response = requests.get(MSG91_RETRY_OTP_URL, params=params, timeout=10)
        data = response.json() if response.content else {}

        if response.status_code == 200 and (data.get('type') == 'success' or 'successfully' in data.get('message', '').lower()):
            _rate_limits[msg91] = now
            return {
                "success": True,
                "message": f"New OTP sent successfully to {e164}."
            }, 200
        else:
            return {
                "success": False,
                "message": data.get('message', 'Failed to resend OTP via MSG91.')
            }, 400
    except Exception as e:
        return {
            "success": False,
            "message": f"Resend request failed: {str(e)}"
        }, 502
