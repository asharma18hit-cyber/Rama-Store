// scripts/test_local_server.js
process.env.GCLOUD_PROJECT = "ma-store-949c7";
process.env.GOOGLE_CLOUD_PROJECT = "ma-store-949c7";
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: "ma-store-949c7" });

// If service account key exists, load it
const path = require("path");
const fs = require("fs");

const possibleKeyPaths = [
  path.join(__dirname, "../firebase_service_account.json"),
  path.join(__dirname, "../serviceAccountKey.json"),
  path.join(__dirname, "../firebase-service-account.json"),
  path.join(process.env.APPDATA || "", "gcloud/application_default_credentials.json")
];

for (const p of possibleKeyPaths) {
  if (fs.existsSync(p)) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = p;
    console.log(`[Staging Server] Using credentials from ${p}`);
    break;
  }
}

const { apiApp } = require("../functions/index.js");

const PORT = 8089;
const server = apiApp.listen(PORT, "127.0.0.1", () => {
  console.log(`[Staging Server] Local Express staging instance running at http://127.0.0.1:${PORT}`);
});

process.on("SIGINT", () => {
  server.close();
  process.exit(0);
});

process.on("SIGTERM", () => {
  server.close();
  process.exit(0);
});
