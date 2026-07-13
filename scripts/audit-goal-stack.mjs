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
  "observationId: observationID.uuidString.lowercased()",
  "id: observationID",
  "needsAuthenticatedUpload",
  "guard let pendingStoragePath = await uploadLocalObservationImage",
  "LocalSpeciesRecognizer",
  "VNCoreMLRequest",
  "MLModel(contentsOf:",
]);

checkFile("ShaderKit Swift package dependency", "ios/App/App.xcodeproj/project.pbxproj", [
  "https://github.com/jamesrochabrun/ShaderKit",
  "kind = exactVersion",
  "version = 1.2.4",
  "productName = ShaderKit",
  "ShaderKit in Frameworks",
]);

checkFile(
  "ShaderKit Swift package resolved pin",
  "ios/App/App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
  [
    "\"identity\" : \"shaderkit\"",
    "\"location\" : \"https://github.com/jamesrochabrun/ShaderKit\"",
    "\"revision\" : \"cfa7858252adfcf6f0ac94aea58399bc8a6b2dcf\"",
    "\"version\" : \"1.2.4\"",
  ],
);

checkFile("ShaderKit six-tier metal implementation", "ios/App/App/AppDelegate.swift", [
  "import ShaderKit",
  "private enum RarityMetalTier: Int",
  "case matteSteel = 1",
  "case coloredAlloy = 2",
  "case crosshatchedSilver = 3",
  "case iridescentPearl = 4",
  "case invertedFoil = 5",
  "case rainbowHolo = 6",
  "struct RarityMetalBorder: View",
  "struct RarityMetalSurface: View",
  ".shader(.polishedAluminum(intensity: 0.3))",
  ".shader(.metallicCrosshatch(intensity: 0.58))",
  ".shader(.diagonalHolo(intensity: 0.64))",
  ".shader(.invertedFoil(intensity: 0.76))",
  ".shader(.foil(intensity: 0.94))",
  ".shader(.rainbowGlitter(intensity: 0.62))",
  "tilt: foilTilt",
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
  "const persisted = await persistObservation(",
  "validObservationId",
  "databaseAuthHeaders",
  "observation_persist_failed",
  "storage_upload_failed",
  "verifiedUserIdFromAuthHeader",
]);

checkFile("Edge Function rollback tests", "supabase/functions/identify-species/index.test.ts", [
  "rejects requests without image data before calling dependencies",
  "requires an OpenAI key unless demo identification is explicit",
  "persists the demo identification only when explicitly enabled",
  "persists a successful identification without deleting its image",
  "deletes a new image when OpenAI identification fails",
  "deletes a new image when Postgres persistence fails",
  "preserves an existing signed-in image and keeps Postgres behind RLS",
]);

checkFile("Edge Function request contract tests", "supabase/functions/identify-species/request-utils.test.ts", [
  "decodes raw and data URL base64 observation images",
  "builds private Storage paths for signed-in and device observations",
  "service-role authorization",
  "Auth sub claim",
  "keeps signed-in Postgres writes behind RLS",
]);

checkFile("Species result normalization tests", "supabase/functions/identify-species/species-result.test.ts", [
  "normalizes generous OpenAI species output",
  "derives rarity and finish from star count",
  "rejects invalid or incomplete species output",
]);

checkFile("Supabase deploy contract", "scripts/verify-supabase-deploy.mjs", [
  "project-local CLI",
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_ANON_KEY",
  "2.109.1",
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
  "\"supabase:verify\"",
  "\"supabase:start\"",
  "\"supabase:deploy\"",
  "\"supabase\": \"2.109.1\"",
  "\"goal:audit\"",
  "\"concept:audit\"",
]);

checkFile("Native visual QA", "scripts/verify-native-smoke-images.mjs", [
  "referenceSpecs",
  "swiftui-native-capture-layout-final.png",
  "swiftui-native-binder-grid-layout-final.png",
  "swiftui-native-friends-profile-v17.png",
  "tuned-map.png",
]);

checkFile("Concept fidelity QA", "scripts/audit-concept-fidelity.mjs", [
  "conceptSpecs",
  "capture-holo-unlock.png",
  "binder-rarity-grid.png",
  "friends-showcase-stack.png",
  "minimumComposite",
  "thumbnailSimilarity",
  "histogramSimilarity",
  "bandSimilarity",
  "WILDGO_BINDER_ACTUAL",
]);

checkAsset("Capture concept reference", "docs/card-visuals/capture-holo-unlock.png");
checkAsset("Binder concept reference", "docs/card-visuals/binder-rarity-grid.png");
checkAsset("Friends concept reference", "docs/card-visuals/friends-showcase-stack.png");
checkAsset("Capture native reference", "qa-shots/swiftui-native-capture-layout-final.png");
checkAsset("Capture generated landscape art", "ios/App/App/GeneratedAssets/capture-blue-jay-landscape-gen-v2.png");
checkAsset("Capture web landscape art", "public/assets/capture-blue-jay-landscape-gen-v2.png");
checkAsset("Binder native reference", "qa-shots/swiftui-native-binder-grid-layout-final.png");
checkAsset("Profile native reference", "qa-shots/swiftui-native-friends-profile-v17.png");
checkAsset("Map native reference", "qa-shots/tuned-map.png");
checkAsset("ShaderKit capture material reference", "qa-shots/swiftui-native-capture-shaderkit-v1.png");
checkAsset("ShaderKit six-tier binder reference", "qa-shots/swiftui-native-binder-shaderkit-rarity-v1.png");

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
