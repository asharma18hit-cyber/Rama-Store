# scripts/replace_inventory_tab.py
with open("public_web/admin.html", "r", encoding="utf-8") as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if '<section id="tab-inventory"' in line:
        start_idx = i
    elif '<section id="tab-orders"' in line:
        end_idx = i
        break

print(f"Replacing lines {start_idx+1} to {end_idx}...")

with open("scripts/patch_admin_inventory_tab.py", "r", encoding="utf-8") as f:
    patch_code = f.read()

# Extract new_tab_inventory from patch_admin_inventory_tab.py
s_tag = 'new_tab_inventory = """'
e_tag = '"""\n\nmatch = '
s_pos = patch_code.find(s_tag) + len(s_tag)
e_pos = patch_code.find(e_tag)
new_tab_content = patch_code[s_pos:e_pos]

lines[start_idx:end_idx] = [new_tab_content + "\n        "]

with open("public_web/admin.html", "w", encoding="utf-8") as f:
    f.writelines(lines)

print("Inventory tab cleanly replaced!")
