import {
  buildFcmMessage,
  buildServiceJwt,
  isDeadToken,
} from "./push.ts";

function assertEquals(actual: unknown, expected: unknown) {
  const a = JSON.stringify(actual);
  const b = JSON.stringify(expected);
  if (a !== b) throw new Error(`Expected ${b}, got ${a}`);
}

Deno.test("builds a message with string data for one phone", () => {
  const message = buildFcmMessage({
    id: "n1",
    type: "new_order",
    title: "New order",
    body: "Open Sales",
    data: { group_id: "g1", count: 2, nothing: null },
  }, "token-1");

  assertEquals(message, {
    message: {
      token: "token-1",
      notification: { title: "New order", body: "Open Sales" },
      data: {
        notification_id: "n1",
        type: "new_order",
        group_id: "g1",
        count: "2",
      },
    },
  });
});

Deno.test("only tokens FCM says are gone count as dead", () => {
  assertEquals(isDeadToken(404, ""), true);
  assertEquals(isDeadToken(400, '{"errorCode":"UNREGISTERED"}'), true);
  assertEquals(isDeadToken(400, '{"errorCode":"INVALID_ARGUMENT"}'), false);
  assertEquals(isDeadToken(429, "QUOTA_EXCEEDED"), false);
  assertEquals(isDeadToken(500, ""), false);
});

Deno.test("signs a token Google can verify", async () => {
  const keys = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", keys.privateKey),
  );
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...pkcs8))
  }\n-----END PRIVATE KEY-----\n`;

  const jwt = await buildServiceJwt(
    { client_email: "a@b.test", private_key: pem },
    1000,
  );

  const [header, claims, signature] = jwt.split(".");
  const decode = (part: string) =>
    Uint8Array.from(
      atob(part.replaceAll("-", "+").replaceAll("_", "/").padEnd(
        Math.ceil(part.length / 4) * 4,
        "=",
      )),
      (char) => char.charCodeAt(0),
    );
  const parsed = JSON.parse(new TextDecoder().decode(decode(claims)));
  assertEquals(parsed.iss, "a@b.test");
  assertEquals(parsed.exp, 4600);
  assertEquals(
    await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      keys.publicKey,
      decode(signature),
      new TextEncoder().encode(`${header}.${claims}`),
    ),
    true,
  );
});
