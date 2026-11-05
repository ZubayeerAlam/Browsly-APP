# Browsly Build Tracker

Full details are in [plan.md](plan.md).

**How this works**

- We build one step at a time, in order.
- `[x]` means the task is finished and its tests or checks pass.
- A step is complete only when its "Done when" check passes.

**Business rules to keep in mind**

- 1% commission on the listing price, excluding delivery (৳1,000 item = ৳10).
- Fixed prices with no bargaining, including for Cash on Delivery.
- Order status: Pending → Packaging → Out for delivery → Complete.
- AI reviews products first. Suspicious or rejected products go to the admin portal.

## Progress

- [x] Planning: `plan.md` and `build.md` created
- [x] Step 0: Foundation
- [ ] Step 1: Accounts (in progress: needs real SMS and the rest of the Android test)
- [x] Step 2: Marketplace
- [ ] Step 3: Selling and AI review (in progress: needs your Gemini key and policy approval)
- [x] Step 4: Buying
- [ ] Step 5: Sales and commission
- [ ] Step 6: Chat and trust
- [ ] Step 7: Admin panel
- [ ] Step 8: Launch prep

---

## Step 0: Foundation

- [x] Set permanent app ID (`com.browsly.app`)
- [x] Remove unused platform folders
- [x] Add environment configuration (`--dart-define-from-file=env.json`)
- [x] Add core packages (other packages are added in the step that needs them)
- [x] Create folder structure, error types and base state
- [x] Apply theme from demo UI (colours and Inter font)
- [x] Build shared loading, empty and error widgets
- [x] Set up GoRouter with five tabs and auth redirects
- [x] Initialise Supabase locally
- [x] Add first migrations and seed data (9 database tests pass)
- [x] Set up CI (first run on GitHub passed)

**Done when:** the app opens with all five tabs, `supabase db reset` works, and `flutter analyze` and `flutter test` pass.

**Status:** complete. The app is verified on the iOS Simulator, the Android build succeeds, and the database checks and CI pass.

## Step 1: Accounts

- [x] `profiles` table, signup trigger, RLS and tests
- [x] Email sign-in and password reset
- [x] Google sign-in (tested on a real Android phone against the local server; still to set up for production)
- [x] Phone OTP and rate limits (tested with test numbers)
- [ ] Real Bangladesh SMS provider (**needs your provider account**)
- [x] Phone verification gate
- [x] Profile and avatar (photo location data is removed before upload)
- [x] Addresses with Bangladesh regions
- [x] Account deletion (`delete-account`)
- [ ] Finish testing this step on a real Android phone. Passed on a moto g96: Google, email and phone sign-in, phone verification, addresses. Still to test: password reset, profile photo, account deletion

**Done when:** all three sign-in methods work on a real device, and users cannot read each other's private data.

**Status:** in progress. All three sign-in methods work on a real Android phone against the local server, using test numbers for phone sign-in. Real emails and texts aren't sent locally. To finish: real SMS, and the rest of the Android test.

## Step 2: Marketplace

- [x] Catalog tables, indexes, RLS and dev seed
- [x] `search_products`
- [x] Home screen
- [x] Product list, search and filter screens
- [x] Product details with colours, sizes, discount price, share and Chat with seller placeholder
- [x] Shop page
- [x] Wishlist
- [x] Paging, image caching, and empty and error states

**Done when:** a guest can browse, search and filter seeded products, and a logged-in user can save to the wishlist.

**Status:** complete. Verified on the iOS Simulator against the local database, using demo data. The Android build succeeds, but the screens haven't been run on Android yet. That test is covered by the open Android task in Step 1.

## Step 3: Selling and AI review

- [x] `become_seller` and shop setup (logo included; shop banner is not built yet)
- [x] Upload policies for the storage buckets
- [x] Post flow from the demo (max 5 JPG or PNG photos) with image compression and drafts
- [x] Pass product photos through `preparePhotoForUpload` so location data is removed, then check the stored file
- [ ] Prohibited-products policy (draft written in `docs/prohibited_products_policy.md`; **needs your approval**)
- [ ] Test the free AI model (`gemini-2.5-flash-lite` is set as the default; **needs your Gemini API key**)
- [x] `moderate-product`, adapter, queue, retries and tests (tested with a fake AI)
- [x] `admin_decide_product` (server only; the admin screens are Step 7)
- [x] Route suspicious, rejected and timed-out products to `admin_review`
- [x] My Posts with rejection reason, edit and resubmit, pause and delete
- [x] Edits to reviewed fields return the product to review (done in `save_product`, the only way clients can edit)
- [x] Remove a seller's photos from storage when their account is deleted

