// Permanently deletes the signed-in user's account.
// This needs the service role key, so it must run on the server.
import { createClient } from "npm:@supabase/supabase-js@2.49.8";

const AVATAR_BUCKET = "avatars";
const SHOP_BUCKETS = ["product-images", "shop-assets"];
const PAGE_SIZE = 500;

type Admin = ReturnType<typeof createClient>;

/** Removes every file in one folder. Throws if anything fails. */
async function removeFolder(admin: Admin, bucket: string, folder: string) {
  while (true) {
    const { data: files, error: listError } = await admin.storage
      .from(bucket)
      .list(folder, { limit: PAGE_SIZE });
    if (listError) throw listError;
    if (files.length === 0) return;

    const paths = files.map((file) => `${folder}/${file.name}`);
    const { error } = await admin.storage.from(bucket).remove(paths);
    if (error) throw error;
  }
}

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

  // Checked before anything is removed. The database also refuses the deletion.
  const { data: hasOpenOrders, error: ordersError } = await admin.rpc(
    "account_has_open_orders",
    { p_user_id: user.id },
  );
  if (ordersError) {
    console.error("Could not check orders", ordersError.message);
    return jsonResponse(500, { code: "DELETE_FAILED" });
  }
  if (hasOpenOrders) {
    return jsonResponse(409, { code: "OPEN_ORDERS" });
  }

  const { data: balance, error: balanceError } = await admin.rpc(
    "seller_commission_balance",
    { p_seller_id: user.id },
  );
  if (balanceError) {
    console.error("Could not check commission", balanceError.message);
    return jsonResponse(500, { code: "DELETE_FAILED" });
  }
  if (Number(balance) > 0) {
    return jsonResponse(409, { code: "OWES_COMMISSION" });
  }

  try {
    await removeFolder(admin, AVATAR_BUCKET, user.id);

    // Listing photos are public, so they must not outlive the account.
    const { data: shop, error: shopError } = await admin
      .from("shops")
      .select("id")
      .eq("seller_id", user.id)
      .maybeSingle();
    if (shopError) throw shopError;
    if (shop) {
      for (const bucket of SHOP_BUCKETS) {
        await removeFolder(admin, bucket, shop.id as string);
      }
    }
  } catch (error) {
    console.error("Could not remove files", error);
    return jsonResponse(500, { code: "DELETE_FAILED" });
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("Could not delete user", deleteError.message);
    return jsonResponse(500, { code: "DELETE_FAILED" });
  }

  return jsonResponse(200, { deleted: true });
});
