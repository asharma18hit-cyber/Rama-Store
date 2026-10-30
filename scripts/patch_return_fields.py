# scripts/patch_return_fields.py
with open("functions/vendor_routes.js", "r", encoding="utf-8") as f:
    c = f.read()

c = c.replace(
    'vendor_id: vendorId,\n        status: "submitted"\n      });',
    'vendor_id: vendorId,\n        status: "submitted",\n        phone_verified: true,\n        mfa_verified: true\n      });'
)

with open("functions/vendor_routes.js", "w", encoding="utf-8") as f:
    f.write(c)

print("Updated vendor_routes.js successfully!")
