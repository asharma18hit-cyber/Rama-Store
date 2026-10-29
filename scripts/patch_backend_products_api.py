# scripts/patch_backend_products_api.py
import re

print("Enhancing functions/index.js with complete product suite APIs...")

with open("functions/index.js", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Update handleProducts to support status, sort, category filtering and full rich fields
old_handle_products_pattern = re.compile(
    r'const handleProducts = async \(req, res\) => \{.*?(?=router\.get\("/store/products", handleProducts\);)',
    re.DOTALL
)

new_handle_products = """const handleProducts = async (req, res) => {
  try {
    res.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const page = Math.max(1, parseInt(req.query.page || 1, 10));
    const perPage = Math.max(1, parseInt(req.query.per_page || 10, 10));
    const search = (req.query.search || req.query.q || "").toLowerCase().trim();
    const categoryId = req.query.category_id && req.query.category_id !== "null" && req.query.category_id !== "all" ? String(req.query.category_id) : null;
    const statusFilter = (req.query.status || "all").toLowerCase().trim();
    const sortBy = (req.query.sort || "newest").toLowerCase().trim();
    const maxPrice = req.query.max_price && req.query.max_price !== "null" ? parseFloat(req.query.max_price) : null;
    const isStorefront = req.path.includes("/store/products");

    const now = Date.now();
    let allRawDocs = [];
    if (cacheMemory.products && (now - cacheMemory.productsTime < 8000)) {
      allRawDocs = cacheMemory.products;
    } else {
      const snap = await db.collection("products").get();
      snap.forEach((doc) => {
        allRawDocs.push({ ...doc.data(), _docId: doc.id });
      });
      cacheMemory.products = allRawDocs;
      cacheMemory.productsTime = now;
    }

    let products = [];
    allRawDocs.forEach((d) => {
      const pId = d.id || d._docId;
      const price = parseFloat(d.selling_price || d.sellingPrice || d.price || 0);
      const purchasePrice = parseFloat(d.purchase_price || d.cost_price || 0);
      const origPrice = parseFloat(d.original_price || d.mrp || price);
      const discountPercent = origPrice > price ? Math.round(((origPrice - price) / origPrice) * 100) : 0;
      const stock = parseInt(d.stock || 0, 10);
      const lowStockThreshold = parseInt(d.low_stock_threshold || 10, 10);
      const name = d.name || "";
      const sku = d.sku || "";
      const brand = d.brand || "";
      const category = d.category || "General";
      const catId = d.category_id !== undefined ? String(d.category_id) : "";
      const status = d.status || (d.is_active === false ? "draft" : "published");
      const scheduledAt = d.scheduled_at ? new Date(d.scheduled_at).getTime() : null;

      // 1. Storefront filtering: Only show published products that are not scheduled in the future and not archived
      if (isStorefront) {
        if (status === "archived") return;
        if (status === "draft") return;
        if (status === "scheduled" && scheduledAt && scheduledAt > now) return;
        if (status !== "published" && status !== "scheduled") return;
      }

      // 2. Admin status filtering
      if (!isStorefront) {
        if (statusFilter === "published" && status !== "published") return;
        if (statusFilter === "draft" && status !== "draft") return;
        if (statusFilter === "scheduled" && status !== "scheduled") return;
        if (statusFilter === "archived" && status !== "archived") return;
        if (statusFilter === "low_stock" && (stock <= 0 || stock > lowStockThreshold)) return;
        if (statusFilter === "out_of_stock" && stock > 0) return;
        // If viewing "all", exclude archived products by default unless requested
        if (statusFilter === "all" && status === "archived") return;
      }

      // 3. Category filtering
      if (categoryId && catId !== categoryId && category.toLowerCase() !== categoryId.toLowerCase()) {
        return;
      }

      // 4. Price ceiling
      if (maxPrice !== null && !isNaN(maxPrice) && price > maxPrice) {
        return;
      }

      // 5. Search query matching
      if (search) {
        const matchesName = name.toLowerCase().includes(search);
        const matchesSku = sku.toLowerCase().includes(search);
        const matchesBrand = brand.toLowerCase().includes(search);
        const matchesCat = category.toLowerCase().includes(search);
        const matchesBarcode = d.barcode ? String(d.barcode).toLowerCase().includes(search) : false;
        if (!matchesName && !matchesSku && !matchesBrand && !matchesCat && !matchesBarcode) {
          return;
        }
      }

      // Extract images array
      let images = Array.isArray(d.images) && d.images.length > 0 ? d.images : [];
      if (images.length === 0 && d.image_url) {
        images = [{ url: d.image_url, is_primary: true }];
      }
      const primaryImg = images.find(img => img.is_primary) || images[0] || { url: d.image_url || "" };

      products.push({
        id: pId,
        _docId: d._docId,
        name: name,
        slug: d.slug || name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""),
        sku: sku,
        barcode: d.barcode || "",
        brand: brand,
        category: category,
        category_id: d.category_id,
        category_name: category,
        subcategory: d.subcategory || "",
        short_description: d.short_description || "",
        description: d.description || "",
        features: Array.isArray(d.features) ? d.features : (d.features ? String(d.features).split("\\n") : []),
        tags: Array.isArray(d.tags) ? d.tags : (d.tags ? String(d.tags).split(",") : []),
        price: price,
        selling_price: price,
        sellingPrice: price,
        original_price: origPrice,
        mrp: origPrice,
        discount_percent: discountPercent,
        purchase_price: purchasePrice,
        cost_price: purchasePrice,
        gst_percent: d.gst_percent !== undefined ? parseFloat(d.gst_percent) : 5,
        tax_inclusive: d.tax_inclusive !== undefined ? Boolean(d.tax_inclusive) : true,
        stock: stock,
        low_stock_threshold: lowStockThreshold,
        status: status,
        is_active: status === "published",
        image_url: primaryImg.url || d.image_url || "",
        images: images,
        variants: Array.isArray(d.variants) ? d.variants : [],
        unit: d.unit || "unit",
        delivery: typeof d.delivery === "object" ? d.delivery : {
          weight_kg: d.weight_kg || 0,
          dimensions: d.dimensions || "",
          serviceable_pins: d.serviceable_pins || "",
          prep_time_hours: d.prep_time_hours || 1,
          special_handling: d.special_handling || "Standard",
          returnable: d.returnable !== undefined ? d.returnable : false,
          return_days: d.return_days || 7
        },
        seo: typeof d.seo === "object" ? d.seo : {
          meta_title: d.meta_title || name,
          meta_description: d.meta_description || d.short_description || "",
          keywords: d.keywords || "",
          is_featured: Boolean(d.is_featured),
          is_homepage: Boolean(d.is_homepage)
        },
        scheduled_at: d.scheduled_at || null,
        archived_at: d.archived_at || null,
        created_at: d.created_at || null,
        updated_at: d.updated_at || null,
        audit_log: Array.isArray(d.audit_log) ? d.audit_log : []
      });
    });

    // 6. Sorting
    if (sortBy === "name_asc") {
      products.sort((a, b) => a.name.localeCompare(b.name));
    } else if (sortBy === "name_desc") {
      products.sort((a, b) => b.name.localeCompare(a.name));
    } else if (sortBy === "price_asc") {
      products.sort((a, b) => a.price - b.price);
    } else if (sortBy === "price_desc") {
      products.sort((a, b) => b.price - a.price);
    } else if (sortBy === "stock_asc") {
      products.sort((a, b) => a.stock - b.stock);
    } else if (sortBy === "stock_desc") {
      products.sort((a, b) => b.stock - a.stock);
    } else {
      // Default: newest first (by id or updated_at)
      products.sort((a, b) => {
        const tA = a.updated_at ? new Date(a.updated_at).getTime() : (Number(a.id) || 0);
        const tB = b.updated_at ? new Date(b.updated_at).getTime() : (Number(b.id) || 0);
        return tB - tA;
      });
    }

    const totalCount = products.length;
    const totalPages = Math.ceil(totalCount / perPage) || 1;
    const startIndex = (page - 1) * perPage;
    const paginatedProducts = products.slice(startIndex, startIndex + perPage);

    return res.json({
      products: paginatedProducts,
      total_count: totalCount,
      total_pages: totalPages,
      page: page,
      per_page: perPage
    });
  } catch (err) {
    console.error("products error:", err);
    return res.status(500).json({ error: "Failed to load products: " + err.message });
  }
};
"""

code = old_handle_products_pattern.sub(new_handle_products, code)

# 2. Add GET /api/products/counts, GET /api/products/:id, POST /api/products/bulk-action, POST /api/products/:id/duplicate, PATCH /api/products/:id/stock
new_endpoints = """
// GET /api/products/counts - Returns accurate database counts for all status tabs
router.get("/products/counts", async (req, res) => {
  try {
    res.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const snap = await db.collection("products").get();
    let total = 0;
    let published = 0;
    let draft = 0;
    let scheduled = 0;
    let low_stock = 0;
    let out_of_stock = 0;
    let archived = 0;

    snap.forEach((doc) => {
      const d = doc.data();
      const status = d.status || (d.is_active === false ? "draft" : "published");
      const stock = parseInt(d.stock || 0, 10);
      const lowThreshold = parseInt(d.low_stock_threshold || 10, 10);

      if (status === "archived") {
        archived++;
        return; // Don't count archived in active total
      }
      total++;
      if (status === "published") published++;
      else if (status === "draft") draft++;
      else if (status === "scheduled") scheduled++;

      if (stock === 0) out_of_stock++;
      else if (stock <= lowThreshold) low_stock++;
    });

    return res.json({
      success: true,
      counts: {
        total,
        published,
        draft,
        scheduled,
        low_stock,
        out_of_stock,
        archived
      }
    });
  } catch (err) {
    return res.status(500).json({ error: "Failed to get catalog counts: " + err.message });
  }
});

// GET /api/products/:id - Fetch single product with full specifications
router.get("/products/:id", async (req, res) => {
  try {
    res.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const docRef = await findProductDocRef(req.params.id);
    if (!docRef) {
      return res.status(404).json({ error: "Product not found" });
    }
    const snap = await docRef.get();
    const d = snap.data();
    return res.json({
      success: true,
      product: {
        ...d,
        id: d.id || snap.id,
        _docId: snap.id
      }
    });
  } catch (err) {
    return res.status(500).json({ error: "Failed to get product: " + err.message });
  }
});

// POST /api/products/bulk-action - Execute bulk operation across selected products
router.post("/products/bulk-action", async (req, res) => {
  try {
    const { action, product_ids, value } = req.body;
    if (!action || !Array.isArray(product_ids) || product_ids.length === 0) {
      return res.status(400).json({ error: "Action and product_ids array are required" });
    }

    const batch = db.batch();
    let count = 0;
    const nowIso = new Date().toISOString();

    for (const pId of product_ids) {
      const docRef = await findProductDocRef(pId);
      if (!docRef) continue;

      if (action === "publish") {
        batch.update(docRef, { status: "published", is_active: true, updated_at: nowIso });
        count++;
      } else if (action === "unpublish") {
        batch.update(docRef, { status: "draft", is_active: false, updated_at: nowIso });
        count++;
      } else if (action === "archive") {
        batch.update(docRef, { status: "archived", is_active: false, archived_at: nowIso, updated_at: nowIso });
        count++;
      } else if (action === "restore") {
        batch.update(docRef, { status: "published", is_active: true, archived_at: null, updated_at: nowIso });
        count++;
      } else if (action === "delete") {
        batch.delete(docRef);
        count++;
      } else if (action === "category") {
        const catId = Number(value);
        let catName = "General";
        try {
          const cDoc = await db.collection("categories").doc(String(catId)).get();
          if (cDoc.exists) catName = cDoc.data().name || catName;
        } catch (_) {}
        batch.update(docRef, { category_id: catId, category: catName, updated_at: nowIso });
        count++;
      } else if (action === "adjust_price") {
        const snap = await docRef.get();
        const pData = snap.data();
        let currPrice = parseFloat(pData.selling_price || pData.price || 0);
        if (value && value.percent) {
          currPrice = Math.round(currPrice * (1 + (parseFloat(value.percent) / 100)));
        } else if (value && value.delta) {
          currPrice = Math.max(1, currPrice + parseFloat(value.delta));
        }
        batch.update(docRef, { selling_price: currPrice, price: currPrice, sellingPrice: currPrice, updated_at: nowIso });
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      cacheMemory.products = null;
    }

    return res.json({
      success: true,
      message: `Bulk action '${action}' applied successfully to ${count} product(s)`,
      affected: count
    });
  } catch (err) {
    console.error("bulk action error:", err);
    return res.status(500).json({ error: "Failed to perform bulk action: " + err.message });
  }
});

// POST /api/products/:id/duplicate - Duplicate product as draft
router.post("/products/:id/duplicate", async (req, res) => {
  try {
    const docRef = await findProductDocRef(req.params.id);
    if (!docRef) return res.status(404).json({ error: "Product not found" });
    const snap = await docRef.get();
    const data = snap.data();

    const newId = Date.now();
    const newSku = (data.sku ? data.sku + "-COPY" : "SKU-" + newId);
    const newProduct = {
      ...data,
      id: newId,
      name: `${data.name} (Copy)`,
      sku: newSku,
      status: "draft",
      is_active: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: new Date().toISOString(),
      audit_log: [{
        action: "duplicated",
        timestamp: new Date().toISOString(),
        changed_by: "Admin",
        summary: `Duplicated from product #${req.params.id}`
      }]
    };

    await db.collection("products").doc(String(newId)).set(newProduct);
    cacheMemory.products = null;

    return res.json({
      success: true,
      message: `Product duplicated as draft with SKU ${newSku}`,
      product: newProduct
    });
  } catch (err) {
    return res.status(500).json({ error: "Duplicate failed: " + err.message });
  }
});

// PATCH /api/products/:id/stock - Quick stock adjustments with audit log
router.patch("/products/:id/stock", async (req, res) => {
  try {
    const { delta, absolute, reason } = req.body;
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
    }

    const auditEntry = {
      action: "stock_adjusted",
      timestamp: new Date().toISOString(),
      changed_by: "Admin",
      summary: `Stock adjusted from ${currStock} to ${newStock} (${reason || "Manual adjustment"})`
    };

    const existingAudit = Array.isArray(data.audit_log) ? data.audit_log : [];
    await docRef.update({
      stock: newStock,
      updated_at: new Date().toISOString(),
      audit_log: [auditEntry, ...existingAudit].slice(0, 25)
    });
    cacheMemory.products = null;

    return res.json({
      success: true,
      message: `Stock updated to ${newStock} units`,
      stock: newStock,
      previous_stock: currStock
    });
  } catch (err) {
    return res.status(500).json({ error: "Failed to update stock: " + err.message });
  }
});
"""

# Insert new endpoints right after router.get("/products/search", handleProducts);
search_anchor = 'router.get("/products/search", handleProducts);'
if "/api/products/counts" not in code:
    code = code.replace(search_anchor, search_anchor + "\n" + new_endpoints, 1)

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(code)

print("functions/index.js updated successfully!")
