# scripts/find_lines.py
with open('functions/index.js', 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if 'router.post("/products"' in line or 'handleUpdateProduct' in line:
            print(f'{i+1}: {line.strip()}')
