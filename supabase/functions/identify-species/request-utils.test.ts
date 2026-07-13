import {
  databaseAuthHeaders,
  decodeBase64Image,
  imageExtension,
  sanitizePathSegment,
  storagePathForObservation,
  stripDataURLPrefix,
  validObservationId,
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

Deno.test("accepts canonical observation UUIDs and rejects unsafe record ids", () => {
  assertEquals(
    validObservationId(" 0190A5F0-7B3A-7CC3-8A6B-2D90F7D88315 "),
    "0190a5f0-7b3a-7cc3-8a6b-2d90f7d88315",
    "canonical UUIDs are normalized for Postgres and Storage",
  );
  assertEquals(
    validObservationId("../../another-record"),
    undefined,
    "non-UUID ids are rejected",
  );
});

Deno.test("keeps signed-in Postgres writes behind RLS", () => {
  const signedIn = databaseAuthHeaders({
    verifiedUserId: "user-123",
    authorizationHeader: "Bearer user-token",
    anonKey: "anon-key",
    serviceRoleKey: "service-role",
  });
  assertEquals(
    signedIn?.Authorization,
    "Bearer user-token",
    "verified users keep their JWT so Postgres RLS owns the write",
  );
  assertEquals(
    signedIn?.apikey,
    "anon-key",
    "signed-in writes use the anon key",
  );

  const anonymous = databaseAuthHeaders({
    verifiedUserId: null,
    authorizationHeader: "Bearer anon-key",
    anonKey: "anon-key",
    serviceRoleKey: "service-role",
  });
  assertEquals(
    anonymous?.Authorization,
    "Bearer service-role",
    "anonymous Edge writes use the server credential",
  );

  assertEquals(
    databaseAuthHeaders({
      verifiedUserId: "user-123",
      authorizationHeader: "Bearer user-token",
      serviceRoleKey: "service-role",
    }),
    undefined,
    "signed-in writes fail closed when the anon key is unavailable",
  );
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
