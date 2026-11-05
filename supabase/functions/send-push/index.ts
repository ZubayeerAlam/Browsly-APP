// Delivers one notification to the user's phones through Firebase Cloud Messaging.
// The database calls this with a shared secret. A failure here never loses the
// notification, because it is already saved for the in-app notification centre.
//
// Needs PUSH_SECRET and FIREBASE_SERVICE_ACCOUNT (the JSON from Firebase). Until
// those are set, it does nothing.
import { createClient } from "npm:@supabase/supabase-js@2.49.8";
import {
  buildFcmMessage,
  buildServiceJwt,
  isDeadToken,
  type PushNotification,
  type ServiceAccount,
} from "./push.ts";

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const assertion = await buildServiceJwt(
    account,
    Math.floor(Date.now() / 1000),
  );
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`Google refused: ${response.status}`);
  return (await response.json()).access_token as string;
}

Deno.serve(async (request) => {
  const secret = Deno.env.get("PUSH_SECRET");
  if (!secret || request.headers.get("x-push-secret") !== secret) {
    return jsonResponse(401, { code: "UNAUTHORIZED" });
  }

  const accountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!accountJson) return jsonResponse(200, { skipped: "not configured" });

  const { notification_id: notificationId } = await request.json();
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const { data: notification, error } = await admin
    .from("notifications")
    .select("id, user_id, type, title, body, data, read_at")
    .eq("id", notificationId)
    .maybeSingle();
  if (error) return jsonResponse(500, { code: "READ_FAILED" });
  if (!notification || notification.read_at) {
    return jsonResponse(200, { skipped: "nothing to send" });
  }

  const { data: devices, error: devicesError } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_id", notification.user_id);
  if (devicesError) return jsonResponse(500, { code: "READ_FAILED" });
  if (devices.length === 0) return jsonResponse(200, { sent: 0 });

  const account = JSON.parse(accountJson) as ServiceAccount & {
    project_id: string;
  };
  const accessToken = await getAccessToken(account);
  const url =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let sent = 0;
  for (const { token } of devices) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(
        buildFcmMessage(notification as PushNotification, token as string),
      ),
    });
    if (response.ok) {
      sent++;
    } else if (isDeadToken(response.status, await response.text())) {
      await admin.from("device_tokens").delete().eq("token", token);
    }
  }
  return jsonResponse(200, { sent });
});
