# Supabase database

This directory contains the version-controlled database definition for Spicy.
It is intentionally not applied until the owner creates the Supabase project.

## Apply the schema

1. Create the Supabase project and keep its database password private.
2. Install and authenticate the Supabase CLI on the machine that will deploy
   the database.
3. Link the CLI to the new project and run `supabase db push` from this project
   directory.
4. Create the first private test account through the app.
5. In the Supabase SQL editor, promote only that account to owner:

```sql
update public.profiles
set role = 'owner'
where id = '<the-account-uuid>';
```

The service-role key is never used by the Flutter application. Keep it only in
server-side deployment settings when a later administration function requires
it.

## Add the three Spicy branches

After the initial schema succeeds, run
[`seed/202608260002_branches.sql`](seed/202608260002_branches.sql) in the
Supabase SQL Editor. It is safe to run again: it only inserts addresses that do
not already exist. The final query shows the three saved branch locations.

## Import the initial menu

Run these files in this exact order in the Supabase SQL Editor:

1. `migrations/202608260003_menu_item_variants.sql` — adds secure size and
   price-option support before menu data exists.
2. `seed/202608260004_initial_menu.sql` — imports the reviewed GitHub menu.

The menu seed is safe to rerun: it inserts missing records but does not
overwrite later owner changes, such as an item marked unavailable at one
branch. Its verification result should show 12 categories, 100 menu items,
118 price options, 300 branch-menu items, and 354 branch prices.

The generated menu source lives in `lib/menu-data.json`. To intentionally
regenerate the import file after a reviewed source-data change, update the
translation parts in `tool/menu_translation_parts/` and run:

```bash
node tool/generate_menu_seed.mjs
```
