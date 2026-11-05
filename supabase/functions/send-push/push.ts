// The parts of sending a push that need no network, kept apart so they can be
// tested without Firebase.

export interface PushNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
}

/** The FCM HTTP v1 request for one phone. FCM data values must be strings. */
export function buildFcmMessage(notification: PushNotification, token: string) {
  const data: Record<string, string> = {
    notification_id: notification.id,
    type: notification.type,
  };
  for (const [key, value] of Object.entries(notification.data)) {
    if (value !== null && value !== undefined) data[key] = String(value);
  }
  return {
    message: {
      token,
      notification: { title: notification.title, body: notification.body },
      data,
    },
  };
}

/**
 * Whether FCM says this phone will never receive anything again, so its token
 * should be removed. Other errors, such as a quota limit, are worth retrying.
 */
export function isDeadToken(status: number, responseBody: string): boolean {
  if (status === 404) return true;
  return status === 400 && responseBody.includes("UNREGISTERED");
}

export interface ServiceAccount {
  client_email: string;
  private_key: string;
}

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

/** The signed token Google exchanges for an FCM access token. */
export async function buildServiceJwt(
  account: ServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));
  const pem = account.private_key
    .replace(/-----[A-Z ]+-----/g, "")
    .replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (char) => char.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;
}
