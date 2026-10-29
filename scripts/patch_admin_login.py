# scripts/patch_admin_login.py
import re

with open('public_web/admin_login.html', 'r', encoding='utf-8') as f:
    c = f.read()

c = c.replace('dY`?\ufffd,?', '\U0001f441\ufe0f')
c = c.replace('dY"? Verify Credentials & Proceed to MFA \ufffdz"', '\U0001f510 Send OTP & Verify')
c = c.replace('\ufffdz" Customer Storefront', '\u2192 Customer Storefront')
c = c.replace('dY>\ufffd,? Multi-Factor Authentication (MFA)', '\U0001f6e1\ufe0f Multi-Factor Authentication (MFA)')
c = c.replace('dY>\ufffd,? Verify MFA & Access Admin Console', '\U0001f680 Verify MFA & Enter Control Hub')
c = c.replace('A\ufffd Re-enter Credentials', '\u2190 Back to Credentials')
c = c.replace('???', '\U0001f510')

with open('public_web/admin_login.html', 'w', encoding='utf-8') as f:
    f.write(c)

print('Cleaned public_web/admin_login.html')
