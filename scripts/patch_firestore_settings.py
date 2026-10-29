# scripts/patch_firestore_settings.py

with open("functions/index.js", "r", encoding="utf-8") as f:
    content = f.read()

# 1. db.settings({ ignoreUndefinedProperties: true });
old_db = "admin.initializeApp();\nconst db = admin.firestore();"
new_db = """admin.initializeApp();
const db = admin.firestore();
try {
  db.settings({ ignoreUndefinedProperties: true });
} catch (_) {}"""

assert old_db in content, "old_db not found"
content = content.replace(old_db, new_db, 1)

# 2. Image normalization in POST /products
old_post_img = """    // Process images
    let imageList = Array.isArray(images) && images.length > 0 ? images : [];
    if (imageList.length === 0 && image_url && image_url.trim()) {
      imageList = [{ url: image_url.trim(), is_primary: true }];
    }
    const primaryImg = imageList.find(img => img.is_primary) || imageList[0] || { url: (image_url && image_url.trim()) ? image_url.trim() : "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80" };"""

new_post_img = """    // Process images
    let rawImages = Array.isArray(images) ? images : [];
    if (rawImages.length === 0 && image_url && typeof image_url === "string" && image_url.trim()) {
      rawImages = [image_url.trim()];
    }
    const imageList = rawImages.map((img, idx) => {
      if (typeof img === "string") {
        return { url: img.trim(), is_primary: idx === 0, alt: name.trim() };
      }
      return {
        url: (img && img.url) ? String(img.url).trim() : "",
        is_primary: Boolean(img && img.is_primary),
        alt: (img && img.alt) ? String(img.alt).trim() : name.trim()
      };
    }).filter(img => Boolean(img.url));

    let primaryUrl = "";
    const primaryImgObj = imageList.find(img => img.is_primary) || imageList[0];
    if (primaryImgObj && primaryImgObj.url) {
      primaryUrl = primaryImgObj.url;
    } else if (image_url && typeof image_url === "string" && image_url.trim()) {
      primaryUrl = image_url.trim();
    } else {
      primaryUrl = "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80";
    }"""

assert old_post_img in content, "old_post_img not found"
content = content.replace(old_post_img, new_post_img, 1)

# Replace primaryImg.url in prodData
old_image_url_line = "      image_url: primaryImg.url,"
new_image_url_line = "      image_url: primaryUrl,"
assert old_image_url_line in content, "old_image_url_line not found"
content = content.replace(old_image_url_line, new_image_url_line, 1)

# 3. Image normalization in PUT /products (handleUpdateProduct)
old_put_img = """    // Process Images
    if (req.body.images !== undefined && Array.isArray(req.body.images)) {
      updates.images = req.body.images;
      const primaryImg = req.body.images.find(img => img.is_primary) || req.body.images[0];
      if (primaryImg && primaryImg.url) {
        updates.image_url = primaryImg.url;
      }
    } else if (req.body.image_url !== undefined) {
      updates.image_url = String(req.body.image_url).trim();
    }"""

new_put_img = """    // Process Images
    if (req.body.images !== undefined && Array.isArray(req.body.images)) {
      const normalizedImages = req.body.images.map((img, idx) => {
        if (typeof img === "string") {
          return { url: img.trim(), is_primary: idx === 0, alt: updates.name || currData.name || "" };
        }
        return {
          url: (img && img.url) ? String(img.url).trim() : "",
          is_primary: Boolean(img && img.is_primary),
          alt: (img && img.alt) ? String(img.alt).trim() : (updates.name || currData.name || "")
        };
      }).filter(img => Boolean(img.url));
      updates.images = normalizedImages;
      const primaryImg = normalizedImages.find(img => img.is_primary) || normalizedImages[0];
      if (primaryImg && primaryImg.url) {
        updates.image_url = primaryImg.url;
      }
    } else if (req.body.image_url !== undefined && typeof req.body.image_url === "string") {
      updates.image_url = req.body.image_url.trim();
    }"""

assert old_put_img in content, "old_put_img not found"
content = content.replace(old_put_img, new_put_img, 1)

with open("functions/index.js", "w", encoding="utf-8") as f:
    f.write(content)

print("Successfully patched functions/index.js with robust image handling and ignoreUndefinedProperties!")
