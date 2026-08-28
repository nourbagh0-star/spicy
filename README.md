# Spicy

Restaurant ordering platform for three branches in Maykop. The private
prototype supports cash delivery and pickup, customer order history, owner
administration, and branch-manager order operations.

## Local setup

The project runs without a Supabase connection while the backend is being
prepared. Once a Supabase project exists, run Flutter with its public client
configuration:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

For a Netlify web build, configure the same two values as build environment
variables and pass them to `flutter build web` as `--dart-define` values.

Never put a Supabase service-role key in the Flutter app, GitHub repository, or
Netlify client environment. It is a server-only secret.

## Database

The version-controlled Supabase schema is in
[`supabase/migrations`](supabase/migrations). It is not applied until a
Supabase project is created. See [`supabase/README.md`](supabase/README.md)
for the safe deployment procedure.
