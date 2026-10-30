# scripts/patch_admin_login_ui.py
import re

with open("public_web/admin_login.html", "r", encoding="utf-8") as f:
    html = f.read()

# Replace header badge
html = re.sub(
    r'<div class="auth-badge">\s*<span>🛡️</span>\s*2-Factor Authentication \(MFA\) Active\s*</div>',
    '<div class="auth-badge"><span>👤</span> Store Owner Login</div>',
    html
)

# Replace creds button
html = re.sub(
    r'<span class="btn-text">🔐 Verify Credentials & Proceed to MFA ➔</span>',
    '<span class="btn-text">Sign In ➔</span>',
    html
)

# Remove MFA Enforced span
html = re.sub(
    r'<span style="color: #64748b; font-size: 0\.75rem;">MFA Enforced</span>',
    '',
    html
)

# Replace Step 2 mfa-info-box
html = re.sub(
    r'<div class="mfa-info-box">.*?</div>\s*</div>',
    '''<div class="mfa-info-box">
                <div style="font-weight: 700; color: #f59e0b; margin-bottom: 4px; font-size: 0.9rem;">
                    Verification Code
                </div>
                Enter the 6-digit code sent to your phone
            </div>''',
    html,
    flags=re.DOTALL
)

# Replace Step 2 label & button
html = html.replace('6-Digit MFA Security Code', '6-Digit Verification Code')
html = html.replace('🛡️ Verify MFA & Access Admin Console', 'Verify & Access Admin Console ➔')
html = html.replace('Resend MFA Code', 'Resend Code')

with open("public_web/admin_login.html", "w", encoding="utf-8") as f:
    f.write(html)

print("public_web/admin_login.html cleaned up successfully!")
