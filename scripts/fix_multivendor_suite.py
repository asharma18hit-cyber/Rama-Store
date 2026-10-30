# scripts/fix_multivendor_suite.py
with open("scripts/verify_multivendor_suite.py", "r", encoding="utf-8") as f:
    text = f.read()

target = '''    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:'''

replacement = '''    try:
        kwargs = {"timeout": 30}
        if url.startswith("https://"):
            kwargs["context"] = ctx
        with urllib.request.urlopen(req, **kwargs) as resp:'''

if target in text:
    text = text.replace(target, replacement)
    print("Replaced urlopen call successfully!")
else:
    print("Pattern not found, checking...")

if "urllib.request.ProxyHandler" not in text:
    text = text.replace(
        "BASE_URL = os.environ.get",
        "opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))\nurllib.request.install_opener(opener)\nBASE_URL = os.environ.get"
    )

with open("scripts/verify_multivendor_suite.py", "w", encoding="utf-8") as f:
    f.write(text)

print("scripts/verify_multivendor_suite.py updated!")
