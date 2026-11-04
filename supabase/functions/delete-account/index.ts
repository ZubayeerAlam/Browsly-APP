// Permanently deletes the signed-in user's account.
// This needs the service role key, so it must run on the server.
import { createClient } from "npm:@supabase/supabase-js@2.49.8";

const AVATAR_BUCKET = "avatars";

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse(405, { code: "METHOD_NOT_ALLOWED" });
  }

  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) {
    return jsonResponse(401, { code: "NOT_SIGNED_IN" });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  // The user comes from the verified token, never from the request body.
  const { data: { user }, error: userError } = await admin.auth.getUser(token);
  if (userError || !user) {
    return jsonResponse(401, { code: "NOT_SIGNED_IN" });
  }

  const { data: files, error: listError } = await admin.storage
    .from(AVATAR_BUCKET)
    .list(user.id);
  if (listError) {
    console.error("Could not list avatar files", listError.message);
    return jsonResponse(500, { code: "DELETE_FAILED" });
  }

  if (files.length > 0) {
    const paths = files.map((file) => `${user.id}/${file.name}`);
    const { error } = await admin.storage.from(AVATAR_BUCKET).remove(paths);
    if (error) {
      console.error("Could not remove avatar files", error.message);
      return jsonResponse(500, { code: "DELETE_FAILED" });
    }
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("Could not delete user", deleteError.message);
    return jsonResponse(500, { code: "DELETE_FAILED" });
  }

  return jsonResponse(200, { deleted: true });
});
