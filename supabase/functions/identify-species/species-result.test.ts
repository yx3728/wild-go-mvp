import {
  normalizeSpeciesResult,
  type SpeciesResult,
  speciesResultFromOutputText,
} from "./species-result.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(
      `${message}: expected ${String(expected)}, got ${String(actual)}`,
    );
  }
}

function expectResult(result: SpeciesResult | undefined): SpeciesResult {
  assert(result !== undefined, "expected result");
  return result;
}

Deno.test("normalizes generous OpenAI species output into card-safe values", () => {
  const result = expectResult(normalizeSpeciesResult({
    commonName: " Blue Jay ",
    latinName: " Cyanocitta cristata ",
    rarity: "urban_legend",
    finish: "sparkle",
    stars: 8,
    confidence: 92,
    note: "  Bold city bird. ",
    alternativeMatches: ["Steller's Jay", "", "Gray Jay", "Florida Scrub-Jay"],
  }, "user/observation.jpg"));

  assertEquals(result.commonName, "Blue Jay", "common name trims whitespace");
  assertEquals(
    result.latinName,
    "Cyanocitta cristata",
    "latin name trims whitespace",
  );
  assertEquals(
    result.rarity,
    "City Legend",
    "rarity synonym maps to card tier",
  );
  assertEquals(
    result.finish,
    "Holo Foil",
    "unknown finish falls back from rarity",
  );
  assertEquals(result.stars, 6, "stars clamp to six-star maximum");
  assertEquals(result.confidence, 0.92, "percentage confidence becomes ratio");
  assertEquals(result.note, "Bold city bird.", "note trims whitespace");
  assertEquals(
    result.storagePath,
    "user/observation.jpg",
    "storage path is preserved",
  );
  assertEquals(
    result.alternativeMatches?.length,
    3,
    "alternatives are trimmed and capped",
  );
});

Deno.test("derives rarity and finish from star count when model labels drift", () => {
  const result = expectResult(speciesResultFromOutputText(JSON.stringify({
    commonName: "Black-eyed Susan",
    latinName: "Rudbeckia hirta",
    rarity: "not-a-tier",
    finish: "not-a-finish",
    stars: "2",
    confidence: "0.875",
    note: "",
  })));

  assertEquals(result.rarity, "Uncommon", "rarity derives from stars");
  assertEquals(result.finish, "Colored Edge", "finish derives from rarity");
  assertEquals(result.confidence, 0.875, "string confidence is accepted");
  assertEquals(
    result.note,
    "Likely Black-eyed Susan observation.",
    "missing note gets safe default",
  );
});

Deno.test("rejects invalid or incomplete species output", () => {
  assertEquals(
    speciesResultFromOutputText("{"),
    undefined,
    "invalid JSON is rejected",
  );
  assertEquals(
    normalizeSpeciesResult({
      commonName: "Mystery bird",
      stars: 4,
      confidence: 0.7,
      note: "Missing latin name.",
    }),
    undefined,
    "missing latin name is rejected",
  );
});
