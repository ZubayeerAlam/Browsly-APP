export interface UnusedPhoto {
  bucket_id: string;
  name: string;
}

/** Storage removes files one bucket at a time. */
export function groupByBucket(photos: UnusedPhoto[]): Map<string, string[]> {
  const groups = new Map<string, string[]>();
  for (const { bucket_id, name } of photos) {
    groups.set(bucket_id, [...(groups.get(bucket_id) ?? []), name]);
  }
  return groups;
}

/** Compares in constant time, so a wrong guess reveals nothing. */
export async function secretsMatch(given: string, expected: string) {
  const digest = async (text: string) =>
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)),
    );
  const [a, b] = await Promise.all([digest(given), digest(expected)]);
  return a.reduce((difference, byte, i) => difference | (byte ^ b[i]), 0) === 0;
}
