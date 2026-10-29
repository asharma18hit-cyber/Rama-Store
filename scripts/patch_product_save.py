# scripts/patch_product_save.py
import re

print("Patching POST/PUT/DELETE products in functions/index.js...")

with open("functions/index.js", "r", encoding="utf-8") as f:
    code = f.read()

# Replace router.post("/products" ... through handleDeleteProduct
start_marker = '// POST /api/products - Create a new product (Published live or saved as Draft)'
end_marker = 'router.delete("/products/:id", handleDeleteProduct);'

start_idx = code.find(start_marker)
end_idx = code.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print("Markers not found!")
    exit(1)

new_block = """// POST /api/products - Create a new product (Published live, saved as Draft, or Scheduled)
router.post("/products", async (req, res) => {
  try {
    const {
      sku, name, category_id, status, purchase_price, selling_price, original_price, mrp,
      stock, image_url, images, description, short_description, features, tags, unit,
      brand, barcode, slug, gst_percent, tax_inclusive, low_stock_threshold,
      variants, delivery, seo, scheduled_at
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ error: "Product name is required" });
    }
    if (selling_price === undefined || selling_price === null || isNaN(selling_price)) {
      return res.status(400).json({ error: "Selling price is required" });
    }

    const prodId = Date.now();
    const prodSku = (sku && sku.trim()) ? sku.trim() : "SKU-" + prodId;

    // Duplicate SKU detection
    const existingSkuSnap = await db.collection("products").where("sku", "==", prodSku).limit(1).get();
    if (!existingSkuSnap.empty) {
      return res.status(400).json({ error: `A product with SKU "${prodSku}" already exists (${existingSkuSnap.docs[0].data().name}). Please use a unique SKU.` });
    }

    const prodStatus = (status === "draft" || status === "scheduled" || status === "archived") ? status : "published";
    const sellPrice = parseFloat(selling_price);
    const costPrice = parseFloat(purchase_price || 0);
    const origPrice = parseFloat(original_price || mrp || 0);
    const prodStock = parseInt(stock || 0, 10);

    let categoryName = "General";
    if (category_id) {
      try {
        const catDoc = await db.collection("categories").doc(String(category_id)).get();
        if (catDoc.exists) {
          categoryName = catDoc.data().name || categoryName;
        }
      } catch (_) {}
    }

    // Process images
    let imageList = Array.isArray(images) && images.length > 0 ? images : [];
    if (imageList.length === 0 && image_url && image_url.trim()) {
      imageList = [{ url: image_url.trim(), is_primary: true }];
    }
    const primaryImg = imageList.find(img => img.is_primary) || imageList[0] || { url: (image_url && image_url.trim()) ? image_url.trim() : "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80" };

    const prodSlug = (slug && slug.trim())
      ? slug.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
      : name.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

    const prodDocRef = db.collection("products").doc(String(prodId));
    const nowIso = new Date().toISOString();

    const prodData = {
      id: prodId,
      sku: prodSku,
      barcode: (barcode && barcode.trim()) ? barcode.trim() : "",
      slug: prodSlug,
      name: name.trim(),
      brand: (brand && brand.trim()) ? brand.trim() : "",
      category: categoryName,
      category_id: category_id ? Number(category_id) : null,
      subcategory: req.body.subcategory ? String(req.body.subcategory).trim() : "",
      short_description: short_description ? short_description.trim() : "",
      description: description ? description.trim() : "",
      features: Array.isArray(features) ? features : (features ? String(features).split("\\n").map(s => s.trim()).filter(Boolean) : []),
      tags: Array.isArray(tags) ? tags : (tags ? String(tags).split(",").map(s => s.trim()).filter(Boolean) : []),
      price: sellPrice,
      selling_price: sellPrice,
      sellingPrice: sellPrice,
      original_price: origPrice > sellPrice ? origPrice : sellPrice,
      mrp: origPrice > sellPrice ? origPrice : sellPrice,
      purchase_price: costPrice,
      cost_price: costPrice,
      stock: prodStock,
      low_stock_threshold: parseInt(low_stock_threshold || 10, 10),
      gst_percent: parseFloat(gst_percent || 0),
      tax_inclusive: tax_inclusive !== undefined ? Boolean(tax_inclusive) : true,
      status: prodStatus,
      is_active: prodStatus === "published",
      image_url: primaryImg.url,
      images: imageList,
      variants: Array.isArray(variants) ? variants : [],
      unit: unit || "unit",
      delivery: typeof delivery === "object" ? delivery : {
        weight_kg: parseFloat(req.body.weight_kg || 0),
        dimensions: req.body.dimensions || "",
        serviceable_pins: req.body.serviceable_pins || "",
        prep_time_hours: parseInt(req.body.prep_time_hours || 1, 10),
        special_handling: req.body.special_handling || "Standard",
        returnable: Boolean(req.body.returnable),
        return_days: parseInt(req.body.return_days || 7, 10)
      },
      seo: typeof seo === "object" ? seo : {
        meta_title: req.body.meta_title || name.trim(),
        meta_description: req.body.meta_description || short_description || "",
        keywords: req.body.keywords || "",
        is_featured: Boolean(req.body.is_featured),
        is_homepage: Boolean(req.body.is_homepage)
      },
      scheduled_at: scheduled_at || null,
      archived_at: null,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: nowIso,
      audit_log: [{
        action: "created",
        timestamp: nowIso,
        changed_by: "Rama Store Owner",
        summary: `Product registered with status '${prodStatus}'`
      }]
    };

    await prodDocRef.set(prodData);
    cacheMemory.products = null; // Invalidate cache so it appears immediately!

    return res.json({
      success: true,
      message: prodStatus === "published" ? "Product created and published live on storefront!" : `Product saved as ${prodStatus}`,
      product: prodData,
      id: prodId
    });
  } catch (err) {
    console.error("create product error:", err);
    return res.status(500).json({ error: "Failed to create product: " + err.message });
  }
});

// PUT /api/products, PUT /api/products/update/:id - Update product & toggle publish status
const handleUpdateProduct = async (req, res) => {
  try {
    const pId = req.params.id || req.body.product_id || req.body.id;
    if (!pId) {
      return res.status(400).json({ error: "Product ID is required" });
    }

    const docRef = await findProductDocRef(pId);
    if (!docRef) {
      return res.status(404).json({ error: "Product not found" });
    }

    const snap = await docRef.get();
    const currData = snap.data() || {};
    const nowIso = new Date().toISOString();

    const updates = {
      updated_at: nowIso
    };

    // Duplicate SKU check if SKU changed
    if (req.body.sku !== undefined) {
      const newSku = String(req.body.sku).trim();
      const existingSkuSnap = await db.collection("products").where("sku", "==", newSku).limit(1).get();
      if (!existingSkuSnap.empty && existingSkuSnap.docs[0].ref.path !== docRef.path) {
        return res.status(400).json({ error: `A product with SKU "${newSku}" already exists. Please choose a unique SKU.` });
      }
      updates.sku = newSku;
    }

    if (req.body.name !== undefined) updates.name = String(req.body.name).trim();
    if (req.body.slug !== undefined) updates.slug = String(req.body.slug).trim();
    if (req.body.barcode !== undefined) updates.barcode = String(req.body.barcode).trim();
    if (req.body.brand !== undefined) updates.brand = String(req.body.brand).trim();
    if (req.body.subcategory !== undefined) updates.subcategory = String(req.body.subcategory).trim();
    if (req.body.short_description !== undefined) updates.short_description = String(req.body.short_description).trim();
    if (req.body.description !== undefined) updates.description = String(req.body.description).trim();
    if (req.body.features !== undefined) {
      updates.features = Array.isArray(req.body.features) ? req.body.features : String(req.body.features).split("\\n").map(s => s.trim()).filter(Boolean);
    }
    if (req.body.tags !== undefined) {
      updates.tags = Array.isArray(req.body.tags) ? req.body.tags : String(req.body.tags).split(",").map(s => s.trim()).filter(Boolean);
    }
    if (req.body.gst_percent !== undefined) updates.gst_percent = parseFloat(req.body.gst_percent) || 0;
    if (req.body.tax_inclusive !== undefined) updates.tax_inclusive = Boolean(req.body.tax_inclusive);
    if (req.body.low_stock_threshold !== undefined) updates.low_stock_threshold = parseInt(req.body.low_stock_threshold, 10) || 10;
    
    if (req.body.status !== undefined) {
      updates.status = req.body.status;
      updates.is_active = (req.body.status === "published");
      if (req.body.status === "archived") {
        updates.archived_at = nowIso;
      }
    }
    if (req.body.is_active !== undefined) {
      updates.is_active = Boolean(req.body.is_active);
      if (req.body.status === undefined) {
        updates.status = updates.is_active ? "published" : "draft";
      }
    }

    if (req.body.selling_price !== undefined || req.body.price !== undefined) {
      const sp = parseFloat(req.body.selling_price !== undefined ? req.body.selling_price : req.body.price);
      if (!isNaN(sp)) {
        updates.selling_price = sp;
        updates.sellingPrice = sp;
        updates.price = sp;
      }
    }
    if (req.body.purchase_price !== undefined || req.body.cost_price !== undefined) {
      const cp = parseFloat(req.body.purchase_price !== undefined ? req.body.purchase_price : req.body.cost_price);
      if (!isNaN(cp)) {
        updates.purchase_price = cp;
        updates.cost_price = cp;
      }
    }
    if (req.body.original_price !== undefined || req.body.mrp !== undefined) {
      const op = parseFloat(req.body.original_price !== undefined ? req.body.original_price : req.body.mrp);
      if (!isNaN(op)) {
        updates.original_price = op;
        updates.mrp = op;
      }
    }
    if (req.body.stock !== undefined) {
      const st = parseInt(req.body.stock, 10);
      if (!isNaN(st)) updates.stock = st;
    }

    // Process Images
    if (req.body.images !== undefined && Array.isArray(req.body.images)) {
      updates.images = req.body.images;
      const primaryImg = req.body.images.find(img => img.is_primary) || req.body.images[0];
      if (primaryImg && primaryImg.url) {
        updates.image_url = primaryImg.url;
      }
    } else if (req.body.image_url !== undefined) {
      updates.image_url = String(req.body.image_url).trim();
    }

    if (req.body.variants !== undefined && Array.isArray(req.body.variants)) {
      updates.variants = req.body.variants;
    }
    if (req.body.delivery !== undefined && typeof req.body.delivery === "object") {
      updates.delivery = req.body.delivery;
    }
    if (req.body.seo !== undefined && typeof req.body.seo === "object") {
      updates.seo = req.body.seo;
    }
    if (req.body.scheduled_at !== undefined) updates.scheduled_at = req.body.scheduled_at;
    if (req.body.unit !== undefined) updates.unit = String(req.body.unit).trim();

    if (req.body.category_id !== undefined) {
      const cid = req.body.category_id ? Number(req.body.category_id) : null;
      updates.category_id = cid;
      if (cid) {
        try {
          const catDoc = await db.collection("categories").doc(String(cid)).get();
          if (catDoc.exists) {
            updates.category = catDoc.data().name || updates.category;
          }
        } catch (_) {}
      }
    }

    // Record audit entry
    const existingAudit = Array.isArray(currData.audit_log) ? currData.audit_log : [];
    const changedFields = Object.keys(updates).filter(k => k !== "updated_at").join(", ");
    const auditEntry = {
      action: updates.status === "archived" ? "archived" : (updates.status === "published" ? "published" : "updated"),
      timestamp: nowIso,
      changed_by: "Rama Store Owner",
      summary: `Updated fields: ${changedFields || "no changes"}`
    };
    updates.audit_log = [auditEntry, ...existingAudit].slice(0, 25);

    await docRef.update(updates);
    cacheMemory.products = null; // Invalidate cache immediately

    const updatedSnap = await docRef.get();
    return res.json({
      success: true,
      message: updates.status === "published" ? "Product published live on storefront!" : `Product updated (${updates.status || "saved"})`,
      product: updatedSnap.data()
    });
  } catch (err) {
    console.error("update product error:", err);
    return res.status(500).json({ error: "Failed to update product: " + err.message });
  }
};

router.put("/products", handleUpdateProduct);
router.put("/products/update/:id", handleUpdateProduct);
router.post("/products/update/:id", handleUpdateProduct);

// PATCH /api/products/:id/publish - Quick toggle publish/draft
router.patch("/products/:id/publish", async (req, res) => {
  try {
    const pId = req.params.id;
    const docRef = await findProductDocRef(pId);
    if (!docRef) {
      return res.status(404).json({ error: "Product not found" });
    }
    const snap = await docRef.get();
    const currStatus = snap.data().status;
    const newStatus = (currStatus === "published") ? "draft" : "published";

    await docRef.update({
      status: newStatus,
      is_active: newStatus === "published",
      updated_at: new Date().toISOString()
    });
    cacheMemory.products = null;

    return res.json({
      success: true,
      status: newStatus,
      message: newStatus === "published" ? "Product is now LIVE on storefront!" : "Product moved to drafts"
    });
  } catch (err) {
    return res.status(500).json({ error: "Failed to toggle status: " + err.message });
  }
});

// DELETE /api/products/delete/:id and DELETE /api/products/:id
const handleDeleteProduct = async (req, res) => {
  try {
    const pId = req.params.id || req.body.id;
    if (!pId) {
      return res.status(400).json({ error: "Product ID is required" });
    }

    const docRef = await findProductDocRef(pId);
    if (!docRef) {
      return res.status(404).json({ error: "Product not found" });
    }

    // Safety policy: Check if product is referenced in historical customer orders
    const pNum = Number(pId);
    const orderItemSnap = await db.collection("orders").limit(200).get();
    let isReferencedInOrders = false;
    orderItemSnap.forEach(doc => {
      const oData = doc.data();
      const items = oData.items || [];
      if (items.some(it => String(it.id || it.product_id || it.productId) === String(pId) || (!isNaN(pNum) && (it.id === pNum || it.product_id === pNum)))) {
        isReferencedInOrders = true;
      }
    });

    if (isReferencedInOrders) {
      // Soft-archive instead of hard deletion to maintain order receipt integrity
      await docRef.update({
        status: "archived",
        is_active: false,
        archived_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });
      cacheMemory.products = null;
      return res.json({
        success: true,
        archived: true,
        message: "Product is referenced in customer orders. It has been safely moved to Archives to preserve order history."
      });
    }

    await docRef.delete();
    cacheMemory.products = null;

    return res.json({
      success: true,
      message: "Product deleted from catalog successfully"
    });
  } catch (err) {
    console.error("delete product error:", err);
    return res.status(500).json({ error: "Failed to delete product: " + err.message });
  }
};

router.delete("/products/delete/:id", handleDeleteProduct);
router.delete("/products/:id", handleDeleteProduct);"""

code = code[:start_idx] + new_block + code[end_idx + len(end_marker):]

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(code)

print("functions/index.js successfully upgraded!")
