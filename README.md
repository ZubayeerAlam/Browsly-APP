# Browsly

A multi-vendor marketplace app for Android and iOS, built with Flutter and Supabase.

- [plan.md](plan.md): the full Release 1 plan
- [build.md](build.md): the step-by-step progress tracker

## Run the app

Start local Supabase, which needs Docker running. This leaves out services the app doesn't use yet:

```bash
supabase start -x realtime,studio,imgproxy,vector,postgres-meta,logflare
```

Copy `env.example.json` to `env.json`, then add the publishable key from `supabase status`. Only public values belong in `env.json`. Never add the Supabase service role key to the app.

```bash
flutter run --dart-define-from-file=env.json
```

On an Android emulator, use `http://10.0.2.2:54321` as the Supabase URL.

### Google sign-in

Copy `supabase/.env.example` to `supabase/.env`, add your Google OAuth client ID and secret, then restart Supabase. Set `GOOGLE_SIGN_IN_ENABLED` to `true` in `env.json` to show the button. The Google client needs this redirect URI for local development: `http://127.0.0.1:54321/auth/v1/callback`.

### Local test sign-in

- **Phone:** `01700000000` or `01700000001` with code `123456`. No real SMS is sent.
- **Email:** local emails are caught by Mailpit at http://127.0.0.1:54324, and nothing is really sent.

Debug builds without `env.json` still open and can browse as a guest.

## Run the checks

```bash
flutter analyze
flutter test
```

## Product review (AI)

Copy `supabase/functions/.env.example` to `supabase/functions/.env`, then restart Supabase. The example uses a fake AI, so no key is needed: a listing title containing `[suspicious]`, `[reject]` or `[aierror]` chooses that result, and anything else is approved. To test the real AI, follow the comments in that file. Never set `MODERATION_PROVIDER` in production.

The function's tests run with:

```bash
deno test --allow-env --no-lock supabase/functions/moderate-product/moderation_test.ts
```

Database commands need the [Supabase CLI](https://supabase.com/docs/guides/local-development) and Docker:

```bash
supabase db start
supabase db reset
supabase test db
```

`supabase db reset` also loads demo sellers and products from `supabase/seed_dev.sql`, and uploads their photos when the full stack is running. This data is for local development only: apply only `supabase/seed.sql` to production, and never use `supabase db push --include-seed`.
