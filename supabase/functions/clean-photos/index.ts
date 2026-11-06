// Removes photo files that nothing in the database uses. The database starts
// this once a day and decides which files are unused (find_unused_photos).
// Needs CLEANUP_SECRET. This uses the service role key, so it must run here.
import { createClient } from "npm:@supabase/supabase-js@2.49.8";
import { groupByBucket, secretsMatch, UnusedPhoto } from "./cleanup.ts";

const BATCH_SIZE = 200;

// A limit per run, so a mistake can never empty a bucket in one go.
const MAX_BATCHES = 5;

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

  // Without a secret set, nobody gets in.
  const secret = Deno.env.get("CLEANUP_SECRET");
  const given = request.headers.get("x-cleanup-secret");
  if (!secret || !given || !(await secretsMatch(given, secret))) {
    return jsonResponse(401, { code: "NOT_ALLOWED" });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  let removed = 0;
  for (let batch = 0; batch < MAX_BATCHES; batch++) {
    const { data, error } = await admin.rpc("find_unused_photos", {
      p_limit: BATCH_SIZE,
    });
    if (error) {
      console.error("Could not list unused photos", error.message);
      return jsonResponse(500, { code: "CLEANUP_FAILED", removed });
    }

    const photos = (data ?? []) as UnusedPhoto[];
    if (photos.length === 0) break;

    for (const [bucket, names] of groupByBucket(photos)) {
      const { error: removeError } = await admin.storage.from(bucket).remove(names);
      if (removeError) {
        console.error("Could not remove photos", bucket, removeError.message);
        return jsonResponse(500, { code: "CLEANUP_FAILED", removed });
      }
      removed += names.length;
    }
  }

  console.log(`Removed ${removed} unused photos`);
  return jsonResponse(200, { removed });
});
