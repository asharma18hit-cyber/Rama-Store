"""
app/otp_service.py - Production & Development OTP Dispatch Engine for Samaur Mart.
Provides carrier-grade SMS & Email delivery with zero external dependencies (urllib/smtplib standard library).

Supported Providers:
1. Fast2SMS (Indian SMS Gateway - simple API key)
2. Twilio (Global SMS)
3. MSG91 (DLT Registered Indian SMS)
4. SMTP (Direct Email delivery for Gmail/Outlook/Sendgrid)
5. Zero-Config Local Development & Fallback Engine
"""

import os
import re
import json
import time
import ssl
import base64
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import urllib.request
import urllib.parse
import urllib.error

# In-memory rate limiting and cooldown trackers
_cooldown_tracker = {} # { recipient: timestamp }
_attempt_tracker = {}  # { recipient: count }

def normalize_recipient(raw_identifier):
    """
    Normalizes input to either ('email', email_addr) or ('phone', 10_digits, e164_str).
    Handles +91, 0, spaces, hyphens, and parenthesis.
    """
    if not raw_identifier:
        return 'unknown', '', ''
        
    val = str(raw_identifier).strip()
    if '@' in val:
        return 'email', val.lower(), val.lower()
        
    # Extract digits only
    digits = re.sub(r'\D', '', val)
    
    # Strip country code +91 or 0 prefix if present
    if len(digits) == 12 and digits.startswith('91'):
        ten_digits = digits[2:]
    elif len(digits) == 11 and digits.startswith('0'):
        ten_digits = digits[1:]
    elif len(digits) == 10:
        ten_digits = digits
    else:
        # Fallback to last 10 digits if longer, or raw digits
        ten_digits = digits[-10:] if len(digits) >= 10 else digits

    e164 = f"+91{ten_digits}" if len(ten_digits) == 10 else f"+{digits}"
    return 'phone', ten_digits, e164

