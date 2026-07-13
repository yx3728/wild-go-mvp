import {
  type SpeciesResult,
  speciesResultFromOutputText,
} from "./species-result.ts";
import {
  databaseAuthHeaders,
  decodeBase64Image,
  storagePathForObservation,
  stripDataURLPrefix,
  validObservationId,
  verifiedUserIdFromAuthHeader,
} from "./request-utils.ts";

type IdentifyRequest = {
  imageBase64?: string;
  imageMimeType?: string;
  clientId?: string;
  observationId?: string;
  latitude?: number;
  longitude?: number;
  capturedAt?: string;
};

const OPENAI_MODEL = Deno.env.get("OPENAI_VISION_MODEL") ?? "gpt-4.1-mini";
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_AUTH_API_KEY = SUPABASE_ANON_KEY ??
  SUPABASE_SERVICE_ROLE_KEY;
const ALLOW_DEMO_IDENTIFICATION = flagEnabled(
  Deno.env.get("ALLOW_DEMO_IDENTIFICATION"),
);

const fallback: SpeciesResult = {
  commonName: "Blue Jay",
  latinName: "Cyanocitta cristata",
  rarity: "City Legend",
  finish: "Holo Foil",
  stars: 6,
  confidence: 0.92,
  note: "Bold, noisy, and usually spotted near mature street trees.",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return json({}, 200);
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const body = await request.json().catch(() => null) as IdentifyRequest | null;
  if (!body?.imageBase64) {
    return json({ error: "imageBase64 is required" }, 400);
  }

  if (!OPENAI_API_KEY && !ALLOW_DEMO_IDENTIFICATION) {
    return json({
      error: "OPENAI_API_KEY is required for cloud species recognition",
      code: "missing_openai_api_key",
    }, 500);
  }

  const userId = await verifiedUserIdFromAuthHeader(request, {
    supabaseUrl: SUPABASE_URL,
    authApiKey: SUPABASE_AUTH_API_KEY,
    serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
  });
  const observationId = userId
    ? validObservationId(body.observationId)
    : undefined;
  const authorizationHeader = userId
    ? request.headers.get("Authorization")
    : undefined;
  const storagePath = await uploadObservationImage(body, userId, observationId);
  if (!storagePath) {
    return json({
      error: "Observation image upload failed",
      code: "storage_upload_failed",
    }, 502);
  }

  if (!OPENAI_API_KEY) {
    const result = { ...fallback, storagePath };
    const persisted = await persistObservation(
      result,
      body,
      userId,
      observationId,
      authorizationHeader,
      "fallback",
    );
    if (!persisted) {
      return json({
        error: "Observation persistence failed",
        code: "observation_persist_failed",
      }, 502);
    }
    return json(result, 200);
  }

  const locationHint =
    typeof body.latitude === "number" && typeof body.longitude === "number"
      ? `Approximate observation coordinate: ${body.latitude.toFixed(3)}, ${
        body.longitude.toFixed(3)
      }.`
      : "No coordinate was provided.";

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      input: [{
        role: "user",
        content: [
          {
            type: "input_text",
            text:
              "Identify the likely species in this observation image for Wild Go. " +
              "Return a collectible card interpretation, not medical or safety advice. " +
              "If uncertain, choose the closest common urban nature species and lower confidence. " +
              `${locationHint} Storage path: ${storagePath ?? "not uploaded"}.`,
          },
          {
            type: "input_image",
            image_url: `data:${body.imageMimeType ?? "image/jpeg"};base64,${
              stripDataURLPrefix(body.imageBase64)
            }`,
          },
        ],
      }],
      text: {
        format: {
          type: "json_schema",
          name: "species_identification",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            required: [
              "commonName",
              "latinName",
              "rarity",
              "finish",
              "stars",
              "confidence",
              "note",
              "alternativeMatches",
            ],
            properties: {
              commonName: { type: "string" },
              latinName: { type: "string" },
              rarity: {
                type: "string",
                enum: [
                  "Common",
                  "Uncommon",
                  "Rare",
                  "Seasonal",
                  "Local Special",
                  "City Legend",
                ],
              },
              finish: {
                type: "string",
                enum: [
                  "Matte",
                  "Colored Edge",
                  "Metallic",
                  "Iridescent",
                  "Foil",
                  "Holo Foil",
                ],
              },
              stars: { type: "integer", minimum: 1, maximum: 6 },
              confidence: { type: "number", minimum: 0, maximum: 1 },
              note: { type: "string" },
              alternativeMatches: {
                type: "array",
                items: { type: "string" },
                maxItems: 3,
              },
            },
          },
        },
      },
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    return json({ error: "OpenAI identification failed", detail }, 502);
  }

  const payload = await response.json();
  const outputText = extractOutputText(payload);
  if (!outputText) {
    return json({ error: "OpenAI returned no structured text" }, 502);
  }

  const result = speciesResultFromOutputText(outputText, storagePath);
  if (!result) {
    return json({ error: "OpenAI returned an invalid species result" }, 502);
  }

  const persisted = await persistObservation(
    result,
    body,
    userId,
    observationId,
    authorizationHeader,
    "cloud_api",
  );
  if (!persisted) {
    return json({
      error: "Observation persistence failed",
      code: "observation_persist_failed",
    }, 502);
  }
  return json(result, 200);
});

