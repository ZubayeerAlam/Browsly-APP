// Reviews queued listings with the AI. Called by the database, never by the app.
// With no AI configured, or the AI down, products simply stay in review.
import { encodeBase64 } from "jsr:@std/encoding@1/base64";
import { createClient } from "npm:@supabase/supabase-js@2.49.8";

import {
  ModerationJob,
  ModerationProvider,
  ModerationStore,
  processQueue,
} from "./moderation.ts";
import { FakeProvider, GeminiProvider } from "./providers.ts";

const BUCKET = "product-images";
const DEFAULT_MODEL = "gemini-2.5-flash-lite";

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Compares digests, so the time taken reveals nothing about the secret. */
async function secretsMatch(given: string, expected: string) {
  const digest = async (text: string) =>
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)),
    );
  const [a, b] = await Promise.all([digest(given), digest(expected)]);
  return a.reduce((difference, byte, i) => difference | (byte ^ b[i]), 0) === 0;
}

function createProvider(): ModerationProvider | null {
  if (Deno.env.get("MODERATION_PROVIDER") === "fake") {
    return new FakeProvider();
  }
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return null;
  return new GeminiProvider(
    apiKey,
    Deno.env.get("GEMINI_MODEL") ?? DEFAULT_MODEL,
  );
}

function createStore(): ModerationStore {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  return {
    async claim(limit) {
      const { data, error } = await admin.rpc("claim_moderation_jobs", {
        p_limit: limit,
      });
      if (error) throw new Error(error.message);
      return (data as Record<string, unknown>[]).map((row) => ({
        reviewId: row.review_id as string,
        contentHash: row.content_hash as string,
        title: row.title as string,
        description: row.description as string,
        categoryName: row.category_name as string,
        condition: row.condition as string,
        price: Number(row.price),
        options: row.options as unknown[],
        imagePaths: row.image_paths as string[],
      }));
    },

    async loadImage(path) {
      const { data, error } = await admin.storage.from(BUCKET).download(path);
      if (error) throw new Error(`Could not load a photo: ${error.message}`);
      return {
        mimeType: data.type || "image/jpeg",
        base64: encodeBase64(new Uint8Array(await data.arrayBuffer())),
      };
    },

    async apply(job, provider, policyVersion, result) {
      const { data, error } = await admin.rpc("apply_moderation_result", {
        p_review_id: job.reviewId,
        p_content_hash: job.contentHash,
        p_provider: provider.name,
        p_model: provider.model,
        p_policy_version: policyVersion,
        p_decision: result.decision,
        p_reason_code: result.reasonCode,
        p_reason: result.reason,
      });
      if (error) throw new Error(error.message);
      return data as string;
    },

    async fail(job: ModerationJob, message: string) {
      const { error } = await admin.rpc("record_moderation_failure", {
        p_review_id: job.reviewId,
        p_error: message,
      });
      if (error) console.error("Could not record a failure", error.message);
    },
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse(405, { code: "METHOD_NOT_ALLOWED" });
  }

  // Without a secret set, nobody gets in.
  const secret = Deno.env.get("MODERATION_SECRET");
  const given = request.headers.get("x-moderation-secret");
  if (!secret || !given || !(await secretsMatch(given, secret))) {
    return jsonResponse(401, { code: "NOT_ALLOWED" });
  }

  const provider = createProvider();
  if (!provider) {
    console.warn("No AI is configured, so products stay in review");
    return jsonResponse(200, { skipped: "NO_AI_CONFIGURED" });
  }

  try {
    const summary = await processQueue(createStore(), provider);
    return jsonResponse(200, { ...summary });
  } catch (error) {
    console.error("The review run failed", error);
    return jsonResponse(500, { code: "REVIEW_RUN_FAILED" });
  }
});
