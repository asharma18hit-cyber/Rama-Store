# scripts/list_routes.py
import re

with open("functions/index.js", "r", encoding="utf-8") as f:
    text = f.read()

routes = re.findall(r'router\.(get|post|put|patch|delete)\([\'"]([^\'"]+)', text)
print(f"Total routes in index.js: {len(routes)}")
for method, route in routes:
    print(f"{method.upper():6} {route}")

print("\n--- Vendor Routes ---")
with open("functions/vendor_routes.js", "r", encoding="utf-8") as f:
    vtext = f.read()
vroutes = re.findall(r'router\.(get|post|put|patch|delete)\([\'"]([^\'"]+)', vtext)
print(f"Total routes in vendor_routes.js: {len(vroutes)}")
for method, route in vroutes:
    print(f"{method.upper():6} {route}")
