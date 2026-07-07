import { existsSync, readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const root = fileURLToPath(new URL("..", import.meta.url));
const checks = [];

checkFile("iOS app source", "ios/App/App/AppDelegate.swift", [
  "import SwiftUI",
  "import SwiftData",
  "import AVFoundation",
  "import MapKit",
  "import PhotosUI",
  "import CoreLocation",
  "import Vision",
  "import CoreML",
  "@Model",
  ".modelContainer(for: WildObservation.self)",
  "AVCaptureSession",
  "AVCapturePhotoCaptureDelegate",
  "PhotosPicker",
  "Map(position:",
  "CLLocationManager",
  "SpeciesRecognitionPipeline",
  "CloudSpeciesRecognizer",
  "LocalSpeciesRecognizer",
  "VNCoreMLRequest",
  "MLModel(contentsOf:",
]);

checkFile("Sticker Swift package dependency", "ios/App/App.xcodeproj/project.pbxproj", [
  "https://github.com/bpisano/sticker",
  "minimumVersion = 1.3.0",
  "productName = Sticker",
  "Sticker in Frameworks",
]);

checkFile(
  "Sticker Swift package resolved pin",
  "ios/App/App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
  [
    "\"identity\" : \"sticker\"",
    "\"location\" : \"https://github.com/bpisano/sticker\"",
    "\"revision\" : \"301b9e0fb802c01edb2ed25695b3ba62e9c61da3\"",
    "\"version\" : \"1.4.0\"",
  ],
);

checkFile("Sticker foil implementation", "ios/App/App/AppDelegate.swift", [
  "import Sticker",
  "ShaderLibrary.compileStickerShaders()",
  "FoilCardFrame(cornerRadius:",
  "CardFoilBloom(cornerRadius:",
  "stickerExampleEffect()",
  "stickerEffect()",
  ".stickerColorIntensity(0.5)",
  ".stickerNoiseScale(200)",
  ".stickerLightIntensity(0.5)",
  "stickerMotionEffect(.dragGesture(intensity: intensity))",
  "stickerMotionEffect(.accelerometer(intensity: intensity, maxRotation: .degrees(42), updateInterval: 0.025))",
]);

checkFile("Supabase migration", "supabase/migrations/20260705220500_initial_wild_go.sql", [
  "create table if not exists public.observations",
  "alter table public.observations enable row level security",
  "create policy \"authenticated users can read own observations\"",
  "insert into storage.buckets",
  "'observations'",
  "source in ('cloud_api', 'local_vision_coreml', 'fallback')",
]);

checkFile("Cloud identification Edge Function", "supabase/functions/identify-species/index.ts", [
  "Deno.serve",
  "OPENAI_API_KEY",
  "https://api.openai.com/v1/responses",
  "species_identification",
  "storage/v1/object/observations",
  "rest/v1/observations",
  "persistObservation(result, body, request, \"cloud_api\")",
  "verifiedUserIdFromAuthHeader",
]);

checkFile("Edge Function request contract tests", "supabase/functions/identify-species/request-utils.test.ts", [
  "decodes raw and data URL base64 observation images",
  "builds private Storage paths for signed-in and device observations",
  "service-role authorization",
  "Auth sub claim",
]);

checkFile("Species result normalization tests", "supabase/functions/identify-species/species-result.test.ts", [
  "normalizes generous OpenAI species output",
  "derives rarity and finish from star count",
  "rejects invalid or incomplete species output",
]);

checkFile("Core ML training tool", "ios/ml/build-model.sh", [
  "WildGoSpeciesClassifier",
  "train_species_classifier.swift",
  "GeneratedAssets",
]);

checkFile("Create ML trainer", "ios/ml/train_species_classifier.swift", [
  "CreateML",
  "MLImageClassifier",
  "WildGoSpeciesClassifier.mlmodel",
]);

checkFile("Package scripts", "package.json", [
  "\"ios:build\"",
  "\"ios:smoke\"",
  "\"ios:visual-check\"",
  "\"ios:verify-events\"",
  "\"ios:interactions\"",
  "\"supabase:test\"",
  "\"goal:audit\"",
]);

checkFile("Native visual QA", "scripts/verify-native-smoke-images.mjs", [
  "referenceSpecs",
  "swiftui-native-capture-layout-final.png",
  "swiftui-native-binder-grid-layout-final.png",
  "swiftui-native-friends-profile-v16.png",
  "tuned-map.png",
]);

checkAsset("Capture concept reference", "docs/card-visuals/capture-holo-unlock.png");
checkAsset("Binder concept reference", "docs/card-visuals/binder-rarity-grid.png");
checkAsset("Friends concept reference", "docs/card-visuals/friends-showcase-stack.png");
checkAsset("Capture native reference", "qa-shots/swiftui-native-capture-layout-final.png");
checkAsset("Binder native reference", "qa-shots/swiftui-native-binder-grid-layout-final.png");
checkAsset("Profile native reference", "qa-shots/swiftui-native-friends-profile-v16.png");
checkAsset("Map native reference", "qa-shots/tuned-map.png");
checkAsset("Sticker example native reference", "qa-shots/swiftui-native-capture-sticker-example-params-v1.png");

const failures = checks.filter((check) => !check.ok);
for (const check of checks) {
  const prefix = check.ok ? "ok" : "FAIL";
  console.log(`${prefix} ${check.label}`);
  for (const detail of check.details) {
    console.log(`  ${detail}`);
  }
}

if (failures.length > 0) {
  console.error(`Goal stack audit failed: ${failures.length} check(s) failed.`);
  process.exit(1);
}

console.log(`Goal stack audit passed: ${checks.length} checks.`);

function checkFile(label, relativePath, requiredText) {
  const fullPath = join(root, relativePath);
  if (!existsSync(fullPath)) {
    checks.push({
      label,
      ok: false,
      details: [`missing ${relativePath}`],
    });
    return;
  }

  const contents = readFileSync(fullPath, "utf8");
  const missing = requiredText.filter((text) => !contents.includes(text));
  checks.push({
    label,
    ok: missing.length === 0,
    details: missing.length === 0
      ? [`${relativePath} contains ${requiredText.length} required signal(s)`]
      : missing.map((text) => `${relativePath} missing ${JSON.stringify(text)}`),
  });
}

function checkAsset(label, relativePath) {
  const fullPath = join(root, relativePath);
  if (!existsSync(fullPath)) {
    checks.push({
      label,
      ok: false,
      details: [`missing ${relativePath}`],
    });
    return;
  }

  const { size } = statSync(fullPath);
  checks.push({
    label,
    ok: size > 10000,
    details: [`${relativePath} is ${size} bytes`],
  });
}
