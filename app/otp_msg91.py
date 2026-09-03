# app/otp_msg91.py
import os
import re
import time
import json
import urllib.request
import urllib.parse
import urllib.error

MSG91_SEND_OTP_URL = "https://control.msg91.com/api/v5/otp"
MSG91_VERIFY_OTP_URL = "https://control.msg91.com/api/v5/otp/verify"
MSG91_RETRY_OTP_URL = "https://control.msg91.com/api/v5/otp/retry"
MSG91_VERIFY_ACCESS_TOKEN_URL = "https://control.msg91.com/api/v5/widget/verifyAccessToken"

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

def _http_request(url, method='GET', headers=None, body=None, params=None, timeout=12):
    if params:
        query_string = urllib.parse.urlencode(params)
        url = f"{url}?{query_string}" if '?' not in url else f"{url}&{query_string}"

    req_headers = headers or {}
    data = None
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        req_headers['Content-Type'] = 'application/json'

    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            status_code = response.getcode()
            content = response.read().decode('utf-8')
            try:
                parsed_json = json.loads(content)
            except Exception:
                parsed_json = {"raw": content}
            return status_code, parsed_json
    except urllib.error.HTTPError as e:
        error_content = e.read().decode('utf-8') if e.fp else ''
        try:
            parsed_json = json.loads(error_content)
        except Exception:
            parsed_json = {"error": error_content or str(e)}
        return e.code, parsed_json
    except Exception as e:
        return 500, {"error": str(e)}

def verify_msg91_access_token(access_token):
    """
    Verifies MSG91 Widget JWT Access Token server-side via MSG91 official endpoint.
    POST https://control.msg91.com/api/v5/widget/verifyAccessToken
    Payload: { "authkey": "<MSG91_AUTHKEY>", "access-token": "<access_token>" }
    """
    token = str(access_token or '').strip()
    if not token:
        return {
            "success": False,
            "message": "Access token is required."
        }, 400

    auth_key = os.environ.get('MSG91_AUTH_KEY', '').strip()
    if not auth_key:
        return {
            "success": False,
            "message": "MSG91 SMS provider is not configured on the production server (Missing MSG91_AUTH_KEY)."
        }, 503

    payload = {
        "authkey": auth_key,
        "access-token": token
    }
    headers = {
        "Content-Type": "application/json"
    }

    status_code, data = _http_request(MSG91_VERIFY_ACCESS_TOKEN_URL, method='POST', headers=headers, body=payload, timeout=12)

    if status_code == 200 and (data.get('type') == 'success' or 'success' in data.get('message', '').lower()):
        token_data = data.get('data') or data
        mobile = token_data.get('mobile') or token_data.get('mobile_number') or token_data.get('phone') or data.get('mobile')
        
        normalized_msg91, e164 = normalize_indian_phone(mobile) if mobile else (None, None)
        
        return {
            "success": True,
            "message": "MSG91 access token verified successfully.",
            "phone": e164 or mobile,
            "data": token_data
        }, 200
    else:
        err_msg = data.get('message') or data.get('error') or "Invalid or expired MSG91 access token."
        return {
            "success": False,
            "message": f"MSG91 token verification failed: {err_msg}"
        }, 401

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
    otp_expiry = os.environ.get('MSG91_OTP_EXPIRY', '5').strip()
    otp_length = os.environ.get('MSG91_OTP_LENGTH', '6').strip()

    if not auth_key:
        # Honest reporting: MSG91 is unconfigured on server
        return {
            "success": False,
            "message": "MSG91 SMS provider is not configured on the production server (Missing MSG91_AUTH_KEY in environment variables)."
        }, 503

    headers = {
        "authkey": auth_key
    }
    
    payload = {
        "mobile": msg91,
        "otp_expiry": otp_expiry,
        "otp_length": int(otp_length) if otp_length.isdigit() else 6
    }
    if template_id:
        payload["template_id"] = template_id

    status_code, data = _http_request(MSG91_SEND_OTP_URL, method='POST', headers=headers, body=payload, timeout=10)

    if status_code == 200 and (data.get('type') == 'success' or 'successfully' in data.get('message', '').lower()):
        _rate_limits[msg91] = now
        _attempt_tracker[msg91] = 0
        return {
            "success": True,
            "message": f"OTP sent successfully via SMS to {e164}.",
            "phone": e164
        }, 200
    else:
        err_msg = data.get('message') or data.get('error') or f"MSG91 error code {status_code}"
        return {
            "success": False,
            "message": f"Failed to deliver SMS: {err_msg}"
        }, 400

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
        "otp": otp
    }
    headers = {
        "authkey": auth_key
    }

    status_code, data = _http_request(MSG91_VERIFY_OTP_URL, method='GET', headers=headers, params=params, timeout=10)

    if status_code == 200 and (data.get('type') == 'success' or 'success' in data.get('message', '').lower()):
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
        "retrytype": "text"
    }
    headers = {
        "authkey": auth_key
    }

    status_code, data = _http_request(MSG91_RETRY_OTP_URL, method='GET', headers=headers, params=params, timeout=10)

    if status_code == 200 and (data.get('type') == 'success' or 'successfully' in data.get('message', '').lower()):
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
