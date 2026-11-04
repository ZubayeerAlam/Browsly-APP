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
- [ ] Step 1: Accounts (in progress: needs Google, SMS and an Android test)
- [ ] Step 2: Marketplace
- [ ] Step 3: Selling and AI review
- [ ] Step 4: Buying
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
- [ ] Google sign-in (code ready and button hidden; **needs your Google account setup**)
- [x] Phone OTP and rate limits (tested with test numbers)
- [ ] Real Bangladesh SMS provider (**needs your provider account**)
- [x] Phone verification gate
- [x] Profile and avatar (photo location data is removed before upload)
- [x] Addresses with Bangladesh regions
- [x] Account deletion (`delete-account`)
- [ ] Test the whole step on a real Android device or emulator

**Done when:** all three sign-in methods work on a real device, and users cannot read each other's private data.

**Status:** in progress. Email and phone sign-in work on the iOS Simulator, using test numbers. To finish: real Google sign-in, real SMS and an Android test.

## Step 2: Marketplace

- [ ] Catalog tables, indexes, RLS and dev seed
- [ ] `search_products`
- [ ] Home screen
- [ ] Product list, search and filter screens
- [ ] Product details with colours, sizes, discount price, share and Chat with seller placeholder
- [ ] Shop page
- [ ] Wishlist
- [ ] Paging, image caching, and empty and error states

**Done when:** a guest can browse, search and filter seeded products, and a logged-in user can save to the wishlist.

## Step 3: Selling and AI review

- [ ] `become_seller` and shop setup
- [ ] Storage buckets and policies
- [ ] Post flow from the demo (max 5 JPG or PNG photos) with image compression and drafts
- [ ] Pass product photos through `preparePhotoForUpload` so location data is removed, then check the stored file
- [ ] Draft the prohibited-products policy for your approval
- [ ] Choose and test a free AI model
- [ ] `moderate-product`, adapter, queue, retries and tests
- [ ] `admin_decide_product`
- [ ] Route suspicious, rejected and timed-out products to `admin_review`
- [ ] My Listings with rejection reason, edit and resubmit, pause and delete
- [ ] Trigger: edits to reviewed fields return the product to review

**Done when:** a valid listing goes live through AI approval, a suspicious or prohibited one reaches the admin queue, and an AI outage never publishes a product.

## Step 4: Buying

- [ ] Cart tables and repository
- [ ] Seller-grouped cart screen
- [ ] Buy Now from product details
- [ ] Order tables, RLS and price snapshots
- [ ] `place_order`, with race and rollback tests
- [ ] Checkout screen with friendly error handling
- [ ] My Orders and order details
- [ ] Buyer cancellation
- [ ] Block account deletion while orders are open, and keep order records after deletion

**Done when:** a buyer can order from two sellers, a race for the last item gives one success and one `OUT_OF_STOCK`, and a double tap creates one order.

## Step 5: Sales and commission

- [ ] `update_group_status`, allowing only valid status changes
- [ ] Cancel and failed delivery, with stock restored
- [ ] Sales tabs, order details and buyer contact information
- [ ] Buyer status timeline: Pending → Packaging → Out for delivery → Complete
- [ ] Complete step: cash record, 1% commission ledger entry and rate snapshot
- [ ] Commission screen
- [ ] Block posting when over the unpaid limit

**Done when:** a ৳1,000 item charges exactly ৳10 on Complete with delivery excluded, cancelled and failed orders charge nothing, and sellers see only their own orders.

## Step 6: Chat and trust

- [ ] `conversations` and `messages` tables, RLS and tests
- [ ] Chat RPCs, Realtime, conversation list, chat room and unread count
- [ ] "Chat with seller" on product and order screens
- [ ] Report a message
- [ ] FCM setup, device tokens, `send-push` and notification centre
- [ ] `track_event` and app tracking (view = details opened, click = card tapped)
- [ ] Nightly rollup and `get_seller_stats`
- [ ] Statistics and Dashboard with real data
- [ ] Reviews and rating updates
- [ ] Reports

**Done when:** chat works in real time between two devices and only its two participants can read it, push arrives, and Statistics show real numbers.

## Step 7: Admin panel

- [ ] Create `admin_web`, admin login and `is_admin()` checks
- [ ] Product Review queue: listing, images, AI reason, approve or reject with a reason
- [ ] Overview (including queue count), users, products, orders
- [ ] Categories, settings (commission rate and limits), banners
- [ ] Reports and settlement recording
- [ ] Audit tests

**Done when:** an admin can decide queued products and record a settlement, and a non-admin is refused by the server.

## Step 8: Launch prep

- [ ] Complete RLS audit and secret scan
- [ ] Performance check with large seed data
- [ ] Terms, privacy policy, seller terms and listing policy (legal review)
- [ ] App icons and store listings
- [ ] Staging → production migration rehearsal and backups
- [ ] Closed beta with real sellers
- [ ] Fix beta issues
- [ ] Submit to Google Play and the App Store

**Done when:** every check in the Verification section of `plan.md` passes and both stores accept the app.