**Done when:** a valid listing goes live through AI approval, a suspicious or prohibited one reaches the admin queue, and an AI outage never publishes a product.

**Status:** in progress. All of this works on the iOS Simulator and the local stack with a fake AI. To finish: test the real Gemini model and approve the policy.

## Step 4: Buying

- [x] Cart table and repository
- [x] Point cart and order items at variants without breaking turned-off ones (`save_product` turns variants off rather than deleting them)
- [x] Cart button on product cards, and cart icon in the Dashboard top bar
- [x] Connect the Add to Cart and Buy Now buttons on product details
- [x] Seller-grouped cart screen
- [x] Buy Now from product details
- [x] Order tables, RLS and price snapshots
- [x] `place_order`, with race and rollback tests (`supabase/scripts/place_order_race.sh`)
- [x] Checkout screen with friendly error handling
- [x] My Orders and order details
- [x] Buyer cancellation
- [x] Block account deletion while orders are open, and keep order records after deletion

**Done when:** a buyer can order from two sellers, a race for the last item gives one success and one `OUT_OF_STOCK`, and a double tap creates one order.

**Status:** complete. Verified on the iOS Simulator and a real Android phone (moto g96, Android 16) against the local database, using a test number.

## Step 5: Sales and commission

- [ ] `update_group_status`, allowing only valid status changes
- [ ] Cancel and failed delivery, with stock restored
- [ ] Sales tabs, order details and buyer contact information
- [ ] Buyer status timeline: Pending → Packaging → Out for delivery → Complete
- [ ] Complete step: cash record, 1% commission ledger entry and rate snapshot
- [ ] Add to the product's `sold_count` on Complete
- [ ] Commission screen
- [ ] Block posting when over the unpaid limit
- [ ] Decide what happens to unpaid commission when a seller deletes their account

**Done when:** a ৳1,000 item charges exactly ৳10 on Complete with delivery excluded, cancelled and failed orders charge nothing, and sellers see only their own orders.

## Step 6: Chat and trust

- [ ] `conversations` and `messages` tables, RLS and tests
- [ ] Chat RPCs, Realtime, conversation list, chat room and unread count
- [ ] Connect "Chat with seller" on product details (it says "coming soon" for now), and add it to order screens
- [ ] Chat and notification icons in the Dashboard top bar
- [ ] Report a message
- [ ] FCM setup, device tokens, `send-push` and notification centre
- [ ] Tell sellers about new and cancelled orders
- [ ] Tell sellers the review result, and refresh My Posts when it arrives (today it needs a pull to refresh)
- [ ] `track_event` and app tracking (view = details opened, click = card tapped)
- [ ] Nightly rollup and `get_seller_stats`
- [ ] Statistics and Dashboard with real data (clicks, sales, views and rating cards, View Insights)
- [ ] Reviews and rating updates, including the review list on product details
- [ ] Reports

**Done when:** chat works in real time between two devices and only its two participants can read it, push arrives, and Statistics show real numbers.

## Step 7: Admin panel

- [ ] Create `admin_web`, admin login and `is_admin()` checks
- [ ] Product Review queue: listing, images, AI reason, approve or reject with a reason
- [ ] Overview (including queue count), users, products, orders
- [ ] Suspending a seller also turns off their shop, which hides their products
- [ ] Categories, settings (commission rate and limits), banners
- [ ] Reports and settlement recording
- [ ] Audit tests

**Done when:** an admin can decide queued products and record a settlement, and a non-admin is refused by the server.

## Step 8: Launch prep

- [ ] Set the production Google redirect URL, and use https for the production server
- [ ] Complete RLS audit and secret scan
- [ ] Daily clean-up of photo files that no listing uses
- [ ] Set production secrets: `project_url` and `moderation_secret` in the Vault, and `MODERATION_SECRET`, `GEMINI_API_KEY` and `GEMINI_MODEL` on the function. Never set `MODERATION_PROVIDER` there
- [ ] Performance check with large seed data. At 50,000 products, browsing took about 0.5 seconds and a search on a very common word took 2.6 seconds
- [ ] Terms, privacy policy, seller terms and listing policy (legal review)
- [ ] App icons and store listings
- [ ] Staging → production migration rehearsal and backups. Apply only `seed.sql` to production, never `seed_dev.sql`, and never use `db push --include-seed`
- [ ] Closed beta with real sellers
- [ ] Fix beta issues
- [ ] Submit to Google Play and the App Store

**Done when:** every check in the Verification section of `plan.md` passes and both stores accept the app.
