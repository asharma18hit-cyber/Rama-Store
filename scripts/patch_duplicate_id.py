# scripts/patch_duplicate_id.py

with open("functions/index.js", "r", encoding="utf-8") as f:
    text = f.read()

target = """    return res.json({
      success: true,
      message: `Product duplicated as draft with SKU ${newSku}`,
      product: newProduct
    });"""

rep = """    return res.json({
      success: true,
      message: `Product duplicated as draft with SKU ${newSku}`,
      product: newProduct,
      id: newId
    });"""

assert target in text, "target not found"
text = text.replace(target, rep, 1)

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(text)

print("Successfully added id: newId to duplicate response!")
