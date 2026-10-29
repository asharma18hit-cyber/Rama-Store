# scripts/fix_syntax.py
with open('functions/index.js', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace broken split(" \n ")
broken = 'features: Array.isArray(d.features) ? d.features : (d.features ? String(d.features).split("\n") : []),'
fixed = 'features: Array.isArray(d.features) ? d.features : (d.features ? String(d.features).split("\\n") : []),'

if broken in text:
    text = text.replace(broken, fixed, 1)
else:
    # try with \r\n
    broken_crlf = 'features: Array.isArray(d.features) ? d.features : (d.features ? String(d.features).split("\r\n") : []),'
    text = text.replace(broken_crlf, fixed, 1)

with open('functions/index.js', 'w', encoding='utf-8') as f:
    f.write(text)

print("Replacement applied")
