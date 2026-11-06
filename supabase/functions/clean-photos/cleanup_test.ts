import { groupByBucket, secretsMatch } from "./cleanup.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assert(condition: boolean) {
  if (!condition) throw new Error("Expected true");
}

Deno.test("files are grouped by bucket", () => {
  const groups = groupByBucket([
    { bucket_id: "avatars", name: "a.jpg" },
    { bucket_id: "product-images", name: "b.jpg" },
    { bucket_id: "avatars", name: "c.jpg" },
  ]);
  assertEquals(groups.get("avatars"), ["a.jpg", "c.jpg"]);
  assertEquals(groups.get("product-images"), ["b.jpg"]);
  assertEquals(groups.size, 2);
});

Deno.test("no files means no work", () => {
  assertEquals(groupByBucket([]).size, 0);
});

Deno.test("only the exact secret matches", async () => {
  assert(await secretsMatch("right", "right"));
  assert(!(await secretsMatch("wrong", "right")));
  assert(!(await secretsMatch("", "right")));
});
