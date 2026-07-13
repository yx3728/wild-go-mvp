import {
  createIdentifySpeciesHandler,
  type IdentifySpeciesConfig,
} from "./index.ts";

type FetchCall = {
  url: string;
  method: string;
  headers: Headers;
  body?: BodyInit | null;
};

const validSpecies = JSON.stringify({
  commonName: "Blue Jay",
  latinName: "Cyanocitta cristata",
  rarity: "City Legend",
  finish: "Holo Foil",
  stars: 6,
  confidence: 0.92,
  note: "Bold city bird.",
  alternativeMatches: ["Steller's Jay"],
});

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

function config(fetcher: typeof fetch): IdentifySpeciesConfig {
  return {
    openAIModel: "gpt-test",
    openAIAPIKey: "openai-key",
    supabaseURL: "https://project.supabase.co",
    supabaseServiceRoleKey: "service-role",
    supabaseAnonKey: "anon-key",
    allowDemoIdentification: false,
    fetcher,
    logger: { error: () => undefined },
  };
}

function identifyRequest(authorization?: string): Request {
  return new Request("https://edge.test/identify-species", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(authorization ? { "Authorization": authorization } : {}),
    },
    body: JSON.stringify({
      imageBase64: btoa("wild-go-image"),
      imageMimeType: "image/jpeg",
      clientId: "test-device",
      observationId: "0190a5f0-7b3a-7cc3-8a6b-2d90f7d88315",
    }),
  });
}

function recordCall(
  calls: FetchCall[],
  input: RequestInfo | URL,
  init?: RequestInit,
): FetchCall {
  const call = {
    url: String(input),
    method: init?.method ?? "GET",
    headers: new Headers(init?.headers),
    body: init?.body,
  };
  calls.push(call);
  return call;
}

Deno.test("persists a successful identification without deleting its image", async () => {
  const calls: FetchCall[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const call = recordCall(calls, input, init);
    if (call.url === "https://api.openai.com/v1/responses") {
      return new Response(JSON.stringify({ output_text: validSpecies }), {
        status: 200,
      });
    }
    if (call.url.includes("/rest/v1/observations")) {
      return new Response(null, { status: 201 });
    }
    return new Response(null, { status: 200 });
  };

  const response = await createIdentifySpeciesHandler(config(fetcher))(
    identifyRequest(),
  );

  assertEquals(response.status, 200, "successful identification returns 200");
  assertEquals(calls.length, 3, "upload, OpenAI, and Postgres are called");
  assertEquals(calls[0].method, "POST", "image uploads first");
  assertEquals(
    calls.some((call) => call.method === "DELETE"),
    false,
    "successful images are retained",
  );
});

Deno.test("deletes a new image when OpenAI identification fails", async () => {
  const calls: FetchCall[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const call = recordCall(calls, input, init);
    if (call.url === "https://api.openai.com/v1/responses") {
      return new Response("model unavailable", { status: 503 });
    }
    return new Response(null, { status: 200 });
  };

  const response = await createIdentifySpeciesHandler(config(fetcher))(
    identifyRequest(),
  );
  const cleanup = calls.find((call) => call.method === "DELETE");

  assertEquals(response.status, 502, "OpenAI failure is surfaced");
  assert(cleanup !== undefined, "uploaded image is deleted");
  assertEquals(
    cleanup.headers.get("Authorization"),
    "Bearer service-role",
    "cleanup uses the server credential",
  );
  const cleanupBody = JSON.parse(String(cleanup.body)) as {
    prefixes: string[];
  };
  assert(
    cleanupBody.prefixes[0].startsWith("devices/test-device/"),
    "cleanup targets the uploaded device path",
  );
  assertEquals(
    calls.some((call) => call.url.includes("/rest/v1/observations")),
    false,
    "Postgres is not called after model failure",
  );
});

Deno.test("deletes a new image when Postgres persistence fails", async () => {
  const calls: FetchCall[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const call = recordCall(calls, input, init);
    if (call.url === "https://api.openai.com/v1/responses") {
      return new Response(JSON.stringify({ output_text: validSpecies }), {
        status: 200,
      });
    }
    if (call.url.includes("/rest/v1/observations")) {
      return new Response("database unavailable", { status: 503 });
    }
    return new Response(null, { status: 200 });
  };

  const response = await createIdentifySpeciesHandler(config(fetcher))(
    identifyRequest(),
  );

  assertEquals(response.status, 502, "persistence failure is surfaced");
  assertEquals(
    calls.at(-1)?.method,
    "DELETE",
    "Storage cleanup follows the failed Postgres write",
  );
});

Deno.test("preserves an existing signed-in image and keeps Postgres behind RLS", async () => {
  const calls: FetchCall[] = [];
  const fetcher: typeof fetch = async (input, init) => {
    const call = recordCall(calls, input, init);
    if (call.url.endsWith("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "user-123" }), { status: 200 });
    }
    if (call.url.includes("/rest/v1/observations") && call.method === "GET") {
      return new Response(JSON.stringify([{ id: "existing" }]), {
        status: 200,
      });
    }
    if (call.url === "https://api.openai.com/v1/responses") {
      return new Response("model unavailable", { status: 503 });
    }
    return new Response(null, { status: 200 });
  };

  const response = await createIdentifySpeciesHandler(config(fetcher))(
    identifyRequest("Bearer user-token"),
  );
  const preflight = calls.find((call) =>
    call.url.includes("/rest/v1/observations") && call.method === "GET"
  );

  assertEquals(response.status, 502, "model failure is surfaced");
  assert(preflight !== undefined, "signed-in retry checks for an existing row");
  assertEquals(
    preflight.headers.get("Authorization"),
    "Bearer user-token",
    "preflight keeps the verified user JWT",
  );
  assertEquals(
    preflight.headers.get("apikey"),
    "anon-key",
    "preflight uses the anon key so RLS owns the read",
  );
  assertEquals(
    calls.some((call) => call.method === "DELETE"),
    false,
    "a failed retry does not delete an image already referenced by Postgres",
  );
});
