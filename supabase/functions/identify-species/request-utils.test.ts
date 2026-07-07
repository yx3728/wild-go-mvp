import {
  decodeBase64Image,
  imageExtension,
  sanitizePathSegment,
  storagePathForObservation,
  stripDataURLPrefix,
  verifiedUserIdFromAuthHeader,
} from "./request-utils.ts";

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

Deno.test("decodes raw and data URL base64 observation images", () => {
  const encoded = btoa("wild-go");
  assertEquals(
    stripDataURLPrefix(`data:image/jpeg;base64,${encoded}`),
    encoded,
    "data URL prefix is removed",
  );
  assertEquals(
    new TextDecoder().decode(decodeBase64Image(encoded)),
    "wild-go",
    "raw base64 decodes",
  );
  assertEquals(
    new TextDecoder().decode(
      decodeBase64Image(`data:image/jpeg;base64,${encoded}`),
    ),
    "wild-go",
    "data URL base64 decodes",
  );
});

Deno.test("builds private Storage paths for signed-in and device observations", () => {
  assertEquals(
    storagePathForObservation({
      userId: "A1B2-USER",
      clientId: "ignored",
      mimeType: "image/png",
      objectId: "card-id",
    }),
    "a1b2-user/card-id.png",
    "signed-in paths are rooted by verified user id",
  );
  assertEquals(
    storagePathForObservation({
      clientId: "Joey's iPhone / NYC",
      mimeType: "image/heic",
      objectId: "card-id",
    }),
    "devices/joey-s-iphone-nyc/card-id.heic",
    "anonymous paths are rooted by sanitized device id",
  );
  assertEquals(
    storagePathForObservation({
      clientId: "",
      mimeType: "image/webp",
      objectId: "card-id",
    }),
    "devices/anonymous/card-id.jpg",
    "unsupported image MIME types fall back to jpg path suffix",
  );
});

Deno.test("sanitizes path segments to Storage-policy-safe folder names", () => {
  assertEquals(
    sanitizePathSegment("../City Legend ## Device"),
    "city-legend-device",
    "unsafe characters are folded into dashes",
  );
  assertEquals(
    sanitizePathSegment(""),
    "anonymous",
    "empty segments fall back to anonymous",
  );
  assertEquals(
    sanitizePathSegment("A".repeat(120)).length,
    80,
    "segments are capped to a bounded length",
  );
  assertEquals(imageExtension("image/heif"), "heif", "HEIF keeps its suffix");
});

Deno.test("verifies signed-in Supabase user tokens before trusting user ids", async () => {
  let requestedURL = "";
  let authorization = "";
  let apiKey = "";
  const fetcher: typeof fetch = async (input, init) => {
    requestedURL = String(input);
    const headers = new Headers(init?.headers);
    authorization = headers.get("Authorization") ?? "";
    apiKey = headers.get("apikey") ?? "";
    return new Response(JSON.stringify({ id: "user-123" }), { status: 200 });
  };

  const userId = await verifiedUserIdFromAuthHeader(
    new Request("https://edge.test/identify", {
      headers: { "Authorization": "Bearer user-token" },
    }),
    {
      supabaseUrl: "https://project.supabase.co",
      authApiKey: "anon-key",
      serviceRoleKey: "service-role",
      fetcher,
    },
  );

  assertEquals(userId, "user-123", "verified Auth response id is returned");
  assertEquals(
    requestedURL,
    "https://project.supabase.co/auth/v1/user",
    "Auth verifier calls the Supabase user endpoint",
  );
  assertEquals(
    authorization,
    "Bearer user-token",
    "user bearer token is forwarded to Auth",
  );
  assertEquals(apiKey, "anon-key", "anon key is used for Auth verification");
});

Deno.test("does not trust missing or service-role authorization as user identity", async () => {
  let fetchCalls = 0;
  const fetcher: typeof fetch = async () => {
    fetchCalls += 1;
    return new Response(JSON.stringify({ id: "should-not-be-used" }), {
      status: 200,
    });
  };

  const missing = await verifiedUserIdFromAuthHeader(
    new Request("https://edge.test/identify"),
    {
      supabaseUrl: "https://project.supabase.co",
      authApiKey: "anon-key",
      serviceRoleKey: "service-role",
      fetcher,
    },
  );
  const serviceRole = await verifiedUserIdFromAuthHeader(
    new Request("https://edge.test/identify", {
      headers: { "Authorization": "Bearer service-role" },
    }),
    {
      supabaseUrl: "https://project.supabase.co",
      authApiKey: "anon-key",
      serviceRoleKey: "service-role",
      fetcher,
    },
  );

  assertEquals(missing, null, "missing Authorization is anonymous");
  assertEquals(serviceRole, null, "service role is never treated as user id");
  assertEquals(fetchCalls, 0, "Auth endpoint is not called for ignored tokens");
});

Deno.test("falls back to Auth sub claim when id is absent", async () => {
  const fetcher: typeof fetch = async () =>
    new Response(JSON.stringify({ sub: "subject-user" }), { status: 200 });

  const userId = await verifiedUserIdFromAuthHeader(
    new Request("https://edge.test/identify", {
      headers: { "Authorization": "Bearer user-token" },
    }),
    {
      supabaseUrl: "https://project.supabase.co",
      authApiKey: "anon-key",
      fetcher,
    },
  );

  assert(userId === "subject-user", "Auth sub claim is accepted as fallback");
});
