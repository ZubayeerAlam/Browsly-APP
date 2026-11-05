// The review logic. It has no network or database code, so tests can run it with
// a fake AI and a fake queue.
import { POLICY_VERSION, REASON_CODES } from "./policy.ts";

export type Decision = "approve" | "suspicious" | "reject";

export interface ModerationResult {
  decision: Decision;
  reasonCode: string;
  reason: string;
}

export interface ListingImage {
  mimeType: string;
  base64: string;
}

/** Only what the AI needs. It must never include seller details. */
export interface ListingForReview {
  title: string;
  description: string;
  categoryName: string;
  condition: string;
  price: number;
  options: unknown[];
  images: ListingImage[];
}

export interface ModerationProvider {
  readonly name: string;
  readonly model: string;
  review(listing: ListingForReview): Promise<ModerationResult>;
}

/** The AI's quota has run out, so there is no point trying more jobs now. */
export class QuotaError extends Error {}

export interface ModerationJob {
  reviewId: string;
  contentHash: string;
  title: string;
  description: string;
  categoryName: string;
  condition: string;
  price: number;
  options: unknown[];
  imagePaths: string[];
}

export interface ModerationStore {
  claim(limit: number): Promise<ModerationJob[]>;
  loadImage(path: string): Promise<ListingImage>;
  apply(
    job: ModerationJob,
    provider: ModerationProvider,
    policyVersion: string,
    result: ModerationResult,
  ): Promise<string>;
  fail(job: ModerationJob, message: string): Promise<void>;
}

/**
 * Checks the AI's reply. Anything unexpected throws, which leaves the product in
 * review for a retry. A malformed reply can never publish a product.
 */
export function parseModerationReply(text: string): ModerationResult {
  let reply: unknown;
  try {
    reply = JSON.parse(text);
  } catch {
    throw new Error("The AI reply was not JSON");
  }
  if (typeof reply !== "object" || reply === null || Array.isArray(reply)) {
    throw new Error("The AI reply was not an object");
  }
  const { decision, reason_code: reasonCode, reason } = reply as Record<
    string,
    unknown
  >;
  if (decision !== "approve" && decision !== "suspicious" && decision !== "reject") {
    throw new Error("The AI reply had an unknown decision");
  }
  if (
    typeof reasonCode !== "string" ||
    !(REASON_CODES as readonly string[]).includes(reasonCode)
  ) {
    throw new Error("The AI reply had an unknown reason code");
  }
  if (typeof reason !== "string" || reason.trim().length === 0) {
    throw new Error("The AI reply had no reason");
  }
  // An approval that also names a broken rule contradicts itself, so a person
  // should look at it.
  if (decision === "approve" && reasonCode !== "none") {
    return { decision: "suspicious", reasonCode, reason: reason.trim() };
  }
  return { decision, reasonCode, reason: reason.trim() };
}

export interface QueueSummary {
  applied: number;
  discarded: number;
  failed: number;
}

/** Works through due jobs. One failed job never stops the others. */
export async function processQueue(
  store: ModerationStore,
  provider: ModerationProvider,
  limit = 5,
): Promise<QueueSummary> {
  const summary: QueueSummary = { applied: 0, discarded: 0, failed: 0 };
  const jobs = await store.claim(limit);
  let quotaUsedUp = false;

  for (const job of jobs) {
    if (quotaUsedUp) {
      await store.fail(job, "AI quota used up");
      summary.failed++;
      continue;
    }
    try {
      const images = await Promise.all(job.imagePaths.map(store.loadImage));
      const result = await provider.review({
        title: job.title,
        description: job.description,
        categoryName: job.categoryName,
        condition: job.condition,
        price: job.price,
        options: job.options,
        images,
      });
      const outcome = await store.apply(job, provider, POLICY_VERSION, result);
      if (outcome === "applied") {
        summary.applied++;
      } else {
        summary.discarded++;
      }
    } catch (error) {
      quotaUsedUp = error instanceof QuotaError;
      const message = error instanceof Error ? error.message : String(error);
      console.error(`Review ${job.reviewId} failed: ${message}`);
      await store.fail(job, message);
      summary.failed++;
    }
  }
  return summary;
}
