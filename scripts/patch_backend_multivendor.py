# scripts/patch_backend_multivendor.py

with open("functions/index.js", "r", encoding="utf-8") as f:
    text = f.read()

# 1. Mount createVendorRouter
target_mount = """apiApp.use("/api", router);
apiApp.use("/", router);

exports.api = functions.https.onRequest(apiApp);"""

rep_mount = """const createVendorRouter = require("./vendor_routes");
const vendorRouter = createVendorRouter({ db, admin, cacheMemory });
apiApp.use("/api", vendorRouter);
apiApp.use("/", vendorRouter);

apiApp.use("/api", router);
apiApp.use("/", router);

exports.api = functions.https.onRequest(apiApp);"""

assert target_mount in text, "target_mount not found in functions/index.js"
text = text.replace(target_mount, rep_mount, 1)

# 2. Update handleProducts storefront filtering & vendor fields
target_filter = """      // 1. Storefront filtering: Only show published products that are not scheduled in the future and not archived
      if (isStorefront) {
        if (status === "archived") return;
        if (status === "draft") return;
        if (status === "scheduled" && scheduledAt && scheduledAt > now) return;
        if (status !== "published" && status !== "scheduled") return;
      }"""

rep_filter = """      // 1. Storefront / Public filtering: Only show published, approved products that are not scheduled in future or archived
      const isPublicStore = isStorefront || (!req.isAdmin && statusFilter !== "all" && statusFilter !== "draft" && statusFilter !== "archived");
      if (isPublicStore) {
        if (status === "archived") return;
        if (status === "draft") return;
        if (status === "scheduled" && scheduledAt && scheduledAt > now) return;
        if (status !== "published" && status !== "scheduled") return;
        // Strict Multi-Vendor rule: Vendor products must be approved by Owner before public storefront publication
        if (d.approval_status === "pending_review" || d.approval_status === "rejected" || d.approval_status === "changes_requested") return;
      }"""

assert target_filter in text, "target_filter not found in functions/index.js"
text = text.replace(target_filter, rep_filter, 1)

# Update product object in handleProducts to include vendor metadata
target_prod_obj = """        tags: Array.isArray(d.tags) ? d.tags : (d.tags ? String(d.tags).split(",") : []),"""

rep_prod_obj = """        tags: Array.isArray(d.tags) ? d.tags : (d.tags ? String(d.tags).split(",") : []),
        vendor_id: d.vendor_id || "owner",
        vendor_name: d.vendor_name || "Rama Store Direct",
        approval_status: d.approval_status || "approved",
        review_notes: d.review_notes || null,"""

assert target_prod_obj in text, "target_prod_obj not found in functions/index.js"
text = text.replace(target_prod_obj, rep_prod_obj, 1)

# 3. Update checkout to tag line items with vendor_id and vendor_name
target_checkout_loop = """    for (const item of cart) {
      const qty = Math.max(1, parseInt(item.quantity || 1, 10));
      let price = parseFloat(item.price || item.selling_price || 0);
      let name = item.name || "Product";

      // If price is 0, attempt lookup from database
      if (price <= 0 && (item.id || item.product_id)) {
        try {
          const pId = item.id || item.product_id;
          const pDoc = await findProductDocRef(pId);
          if (pDoc) {
            const pSnap = await pDoc.get();
            if (pSnap.exists) {
              const pData = pSnap.data();
              price = parseFloat(pData.selling_price || pData.price || 0);
              name = pData.name || name;
            }
          }
        } catch (_) {}
      }

      subtotal += price * qty;
      verifiedItems.push({
        id: item.id || item.product_id,
        productId: item.id || item.product_id,
        name: name,
        price: price,
        quantity: qty,
        subtotal: price * qty
      });
    }"""

rep_checkout_loop = """    for (const item of cart) {
      const qty = Math.max(1, parseInt(item.quantity || 1, 10));
      let price = parseFloat(item.price || item.selling_price || 0);
      let name = item.name || "Product";
      let itemVendorId = "owner";
      let itemVendorName = "Rama Store Direct";

      const pId = item.id || item.product_id;
      if (pId) {
        try {
          const pDoc = await findProductDocRef(pId);
          if (pDoc) {
            const pSnap = await pDoc.get();
            if (pSnap.exists) {
              const pData = pSnap.data();
              if (price <= 0) {
                price = parseFloat(pData.selling_price || pData.price || 0);
              }
              name = pData.name || name;
              if (pData.vendor_id) {
                itemVendorId = pData.vendor_id;
                itemVendorName = pData.vendor_name || "Marketplace Vendor";
              }
            }
          }
        } catch (_) {}
      }

      subtotal += price * qty;
      verifiedItems.push({
        id: item.id || item.product_id,
        productId: item.id || item.product_id,
        name: name,
        price: price,
        quantity: qty,
        subtotal: price * qty,
        vendor_id: itemVendorId,
        vendor_name: itemVendorName,
        vendor_fulfillment_status: "new"
      });
    }"""

assert target_checkout_loop in text, "target_checkout_loop not found in functions/index.js"
text = text.replace(target_checkout_loop, rep_checkout_loop, 1)

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(text)

print("Successfully patched functions/index.js for Multi-Vendor Marketplace!")
