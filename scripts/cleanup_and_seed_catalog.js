// scripts/cleanup_and_seed_catalog.js - Clean dummy products and seed realistic grocery items
const admin = require('../functions/node_modules/firebase-admin');
const serviceAccount = require('../ma-store-949c7-firebase-adminsdk-fbsvc-9145fe2c5d.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

const DUMMY_IDS_TO_REMOVE = ['9', '10', '11', '12', '13', '14', '15', '16'];

const REALISTIC_CATEGORIES = [
  { id: 1, name: "Staples & Grains", icon: "🌾" },
  { id: 2, name: "Edible Oils & Ghee", icon: "🛢️" },
  { id: 3, name: "Spices & Seasoning", icon: "🌶️" },
  { id: 4, name: "Dairy & Breakfast", icon: "🥛" },
  { id: 5, name: "Tea & Beverages", icon: "☕" },
  { id: 6, name: "Snacks & Biscuits", icon: "🍪" },
  { id: 7, name: "Household & Cleaning", icon: "🧼" },
  { id: 8, name: "Personal Care", icon: "🧴" }
];

const REALISTIC_PRODUCTS = [
  {
    id: 1,
    sku: "RAMA-ATT-001",
    name: "Aashirvaad Superior MP Shudh Chakki Atta (5 kg)",
    category: "Staples & Grains",
    category_id: 1,
    price: 235,
    selling_price: 235,
    sellingPrice: 235,
    original_price: 260,
    mrp: 260,
    discount_percent: 10,
    purchase_price: 215,
    cost_price: 215,
    stock: 45,
    unit: "5 kg",
    status: "published",
    is_active: true,
    description: "100% whole wheat flour directly sourced from MP Sehore grains for soft, fluffy rotis.",
    image_url: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 2,
    sku: "RAMA-RIC-002",
    name: "India Gate Feast Rozzana Basmati Rice (5 kg)",
    category: "Staples & Grains",
    category_id: 1,
    price: 475,
    selling_price: 475,
    sellingPrice: 475,
    original_price: 550,
    mrp: 550,
    discount_percent: 14,
    purchase_price: 420,
    cost_price: 420,
    stock: 35,
    unit: "5 kg",
    status: "published",
    is_active: true,
    description: "Long grain aromatic basmati rice, aged to perfection for biryani and daily meals.",
    image_url: "https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 3,
    sku: "RAMA-OIL-003",
    name: "Fortune Premium Kachi Ghani Pure Mustard Oil (1 L Pouch)",
    category: "Edible Oils & Ghee",
    category_id: 2,
    price: 145,
    selling_price: 145,
    sellingPrice: 145,
    original_price: 175,
    mrp: 175,
    discount_percent: 17,
    purchase_price: 130,
    cost_price: 130,
    stock: 60,
    unit: "1 L",
    status: "published",
    is_active: true,
    description: "Cold-pressed traditional pungent mustard oil rich in natural antioxidants and Omega-3.",
    image_url: "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 4,
    sku: "RAMA-GHE-004",
    name: "Amul Pure Cow Ghee Tin (1 L)",
    category: "Edible Oils & Ghee",
    category_id: 2,
    price: 610,
    selling_price: 610,
    sellingPrice: 610,
    original_price: 665,
    mrp: 665,
    discount_percent: 8,
    purchase_price: 570,
    cost_price: 570,
    stock: 25,
    unit: "1 L",
    status: "published",
    is_active: true,
    description: "Aromatic granular cow ghee made from fresh milk fat, rich in vitamins A, D, E & K.",
    image_url: "https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 5,
    sku: "RAMA-TEA-005",
    name: "Tata Tea Gold Rich Taste Assam Leaf Tea (500 g)",
    category: "Tea & Beverages",
    category_id: 5,
    price: 265,
    selling_price: 265,
    sellingPrice: 265,
    original_price: 310,
    mrp: 310,
    discount_percent: 15,
    purchase_price: 235,
    cost_price: 235,
    stock: 40,
    unit: "500 g",
    status: "published",
    is_active: true,
    description: "Exquisite blend of rich Assam CTC teas with gently rolled long leaves for rich aroma.",
    image_url: "https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 6,
    sku: "RAMA-DAL-006",
    name: "Tata Sampann Unpolished High-Protein Toor Dal (1 kg)",
    category: "Staples & Grains",
    category_id: 1,
    price: 175,
    selling_price: 175,
    sellingPrice: 175,
    original_price: 210,
    mrp: 210,
    discount_percent: 17,
    purchase_price: 155,
    cost_price: 155,
    stock: 50,
    unit: "1 kg",
    status: "published",
    is_active: true,
    description: "Unpolished arhar/toor dal without artificial color or polish, natural taste and high protein.",
    image_url: "https://images.unsplash.com/photo-1596797882870-8c33deeac224?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 7,
    sku: "RAMA-SLT-007",
    name: "Tata Salt Vacuum Evaporated Iodized Salt (1 kg)",
    category: "Spices & Seasoning",
    category_id: 3,
    price: 26,
    selling_price: 26,
    sellingPrice: 26,
    original_price: 28,
    mrp: 28,
    discount_percent: 7,
    purchase_price: 22,
    cost_price: 22,
    stock: 100,
    unit: "1 kg",
    status: "published",
    is_active: true,
    description: "Desh ka Namak - pure vacuum evaporated salt with essential iodine for health.",
    image_url: "https://images.unsplash.com/photo-1518110925495-5fe2fda0442c?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 8,
    sku: "RAMA-SUG-008",
    name: "Madhur Pure & Hygienic Refined Sugar (1 kg)",
    category: "Staples & Grains",
    category_id: 1,
    price: 52,
    selling_price: 52,
    sellingPrice: 52,
    original_price: 60,
    mrp: 60,
    discount_percent: 13,
    purchase_price: 46,
    cost_price: 46,
    stock: 75,
    unit: "1 kg",
    status: "published",
    is_active: true,
    description: "Sulphur-free, sparkling white, pure cane sugar untouched by human hands.",
    image_url: "https://images.unsplash.com/photo-1622484216858-a537f5d96f9a?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 17,
    sku: "RAMA-MAS-009",
    name: "MDH Deggi Mirch Natural Red Chilli Powder (100 g)",
    category: "Spices & Seasoning",
    category_id: 3,
    price: 92,
    selling_price: 92,
    sellingPrice: 92,
    original_price: 105,
    mrp: 105,
    discount_percent: 12,
    purchase_price: 80,
    cost_price: 80,
    stock: 30,
    unit: "100 g",
    status: "published",
    is_active: true,
    description: "Unique blend of Kashmiri chillies imparting natural vibrant red color and mild pungency.",
    image_url: "https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 18,
    sku: "RAMA-MAS-010",
    name: "Everest Royal Garam Masala (100 g)",
    category: "Spices & Seasoning",
    category_id: 3,
    price: 88,
    selling_price: 88,
    sellingPrice: 88,
    original_price: 98,
    mrp: 98,
    discount_percent: 10,
    purchase_price: 76,
    cost_price: 76,
    stock: 30,
    unit: "100 g",
    status: "published",
    is_active: true,
    description: "Aromatic blend of 13 roasted spices delivering rich Indian royal culinary aroma.",
    image_url: "https://images.unsplash.com/photo-1599940824399-b87987ceb72a?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 19,
    sku: "RAMA-BUT-011",
    name: "Amul Pasteurized Table Butter (500 g)",
    category: "Dairy & Breakfast",
    category_id: 4,
    price: 275,
    selling_price: 275,
    sellingPrice: 275,
    original_price: 290,
    mrp: 290,
    discount_percent: 5,
    purchase_price: 255,
    cost_price: 255,
    stock: 20,
    unit: "500 g",
    status: "published",
    is_active: true,
    description: "Utterly butterly delicious creamy pasteurized butter loved across all households.",
    image_url: "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 20,
    sku: "RAMA-MAG-012",
    name: "Nestle Maggi 2-Minute Masala Instant Noodles (4-Pack, 280 g)",
    category: "Snacks & Biscuits",
    category_id: 6,
    price: 56,
    selling_price: 56,
    sellingPrice: 56,
    original_price: 60,
    mrp: 60,
    discount_percent: 7,
    purchase_price: 49,
    cost_price: 49,
    stock: 50,
    unit: "4 x 70 g",
    status: "published",
    is_active: true,
    description: "India's favorite instant noodles with authentic roasted spices tastemaker.",
    image_url: "https://images.unsplash.com/photo-1612927601601-6638404737ce?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 21,
    sku: "RAMA-BIS-013",
    name: "Britannia Good Day Butter Cookies Value Pack (600 g)",
    category: "Snacks & Biscuits",
    category_id: 6,
    price: 115,
    selling_price: 115,
    sellingPrice: 115,
    original_price: 135,
    mrp: 135,
    discount_percent: 15,
    purchase_price: 98,
    cost_price: 98,
    stock: 40,
    unit: "600 g",
    status: "published",
    is_active: true,
    description: "Rich buttery cookies with a pleasant crusted smile, perfect with morning tea.",
    image_url: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 22,
    sku: "RAMA-CHO-014",
    name: "Cadbury Dairy Milk Silk Chocolate Bar (150 g)",
    category: "Snacks & Biscuits",
    category_id: 6,
    price: 165,
    selling_price: 165,
    sellingPrice: 165,
    original_price: 185,
    mrp: 185,
    discount_percent: 11,
    purchase_price: 145,
    cost_price: 145,
    stock: 25,
    unit: "150 g",
    status: "published",
    is_active: true,
    description: "Smoother, creamier, and silkier chocolate bar for special sweet indulgences.",
    image_url: "https://images.unsplash.com/photo-1549007994-cb92caebd54b?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 23,
    sku: "RAMA-DET-015",
    name: "Surf Excel Easy Wash Detergent Powder (1 kg)",
    category: "Household & Cleaning",
    category_id: 7,
    price: 135,
    selling_price: 135,
    sellingPrice: 135,
    original_price: 150,
    mrp: 150,
    discount_percent: 10,
    purchase_price: 118,
    cost_price: 118,
    stock: 35,
    unit: "1 kg",
    status: "published",
    is_active: true,
    description: "Superfine powder that dissolves fast and removes tough stains with ease.",
    image_url: "https://images.unsplash.com/photo-1583947215259-38e31be8751f?auto=format&fit=crop&w=600&q=80"
  },
  {
    id: 24,
    sku: "RAMA-HND-016",
    name: "Dettol Liquid Handwash Original Germ Protection (200 ml)",
    category: "Household & Cleaning",
    category_id: 7,
    price: 95,
    selling_price: 95,
    sellingPrice: 95,
    original_price: 109,
    mrp: 109,
    discount_percent: 13,
    purchase_price: 82,
    cost_price: 82,
    stock: 45,
    unit: "200 ml",
    status: "published",
    is_active: true,
    description: "Trusted germ protection handwash enriched with moisturizers to keep hands soft.",
    image_url: "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=600&q=80"
  }
];

async function run() {
  console.log("=== Rama Store Firestore Catalog Clean-up & Migration ===");

  // 1. Delete dummy items
  console.log("Removing dummy non-grocery items...");
  for (const id of DUMMY_IDS_TO_REMOVE) {
    const docRef = db.collection("products").doc(id);
    const docSnap = await docRef.get();
    if (docSnap.exists) {
      console.log(`Deleting dummy product [${id}]:`, docSnap.data().name);
      await docRef.delete();
    }
  }

  // Also check for any other products with book/candle/badminton/paracetamol keywords
  const allProdsSnap = await db.collection("products").get();
  for (const doc of allProdsSnap.docs) {
    const d = doc.data();
    const nameLower = (d.name || "").toLowerCase();
    if (
      nameLower.includes("psychology of money") ||
      nameLower.includes("atomic habits") ||
      nameLower.includes("badminton") ||
      nameLower.includes("paracetamol") ||
      nameLower.includes("soy candle") ||
      nameLower.includes("gel roller pens") ||
      nameLower.includes("executive ruled notebook") ||
      nameLower.includes("first aid safety kit")
    ) {
      console.log(`Deleting dummy doc [${doc.id}]:`, d.name);
      await doc.ref.delete();
    }
  }

  // 2. Update Categories
  console.log("\nUpdating supermarket categories...");
  for (const cat of REALISTIC_CATEGORIES) {
    await db.collection("categories").doc(String(cat.id)).set(cat);
    console.log(`Saved category [${cat.id}]:`, cat.name);
  }

  // 3. Seed Realistic Grocery Products
  console.log("\nSeeding authentic Indian supermarket grocery catalog...");
  for (const prod of REALISTIC_PRODUCTS) {
    const docRef = db.collection("products").doc(String(prod.id));
    await docRef.set({
      ...prod,
      updated_at: new Date().toISOString()
    });
    console.log(`Saved product [${prod.id}]: ${prod.name} (Selling: ₹${prod.price}, MRP: ₹${prod.original_price})`);
  }

  console.log("\n=== Migration completed successfully! ===");
}

run()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Migration failed:", err);
    process.exit(1);
  });
