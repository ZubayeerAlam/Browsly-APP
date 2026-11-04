# Browsly

A multi-vendor marketplace app for Android and iOS, built with Flutter and Supabase.

- [plan.md](plan.md): the full Release 1 plan
- [build.md](build.md): the step-by-step progress tracker

## Run the app

Browse as a guest during development, without any Supabase settings:

```bash
flutter run
```

To connect to Supabase, copy `env.example.json` to `env.json`, fill in your values, then run:

```bash
flutter run --dart-define-from-file=env.json
```

Only public values belong in `env.json`. Never add the Supabase service role key to the app.

## Run the checks

```bash
flutter analyze
flutter test
```

Database commands need the [Supabase CLI](https://supabase.com/docs/guides/local-development) and Docker:

```bash
supabase db start
supabase db reset
supabase test db
```
