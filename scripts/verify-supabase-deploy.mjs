import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const root = fileURLToPath(new URL("..", import.meta.url));
const deployScript = readFileSync(join(root, "supabase/deploy.sh"), "utf8");
const packageJSON = JSON.parse(
  readFileSync(join(root, "package.json"), "utf8"),
);

const failures = [];

requireText(
  deployScript,
  'SUPABASE_CLI="$PWD/node_modules/.bin/supabase"',
  "deploy script falls back to the project-local CLI",
);
requireText(
  deployScript,
  '"OPENAI_API_KEY=$OPENAI_API_KEY"',
  "deploy script publishes the OpenAI key",
);
forbidText(
  deployScript,
  '"SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY"',
  "reserved service-role environment variable is not redeclared",
);
forbidText(
  deployScript,
  '"SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"',
  "reserved anon environment variable is not redeclared",
);

if (packageJSON.devDependencies?.supabase !== "2.109.1") {
  failures.push("package.json must pin Supabase CLI exactly to 2.109.1");
}

if (failures.length > 0) {
  for (const failure of failures) console.error(`FAIL ${failure}`);
  process.exit(1);
}

console.log("Supabase deploy contract passed: pinned local CLI and hosted secrets are valid.");

function requireText(contents, expected, message) {
  if (!contents.includes(expected)) failures.push(message);
}

function forbidText(contents, forbidden, message) {
  if (contents.includes(forbidden)) failures.push(message);
}
