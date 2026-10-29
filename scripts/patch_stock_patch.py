# scripts/patch_stock_patch.py

with open("functions/index.js", "r", encoding="utf-8") as f:
    content = f.read()

target = """    const { delta, absolute, reason } = req.body;
    const docRef = await findProductDocRef(req.params.id);
    if (!docRef) return res.status(404).json({ error: "Product not found" });

    const snap = await docRef.get();
    const data = snap.data();
    let currStock = parseInt(data.stock || 0, 10);
    let newStock = currStock;

    if (absolute !== undefined && absolute !== null) {
      newStock = Math.max(0, parseInt(absolute, 10));
    } else if (delta !== undefined && delta !== null) {
      newStock = Math.max(0, currStock + parseInt(delta, 10));
    }"""

replacement = """    const { delta, absolute, stock, new_stock, reason } = req.body;
    const docRef = await findProductDocRef(req.params.id);
    if (!docRef) return res.status(404).json({ error: "Product not found" });

    const snap = await docRef.get();
    const data = snap.data();
    let currStock = parseInt(data.stock || 0, 10);
    let newStock = currStock;

    const absVal = absolute !== undefined ? absolute : (stock !== undefined ? stock : new_stock);
    if (absVal !== undefined && absVal !== null) {
      newStock = Math.max(0, parseInt(absVal, 10));
    } else if (delta !== undefined && delta !== null) {
      newStock = Math.max(0, currStock + parseInt(delta, 10));
    }"""

assert target in content, "Target not found in functions/index.js"
content = content.replace(target, replacement, 1)

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(content)

print("Successfully updated PATCH /products/:id/stock to accept stock, new_stock, and absolute!")
