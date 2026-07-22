export type AuthVerificationConfig = {
  supabaseUrl?: string;
  authApiKey?: string;
  serviceRoleKey?: string;
  fetcher?: typeof fetch;
};

export type ObservationStoragePathOptions = {
  userId?: string | null;
  clientId?: string;
  mimeType: string;
  objectId?: string;
};

export type DatabaseAuthOptions = {
  verifiedUserId?: string | null;
  authorizationHeader?: string | null;
  anonKey?: string;
  serviceRoleKey?: string;
};

export function decodeBase64Image(imageBase64 = ""): Uint8Array {
  const normalized = stripDataURLPrefix(imageBase64);
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

export function stripDataURLPrefix(imageBase64 = ""): string {
  const commaIndex = imageBase64.indexOf(",");
  return commaIndex >= 0 ? imageBase64.slice(commaIndex + 1) : imageBase64;
}

export function sanitizePathSegment(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80) || "anonymous";
}

export function imageExtension(mimeType: string): string {
  switch (mimeType) {
    case "image/png":
      return "png";
    case "image/heic":
      return "heic";
    case "image/heif":
      return "heif";
    default:
      return "jpg";
  }
}

export function validObservationId(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim().toLowerCase();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(normalized)
    ? normalized
    : undefined;
}

export function databaseAuthHeaders({
  verifiedUserId,
  authorizationHeader,
  anonKey,
  serviceRoleKey,
}: DatabaseAuthOptions): Record<string, string> | undefined {
  if (
    verifiedUserId &&
    authorizationHeader?.startsWith("Bearer ") &&
    anonKey
  ) {
    return {
      "Authorization": authorizationHeader,
      "apikey": anonKey,
    };
  }

  if (!verifiedUserId && serviceRoleKey) {
    return {
      "Authorization": `Bearer ${serviceRoleKey}`,
      "apikey": serviceRoleKey,
    };
  }

  return undefined;
}

export function storagePathForObservation({
  userId,
  clientId = "anonymous",
  mimeType,
  objectId = crypto.randomUUID(),
}: ObservationStoragePathOptions): string {
  const extension = imageExtension(mimeType);
  if (userId) {
    return `${sanitizePathSegment(userId)}/${objectId}.${extension}`;
  }
  return `devices/${sanitizePathSegment(clientId)}/${objectId}.${extension}`;
}

export async function verifiedUserIdFromAuthHeader(
  request: Request,
  {
    supabaseUrl,
    authApiKey,
    serviceRoleKey,
    fetcher = fetch,
  }: AuthVerificationConfig,
): Promise<string | null> {
  const header = request.headers.get("Authorization");
  if (!header?.startsWith("Bearer ")) {
    return null;
  }

  const token = header.slice("Bearer ".length);
  if (!supabaseUrl || !authApiKey || token === serviceRoleKey) {
    return null;
  }

  const response = await fetcher(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      "Authorization": `Bearer ${token}`,
      "apikey": authApiKey,
    },
  }).catch(() => undefined);

  if (!response?.ok) {
    return null;
  }

  const payload = await response.json().catch(() => null) as {
    id?: string;
    sub?: string;
  } | null;
  if (typeof payload?.id === "string") {
    return payload.id;
  }
  return typeof payload?.sub === "string" ? payload.sub : null;
}
