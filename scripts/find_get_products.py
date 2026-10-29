# scripts/find_get_products.py
with open("functions/index.js", "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        if "router.get('/products'" in line or 'router.get("/products"' in line:
            print(f"Line {i+1}: {line.strip()}")