function extractOutputText(payload: unknown): string | undefined {
  if (!payload || typeof payload !== "object") return undefined;

  const maybe = payload as {
    output_text?: string;
    output?: Array<{ content?: Array<{ type?: string; text?: string }> }>;
  };

  if (typeof maybe.output_text === "string") {
    return maybe.output_text;
  }

  return maybe.output
    ?.flatMap((item) => item.content ?? [])
    .find((content) =>
      content.type === "output_text" && typeof content.text === "string"
    )
    ?.text;
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

async function uploadObservationImage(
  request: IdentifyRequest,
  userId: string | null,
  observationId?: string,
): Promise<string | undefined> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return undefined;
  }

  const mimeType = request.imageMimeType ?? "image/jpeg";
  if (
    !["image/jpeg", "image/png", "image/heic", "image/heif"].includes(mimeType)
  ) {
    return undefined;
  }

  const storagePath = storagePathForObservation({
    userId,
    clientId: request.clientId,
    mimeType,
    objectId: observationId,
  });
  const uploadURL =
    `${SUPABASE_URL}/storage/v1/object/observations/${storagePath}`;
  let imageBytes: Uint8Array;

  try {
    imageBytes = decodeBase64Image(request.imageBase64);
  } catch {
    return undefined;
  }
  const imageBody = imageBytes.buffer.slice(
    imageBytes.byteOffset,
    imageBytes.byteOffset + imageBytes.byteLength,
  ) as ArrayBuffer;

  const response = await fetch(uploadURL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "apikey": SUPABASE_SERVICE_ROLE_KEY,
      "Content-Type": mimeType,
      "x-upsert": observationId ? "true" : "false",
    },
    body: imageBody,
  }).catch(() => undefined);

  if (!response?.ok) {
    return undefined;
  }

  return storagePath;
}

async function persistObservation(
  result: SpeciesResult,
  request: IdentifyRequest,
  userId: string | null,
  observationId: string | undefined,
  authorizationHeader: string | null | undefined,
  source: "cloud_api" | "fallback",
): Promise<boolean> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return false;
  }

  const authHeaders = databaseAuthHeaders({
    verifiedUserId: userId,
    authorizationHeader,
    anonKey: SUPABASE_ANON_KEY,
    serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
  });
  if (!authHeaders) return false;

  const observationsURL = new URL(`${SUPABASE_URL}/rest/v1/observations`);
  if (observationId) {
    observationsURL.searchParams.set("on_conflict", "id");
  }

  const response = await fetch(observationsURL, {
    method: "POST",
    headers: {
      ...authHeaders,
      "Content-Type": "application/json",
      "Prefer": observationId
        ? "resolution=merge-duplicates,return=minimal"
        : "return=minimal",
    },
    body: JSON.stringify({
      ...(observationId ? { id: observationId } : {}),
      user_id: userId,
      client_id: request.clientId ?? "anonymous",
      common_name: result.commonName,
      latin_name: result.latinName,
      rarity: result.rarity,
      finish: result.finish,
      stars: result.stars,
      confidence: result.confidence,
      locality: "Approx location",
      note: result.note,
      latitude: request.latitude ?? null,
      longitude: request.longitude ?? null,
      image_path: result.storagePath ?? null,
      source,
      captured_at: request.capturedAt ?? new Date().toISOString(),
    }),
  }).catch(() => undefined);

  return response?.ok ?? false;
}

function flagEnabled(value: string | undefined): boolean {
  return ["1", "true", "yes"].includes((value ?? "").trim().toLowerCase());
}
