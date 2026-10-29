# scripts/reorder_csv_route.py

with open("functions/index.js", "r", encoding="utf-8") as f:
    text = f.read()

csv_route = """// CSV Catalog Export
router.get("/products/export-csv", async (req, res) => {
  try {
    const snap = await db.collection("products").get();
    const rows = [
      ["SKU", "Product Name", "Category", "MRP", "Selling Price", "Cost Price", "Stock", "Unit", "Status", "Image URL"]
    ];

    snap.forEach((doc) => {
      const d = doc.data();
      rows.push([
        d.sku || "",
        (d.name || "").replace(/"/g, '""'),
        (d.category || "").replace(/"/g, '""'),
        d.original_price || d.mrp || "",
        d.selling_price || d.price || "",
        d.purchase_price || d.cost_price || "",
        d.stock || 0,
        d.unit || "unit",
        d.status || (d.is_active === false ? "draft" : "published"),
        d.image_url || ""
      ]);
    });

    const csvContent = rows.map(r => r.map(field => `"${String(field)}"`).join(",")).join("\\r\\n");
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", 'attachment; filename="rama_store_catalog_' + Date.now() + '.csv"');
    return res.send(csvContent);
  } catch (err) {
    return res.status(500).send("CSV export error: " + err.message);
  }
});
"""

assert csv_route in text, "csv_route not found"
text = text.replace(csv_route, "")

target = '// GET /api/products/:id - Fetch single product with full specifications'
assert target in text, "target not found"
text = text.replace(target, csv_route + "\n" + target)

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(text)

print("Moved /products/export-csv before /products/:id successfully!")