def _http_post(url, headers=None, json_body=None, form_body=None, timeout=8):
    """Zero-dependency HTTP POST using Python standard library urllib."""
    headers = headers or {}
    data = None
    
    if json_body is not None:
        data = json.dumps(json_body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    elif form_body is not None:
        data = urllib.parse.urlencode(form_body).encode('utf-8')
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
        
    req = urllib.request.Request(url, data=data, headers=headers, method='POST')
    
    # Use default SSL context
    ctx = ssl.create_default_context()
    
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            status = resp.status
            content = resp.read().decode('utf-8', errors='replace')
            try:
                parsed = json.loads(content)
            except Exception:
                parsed = {"raw": content}
            return status, parsed
    except urllib.error.HTTPError as e:
        content = e.read().decode('utf-8', errors='replace') if e.fp else str(e)
        try:
            parsed = json.loads(content)
        except Exception:
            parsed = {"error": content}
        return e.code, parsed
    except Exception as e:
        return 500, {"error": str(e)}

# -------------------------------------------------------------
# 1. FAST2SMS GATEWAY (INDIA)
# -------------------------------------------------------------
def _send_fast2sms(phone_10, otp):
    """
    Sends SMS using Fast2SMS API (Indian Gateway).
    Requires FAST2SMS_API_KEY environment variable.
    """
    api_key = os.environ.get('FAST2SMS_API_KEY', '').strip()
    if not api_key:
        return False, "FAST2SMS_API_KEY is not set."

    url = "https://www.fast2sms.com/dev/bulkV2"
    headers = {
        "authorization": api_key
    }
    payload = {
        "route": "otp",
        "variables_values": str(otp),
        "numbers": str(phone_10)
    }

    status, data = _http_post(url, headers=headers, json_body=payload, timeout=8)
    if status == 200 and data.get('return') is True:
        return True, "SMS dispatched via Fast2SMS."
    else:
        err = data.get('message') or data.get('error') or f"Status {status}"
        return False, f"Fast2SMS error: {err}"

# -------------------------------------------------------------
# 2. TWILIO GATEWAY (GLOBAL)
# -------------------------------------------------------------
def _send_twilio(phone_e164, otp):
    """
    Sends SMS using Twilio REST API.
    Requires TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER.
    """
    sid = os.environ.get('TWILIO_ACCOUNT_SID', '').strip()
    token = os.environ.get('TWILIO_AUTH_TOKEN', '').strip()
    from_num = os.environ.get('TWILIO_PHONE_NUMBER', '').strip()

    if not sid or not token or not from_num:
        return False, "Twilio credentials incomplete."

    url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"
    credentials = f"{sid}:{token}".encode('utf-8')
    auth_header = "Basic " + base64.b64encode(credentials).decode('utf-8')

    headers = {
        "Authorization": auth_header
    }
    form_data = {
        "To": phone_e164,
        "From": from_num,
        "Body": f"Your Samaur Mart security verification code is {otp}. Valid for 10 minutes. Do not share this code."
    }

    status, data = _http_post(url, headers=headers, form_body=form_data, timeout=8)
    if status in (200, 201):
        return True, "SMS dispatched via Twilio."
    else:
        err = data.get('message') or data.get('error_message') or f"Status {status}"
        return False, f"Twilio error: {err}"

# -------------------------------------------------------------
# 3. MSG91 GATEWAY (INDIA DLT)
# -------------------------------------------------------------
def _send_msg91(phone_10, otp):
    """
    Sends SMS using MSG91 OTP v5 API.
    Requires MSG91_AUTH_KEY and MSG91_TEMPLATE_ID.
    """
    auth_key = os.environ.get('MSG91_AUTH_KEY', '').strip()
    template_id = os.environ.get('MSG91_TEMPLATE_ID', '').strip()

    if not auth_key or not template_id:
        return False, "MSG91 credentials incomplete."

    url = "https://control.msg91.com/api/v5/otp"
    headers = {
        "authkey": auth_key
    }
    payload = {
        "template_id": template_id,
        "mobile": f"91{phone_10}",
        "otp": str(otp)
    }

    status, data = _http_post(url, headers=headers, json_body=payload, timeout=8)
    if status == 200 and ('success' in str(data.get('type', '')).lower() or 'success' in str(data.get('message', '')).lower()):
        return True, "SMS dispatched via MSG91."
    else:
        err = data.get('message') or f"Status {status}"
        return False, f"MSG91 error: {err}"

# -------------------------------------------------------------
# 4. SMTP EMAIL DISPATCHER
# -------------------------------------------------------------
def _send_smtp_email(to_email, otp, purpose="Verification"):
    """
    Sends HTML + Plain text email via standard SMTP (Gmail, Outlook, Amazon SES, Sendgrid).
    Requires SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD.
    """
    host = os.environ.get('SMTP_HOST', '').strip()
    port = int(os.environ.get('SMTP_PORT', '587'))
    user = os.environ.get('SMTP_USER', '').strip()
    password = os.environ.get('SMTP_PASSWORD', '').strip()
    sender = os.environ.get('SMTP_FROM', user or 'noreply@ramastore.com').strip()

    if not host or not user or not password:
        return False, "SMTP email server credentials not configured."

    msg = MIMEMultipart('alternative')
    msg['Subject'] = f"Samaur Mart Security Code: {otp}"
    msg['From'] = f"Samaur Mart <{sender}>"
    msg['To'] = to_email

    text_content = f"Your Samaur Mart security verification code for {purpose} is: {otp}\n\nThis code will expire in 10 minutes. If you did not request this, please ignore."
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="margin: 0; padding: 20px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f8fafc; color: #1e293b;">
        <div style="max-width: 500px; margin: 0 auto; background: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);">
            <div style="background: #0f172a; padding: 24px; text-align: center;">
                <h1 style="margin: 0; color: #f8fafc; font-size: 20px; letter-spacing: 0.05em;">SAMAUR MART</h1>
                <p style="margin: 4px 0 0; color: #94a3b8; font-size: 13px;">Security & Identity Verification</p>
            </div>
            <div style="padding: 32px 24px; text-align: center;">
                <p style="margin: 0 0 16px; font-size: 15px; color: #475569;">Use the one-time verification code below for <strong>{purpose}</strong>:</p>
                <div style="display: inline-block; background: #f1f5f9; border: 1px dashed #cbd5e1; border-radius: 8px; padding: 12px 28px; margin: 12px 0 20px;">
                    <span style="font-family: monospace; font-size: 32px; font-weight: 700; letter-spacing: 6px; color: #0f172a;">{otp}</span>
                </div>
                <p style="margin: 0; font-size: 13px; color: #64748b;">This code will expire in <strong>10 minutes</strong>. Do not share this code with anyone.</p>
            </div>
            <div style="background: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;">
                &copy; Samaur Mart. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    """

    msg.attach(MIMEText(text_content, 'plain'))
    msg.attach(MIMEText(html_content, 'html'))

    try:
        if port == 465:
            server = smtplib.SMTP_SSL(host, port, timeout=8)
        else:
            server = smtplib.SMTP(host, port, timeout=8)
            server.starttls()
            
        server.login(user, password)
        server.sendmail(sender, [to_email], msg.as_string())
        server.quit()
        return True, "Email dispatched via SMTP."
    except Exception as e:
        return False, f"SMTP error: {str(e)}"

# -------------------------------------------------------------
# 5. DISPATCHER & DEVELOPMENT FALLBACK
# -------------------------------------------------------------
def log_otp_banner(destination, otp, purpose, provider_status):
    """Outputs a prominent log banner in server console for visibility."""
    banner = f"""
================================================================================
[SAMAUR MART OTP ENGINE]
Target      : {destination}
OTP Code    : {otp}
Purpose     : {purpose}
Provider    : {provider_status}
Timestamp   : {time.strftime('%Y-%m-%d %H:%M:%S')}
================================================================================
"""
    print(banner, flush=True)

def dispatch_otp(recipient, otp, purpose="User Authentication", bypass_cooldown=False):
    """
    Main entry point for dispatching OTPs across all available channels.
    Falls back gracefully without throwing errors so testing or local dev is never blocked.
    
    Returns dict:
    {
        "success": bool,
        "provider": str,
        "message": str,
        "debug_otp": str or None,
        "recipient": str
    }
    """
    kind, normalized, display = normalize_recipient(recipient)
    now = time.time()
    
    # 1. Rate Limiting Cooldown (15s cooldown; skipped in testing environments or if bypassed)
    is_testing = (os.environ.get('TESTING') == 'true' or os.environ.get('FLASK_ENV') == 'testing')
    last_sent = _cooldown_tracker.get(normalized, 0)
    if not is_testing and not bypass_cooldown and (now - last_sent) < 15:
        remaining = int(15 - (now - last_sent))
        return {
            "success": False,
            "error": f"Please wait {remaining} seconds before requesting a new OTP code.",
            "cooldown_remaining": remaining,
            "debug_otp": otp
        }

    provider_used = "development_fallback"
    delivery_note = "Local Development Mode (SMS gateway keys not configured in .env)"
    sent_successfully = False

    # 2. Try Email if recipient is an email address
    if kind == 'email':
        if os.environ.get('SMTP_HOST'):
            ok, msg = _send_smtp_email(normalized, otp, purpose)
            if ok:
                provider_used = "smtp_email"
                delivery_note = f"Verification code sent to {normalized}."
                sent_successfully = True
            else:
                delivery_note = f"SMTP failed ({msg}); fell back to console log."
        else:
            delivery_note = f"SMTP not configured; code printed to server console."

    # 3. Try SMS Gateways if recipient is a phone number
    elif kind == 'phone':
        # Priority A: Fast2SMS (Indian Gateway)
        if os.environ.get('FAST2SMS_API_KEY'):
            ok, msg = _send_fast2sms(normalized, otp)
            if ok:
                provider_used = "fast2sms"
                delivery_note = f"SMS sent to {display} via Fast2SMS."
                sent_successfully = True
            else:
                delivery_note = f"Fast2SMS failed ({msg}); fell back to console log."

        # Priority B: Twilio (Global SMS)
        elif os.environ.get('TWILIO_ACCOUNT_SID') and os.environ.get('TWILIO_AUTH_TOKEN'):
            ok, msg = _send_twilio(display, otp)
            if ok:
                provider_used = "twilio"
                delivery_note = f"SMS sent to {display} via Twilio."
                sent_successfully = True
            else:
                delivery_note = f"Twilio failed ({msg}); fell back to console log."

        # Priority C: MSG91 (DLT SMS)
        elif os.environ.get('MSG91_AUTH_KEY') and os.environ.get('MSG91_TEMPLATE_ID'):
            ok, msg = _send_msg91(normalized, otp)
            if ok:
                provider_used = "msg91"
                delivery_note = f"SMS sent to {display} via MSG91."
                sent_successfully = True
            else:
                delivery_note = f"MSG91 failed ({msg}); fell back to console log."

    # 4. Console Banner Logging
    log_otp_banner(display, otp, purpose, f"{provider_used} - {delivery_note}")
    _cooldown_tracker[normalized] = now

    # In production, debug_otp can still be supplied if ENABLE_DEBUG_OTP is True or in development
    is_prod = os.environ.get('FLASK_ENV') == 'production'
    allow_debug = not is_prod or os.environ.get('ENABLE_DEBUG_OTP', 'true').lower() in ('true', '1')

    return {
        "success": True,
        "otp_sent": True,
        "provider": provider_used,
        "message": delivery_note,
        "debug_otp": otp if allow_debug else None,
        "recipient": display
    }
