// functions/index.js - Enterprise Production Firebase Cloud Functions
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Trusted Order Creation Cloud Function
 * Server-authoritative price validation, stock reservation, and atomic transaction.
 */
exports.createOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to create an order."
    );
  }

  const userId = context.auth.uid;
  const items = data.items || [];
  const shippingAddress = data.shippingAddress || "";
  const paymentMethod = data.paymentMethod || "COD";

  if (!items.length) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Order items cannot be empty."
    );
  }

  return db.runTransaction(async (transaction) => {
    let subtotal = 0;
    const verifiedItems = [];

    for (const item of items) {
      const productRef = db.collection("products").doc(String(item.productId));
      const productSnap = await transaction.get(productRef);

      if (!productSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          `Product ID ${item.productId} not found.`
        );
      }

      const product = productSnap.data();
      const quantity = Math.max(1, parseInt(item.quantity || 1, 10));

      if (product.stock < quantity) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Insufficient stock for product: ${product.name}. Available: ${product.stock}`
        );
      }

      const price = parseFloat(product.sellingPrice);
      subtotal += price * quantity;

      verifiedItems.push({
        productId: item.productId,
        name: product.name,
        quantity: quantity,
        priceAtPurchase: price,
      });

      // Atomically decrement stock
      transaction.update(productRef, {
        stock: product.stock - quantity,
      });
    }

    const shippingFee = subtotal >= 500 ? 0 : 49;
    const totalAmount = subtotal + shippingFee;
    const trackingNumber = "RS-ORD-" + Date.now() + "-" + Math.floor(1000 + Math.random() * 9000);

    const orderRef = db.collection("orders").doc();
    const orderData = {
      orderId: orderRef.id,
      trackingNumber: trackingNumber,
      customerId: userId,
      customerPhone: context.auth.token.phone_number || "",
      items: verifiedItems,
      subtotalAmount: subtotal,
      shippingFee: shippingFee,
      totalAmount: totalAmount,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      paymentStatus: "PENDING",
      orderStatus: "Pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(orderRef, orderData);

    return {
      success: true,
      orderId: orderRef.id,
      trackingNumber: trackingNumber,
      totalAmount: totalAmount,
    };
  });
});

/**
 * Order Cancellation & Inventory Restoration Cloud Function
 */
exports.cancelOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to cancel an order."
    );
  }

  const userId = context.auth.uid;
  const orderId = data.orderId;
  const reason = data.reason || "Customer requested cancellation";

  if (!orderId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "orderId is required."
    );
  }

  return db.runTransaction(async (transaction) => {
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await transaction.get(orderRef);

    if (!orderSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Order not found.");
    }

    const order = orderSnap.data();

    // Verify ownership or admin rights
    const isAdmin = context.auth.token.admin === true || context.auth.token.role === "admin";
    if (order.customerId !== userId && !isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You do not have permission to cancel this order."
      );
    }

    if (order.orderStatus === "Cancelled") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Order is already cancelled."
      );
    }

    if (order.orderStatus === "Shipped" || order.orderStatus === "Delivered") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Dispatched or delivered orders cannot be cancelled."
      );
    }

    // Atomically restore product stock
    for (const item of order.items || []) {
      const productRef = db.collection("products").doc(String(item.productId));
      const productSnap = await transaction.get(productRef);
      if (productSnap.exists) {
        const product = productSnap.data();
        transaction.update(productRef, {
          stock: product.stock + item.quantity,
        });
      }
    }

    const isPaid = order.paymentStatus === "PAID";
    const newPaymentStatus = isPaid ? "REFUND_PENDING" : order.paymentStatus;

    transaction.update(orderRef, {
      orderStatus: "Cancelled",
      paymentStatus: newPaymentStatus,
      cancellationReason: reason,
      cancelledBy: userId,
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: "Order cancelled successfully and inventory restored.",
    };
  });
});

/**
 * Server-Authoritative Payment Verification Cloud Function
 */
exports.verifyPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to verify payment."
    );
  }

  const orderId = data.orderId;
  const paymentTransactionId = data.paymentTransactionId;

  if (!orderId || !paymentTransactionId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "orderId and paymentTransactionId are required."
    );
  }

  const orderRef = db.collection("orders").doc(orderId);
  const orderSnap = await orderRef.get();

  if (!orderSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Order not found.");
  }

  await orderRef.update({
    paymentStatus: "PAID",
    paymentTransactionId: paymentTransactionId,
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    message: "Payment verified successfully by server.",
  };
});

/**
 * Privileged Custom Claim Assignment for Admin Authorization
 */
exports.setAdminRole = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only existing admins can grant admin privileges."
    );
  }

  const targetUid = data.uid;
  if (!targetUid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Target UID is required."
    );
  }

  await admin.auth().setCustomUserClaims(targetUid, { admin: true, role: "admin" });
  await db.collection("users").doc(targetUid).update({ role: "admin" });

  return {
    success: true,
    message: `Admin role successfully assigned to user ${targetUid}`,
  };
});
