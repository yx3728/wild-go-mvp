type IdentifyRequest = {
  imageBase64?: string
  imageMimeType?: string
  clientId?: string
  latitude?: number
  longitude?: number
  capturedAt?: string
}

type SpeciesResult = {
  commonName: string
  latinName: string
  rarity: string
  finish: string
  stars: number
  confidence: number
  note: string
  storagePath?: string
  alternativeMatches?: string[]
}

const OPENAI_MODEL = Deno.env.get("OPENAI_VISION_MODEL") ?? "gpt-4.1-mini"
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
const ALLOW_DEMO_IDENTIFICATION = flagEnabled(Deno.env.get("ALLOW_DEMO_IDENTIFICATION"))

const fallback: SpeciesResult = {
  commonName: "Blue Jay",
  latinName: "Cyanocitta cristata",
  rarity: "City Legend",
  finish: "Holo Foil",
  stars: 6,
  confidence: 0.92,
  note: "Bold, noisy, and usually spotted near mature street trees.",
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return json({}, 200)
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  const body = await request.json().catch(() => null) as IdentifyRequest | null
  if (!body?.imageBase64) {
    return json({ error: "imageBase64 is required" }, 400)
  }

  if (!OPENAI_API_KEY && !ALLOW_DEMO_IDENTIFICATION) {
    return json({
      error: "OPENAI_API_KEY is required for cloud species recognition",
      code: "missing_openai_api_key",
    }, 500)
  }

  const storagePath = await uploadObservationImage(body, request)

  if (!OPENAI_API_KEY) {
    const result = { ...fallback, storagePath }
    await persistObservation(result, body, request, "fallback")
    return json(result, 200)
  }

  const locationHint = typeof body.latitude === "number" && typeof body.longitude === "number"
    ? `Approximate observation coordinate: ${body.latitude.toFixed(3)}, ${body.longitude.toFixed(3)}.`
    : "No coordinate was provided."

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
            image_url: `data:${body.imageMimeType ?? "image/jpeg"};base64,${stripDataURLPrefix(body.imageBase64)}`,
          },
        ],
      }],
      text: {
        format: {
          type: "json_schema",
          name: "species_identification",
          schema: {
            type: "object",
            additionalProperties: false,
            required: ["commonName", "latinName", "rarity", "finish", "stars", "confidence", "note"],
            properties: {
              commonName: { type: "string" },
              latinName: { type: "string" },
              rarity: {
                type: "string",
                enum: ["Common", "Uncommon", "Rare", "Seasonal", "Local Special", "City Legend"],
              },
              finish: {
                type: "string",
                enum: ["Matte", "Colored Edge", "Metallic", "Iridescent", "Foil", "Holo Foil"],
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
  })

  if (!response.ok) {
    const detail = await response.text()
    return json({ error: "OpenAI identification failed", detail }, 502)
  }

  const payload = await response.json()
  const outputText = extractOutputText(payload)
  if (!outputText) {
    return json({ error: "OpenAI returned no structured text" }, 502)
  }

  const result = {
    ...JSON.parse(outputText) as SpeciesResult,
    storagePath,
  }
  await persistObservation(result, body, request, "cloud_api")
  return json(result, 200)
})

function extractOutputText(payload: unknown): string | undefined {
  if (!payload || typeof payload !== "object") return undefined

  const maybe = payload as {
    output_text?: string
    output?: Array<{ content?: Array<{ type?: string; text?: string }> }>
  }

  if (typeof maybe.output_text === "string") {
    return maybe.output_text
  }

  return maybe.output
    ?.flatMap((item) => item.content ?? [])
    .find((content) => content.type === "output_text" && typeof content.text === "string")
    ?.text
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  })
}

async function uploadObservationImage(request: IdentifyRequest, httpRequest: Request): Promise<string | undefined> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return undefined
  }

  const mimeType = request.imageMimeType ?? "image/jpeg"
  if (!["image/jpeg", "image/png", "image/heic", "image/heif"].includes(mimeType)) {
    return undefined
  }

  const userId = userIdFromAuthHeader(httpRequest)
  const clientId = sanitizePathSegment(request.clientId ?? "anonymous")
  const extension = imageExtension(mimeType)
  const storagePath = userId
    ? `${sanitizePathSegment(userId)}/${crypto.randomUUID()}.${extension}`
    : `devices/${clientId}/${crypto.randomUUID()}.${extension}`
  const uploadURL = `${SUPABASE_URL}/storage/v1/object/observations/${storagePath}`
  let imageBytes: Uint8Array

  try {
    imageBytes = decodeBase64Image(request.imageBase64)
  } catch {
    return undefined
  }
  const imageBody = imageBytes.buffer.slice(
    imageBytes.byteOffset,
    imageBytes.byteOffset + imageBytes.byteLength,
  ) as ArrayBuffer

  const response = await fetch(uploadURL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "apikey": SUPABASE_SERVICE_ROLE_KEY,
      "Content-Type": mimeType,
      "x-upsert": "false",
    },
    body: imageBody,
  }).catch(() => undefined)

  if (!response?.ok) {
    return undefined
  }

  return storagePath
}

async function persistObservation(
  result: SpeciesResult,
  request: IdentifyRequest,
  httpRequest: Request,
  source: "cloud_api" | "fallback",
) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return
  }

  const userId = userIdFromAuthHeader(httpRequest)

  await fetch(`${SUPABASE_URL}/rest/v1/observations`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "apikey": SUPABASE_SERVICE_ROLE_KEY,
      "Content-Type": "application/json",
      "Prefer": "return=minimal",
    },
    body: JSON.stringify({
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
  }).catch(() => undefined)
}

function flagEnabled(value: string | undefined): boolean {
  return ["1", "true", "yes"].includes((value ?? "").trim().toLowerCase())
}

function decodeBase64Image(imageBase64 = ""): Uint8Array {
  const normalized = stripDataURLPrefix(imageBase64)
  const binary = atob(normalized)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index)
  }
  return bytes
}

function stripDataURLPrefix(imageBase64 = ""): string {
  const commaIndex = imageBase64.indexOf(",")
  return commaIndex >= 0 ? imageBase64.slice(commaIndex + 1) : imageBase64
}

function sanitizePathSegment(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80) || "anonymous"
}

function imageExtension(mimeType: string): string {
  switch (mimeType) {
    case "image/png":
      return "png"
    case "image/heic":
      return "heic"
    case "image/heif":
      return "heif"
    default:
      return "jpg"
  }
}

function userIdFromAuthHeader(request: Request): string | null {
  const header = request.headers.get("Authorization")
  if (!header?.startsWith("Bearer ")) {
    return null
  }

  const token = header.slice("Bearer ".length)
  const parts = token.split(".")
  if (parts.length < 2) {
    return null
  }

  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))) as { sub?: string }
    return typeof payload.sub === "string" ? payload.sub : null
  } catch {
    return null
  }
}
