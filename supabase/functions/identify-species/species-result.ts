export type SpeciesResult = {
  commonName: string;
  latinName: string;
  rarity: string;
  finish: string;
  stars: number;
  confidence: number;
  note: string;
  storagePath?: string;
  alternativeMatches?: string[];
};

const rarityByStars = [
  "Common",
  "Uncommon",
  "Rare",
  "Seasonal",
  "Local Special",
  "City Legend",
] as const;

const finishByRarity = new Map<string, string>([
  ["Common", "Matte"],
  ["Uncommon", "Colored Edge"],
  ["Rare", "Metallic"],
  ["Seasonal", "Iridescent"],
  ["Local Special", "Foil"],
  ["City Legend", "Holo Foil"],
]);

export function speciesResultFromOutputText(
  outputText: string,
  storagePath?: string,
): SpeciesResult | undefined {
  try {
    return normalizeSpeciesResult(JSON.parse(outputText), storagePath);
  } catch {
    return undefined;
  }
}

export function normalizeSpeciesResult(
  input: unknown,
  storagePath?: string,
): SpeciesResult | undefined {
  if (!input || typeof input !== "object") return undefined;

  const candidate = input as Record<string, unknown>;
  const commonName = cleanText(candidate.commonName);
  const latinName = cleanText(candidate.latinName);
  if (!commonName || !latinName) return undefined;

  const stars = normalizeStars(candidate.stars, candidate.rarity);
  const rarity = normalizeRarity(candidate.rarity, stars);
  const finish = normalizeFinish(candidate.finish, rarity);
  const confidence = normalizeConfidence(candidate.confidence);
  const note = cleanText(candidate.note) ?? `Likely ${commonName} observation.`;
  const alternativeMatches = normalizeAlternativeMatches(
    candidate.alternativeMatches,
  );

  return {
    commonName,
    latinName,
    rarity,
    finish,
    stars,
    confidence,
    note,
    ...(storagePath ? { storagePath } : {}),
    ...(alternativeMatches.length > 0 ? { alternativeMatches } : {}),
  };
}

function cleanText(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeStars(value: unknown, rarity: unknown): number {
  const numeric = typeof value === "number" ? value : Number(value);
  if (Number.isFinite(numeric)) {
    return Math.min(6, Math.max(1, Math.round(numeric)));
  }

  const rarityIndex = rarityByStars.indexOf(
    normalizeRarityText(rarity) as typeof rarityByStars[number],
  );
  return rarityIndex >= 0 ? rarityIndex + 1 : 3;
}

function normalizeRarity(value: unknown, stars: number): string {
  const rarity = normalizeRarityText(value);
  if (rarityByStars.includes(rarity as typeof rarityByStars[number])) {
    return rarity;
  }
  return rarityByStars[stars - 1];
}

function normalizeRarityText(value: unknown): string {
  const normalized = cleanText(value)?.toLowerCase().replace(/[_-]+/g, " ");
  switch (normalized) {
    case "common":
      return "Common";
    case "uncommon":
      return "Uncommon";
    case "rare":
      return "Rare";
    case "seasonal":
      return "Seasonal";
    case "local special":
      return "Local Special";
    case "city legend":
    case "urban legend":
    case "legendary":
      return "City Legend";
    default:
      return "";
  }
}

function normalizeFinish(value: unknown, rarity: string): string {
  const normalized = cleanText(value)?.toLowerCase().replace(/[_-]+/g, " ");
  switch (normalized) {
    case "matte":
      return "Matte";
    case "colored edge":
    case "colored":
      return "Colored Edge";
    case "metallic":
      return "Metallic";
    case "iridescent":
      return "Iridescent";
    case "foil":
      return "Foil";
    case "holo foil":
    case "holographic":
    case "holographic foil":
      return "Holo Foil";
    default:
      return finishByRarity.get(rarity) ?? "Metallic";
  }
}

function normalizeConfidence(value: unknown): number {
  const numeric = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(numeric)) return 0.5;
  const ratio = numeric > 1 ? numeric / 100 : numeric;
  return Math.min(1, Math.max(0, Number(ratio.toFixed(4))));
}

function normalizeAlternativeMatches(value: unknown): string[] {
  if (!Array.isArray(value)) return [];

  return value
    .map(cleanText)
    .filter((match): match is string => Boolean(match))
    .slice(0, 3);
}
