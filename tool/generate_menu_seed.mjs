#!/usr/bin/env node

/**
 * Creates the first, idempotent Supabase menu seed from the reviewed local
 * copy of the GitHub menu. Run from the project root:
 *
 *   node tool/generate_menu_seed.mjs
 *
 * The generated SQL never overwrites a later owner edit. It only inserts data
 * that is not already present.
 */
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const projectRoot = process.cwd();
const menuPath = path.join(projectRoot, 'lib', 'menu-data.json');
const translationPartDirectory = path.join(
  projectRoot,
  'tool',
  'menu_translation_parts',
);
const outputDirectory = path.join(projectRoot, 'supabase', 'seed');
const outputPath = path.join(
  outputDirectory,
  '202608260004_initial_menu.sql',
);
const translationOutputDirectory = path.join(projectRoot, 'supabase', 'queries');
const translationOutputPath = path.join(
  translationOutputDirectory,
  'import_menu_translations_en_ar.sql',
);
const githubRawBase =
  'https://raw.githubusercontent.com/nourbagh0-star/spicy-menu-data/main';
const branchAddresses = [
  'Пионерская ул., 327, Майкоп',
  'Краснооктябрьская ул., 17, Майкоп',
  '2-я Крестьянская ул., 17, Майкоп',
];

const categorySlugs = {
  пицца: 'pizza',
  блинчики: 'pancakes',
  кальцоне: 'calzone',
  сэндвичи: 'sandwiches',
  блюда: 'dishes',
  салаты: 'salads',
  'фруктовые-салаты': 'fruit-salads',
  мороженое: 'ice-cream',
  'молочные-коктейли': 'milkshakes',
  'цитрусовый-фреш': 'citrus-fresh',
  смузи: 'smoothies',
  'кофе-чай': 'coffee-tea',
};

const labelTranslations = {
  standard: { ru: 'Стандартный', en: 'Standard', ar: 'قياسي' },
  size330: { ru: '330 мл', en: '330 ml', ar: '330 مل' },
  size500: { ru: '500 мл', en: '500 ml', ar: '500 مل' },
  size300: { ru: '300 мл', en: '300 ml', ar: '300 مل' },
  medium: { ru: 'Средний', en: 'Medium', ar: 'متوسط' },
  large: { ru: 'Большой', en: 'Large', ar: 'كبير' },
};

const size330And500Categories = new Set([
  'фруктовые-салаты',
  'молочные-коктейли',
  'цитрусовый-фреш',
]);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function fullImageUrl(image) {
  assert(typeof image === 'string' && image.trim(), 'Every menu item needs an image');
  return image.startsWith('/') ? `${githubRawBase}${image}` : image;
}

function option(code, priceRoubles, label) {
  assert(Number.isInteger(priceRoubles) && priceRoubles >= 0, 'Invalid price');
  return {
    code,
    price_kopeks: priceRoubles * 100,
    ru_name: label.ru,
    en_name: label.en,
    ar_name: label.ar,
  };
}

function variantsFor(item, categoryId) {
  if (item.id === 'сэндвичи-тако-4') {
    return [option('standard', 240, labelTranslations.standard)];
  }

  if (item.id === 'сэндвичи-эскалоп-5') {
    return [option('standard', 290, labelTranslations.standard)];
  }

  if (item.id === 'сэндвичи-бургер-фит-23') {
    return [
      option('medium', item.prices[0], labelTranslations.medium),
      option('large', item.prices[1], labelTranslations.large),
    ];
  }

  if (size330And500Categories.has(categoryId)) {
    assert(item.prices.length === 2, `Expected two prices for ${item.id}`);
    return [
      option('330ml', item.prices[0], labelTranslations.size330),
      option('500ml', item.prices[1], labelTranslations.size500),
    ];
  }

  if (categoryId === 'смузи') {
    assert(item.prices.length === 2, `Expected two prices for ${item.id}`);
    return [
      option('300ml', item.prices[0], labelTranslations.size300),
      option('500ml', item.prices[1], labelTranslations.size500),
    ];
  }

  assert(item.prices.length === 1, `Unexpected price options for ${item.id}`);
  return [option('standard', item.prices[0], labelTranslations.standard)];
}

async function loadTranslationParts() {
  const files = ['a.json', 'b.json', 'c.json'];
  const parts = await Promise.all(
    files.map(async (fileName) => {
      const text = await readFile(path.join(translationPartDirectory, fileName), 'utf8');
      return JSON.parse(text);
    }),
  );

  return parts.reduce(
    (merged, part) => ({
      categories: { ...merged.categories, ...part.categories },
      items: { ...merged.items, ...part.items },
    }),
    { categories: {}, items: {} },
  );
}

function jsonSql(value, tag) {
  const json = JSON.stringify(value);
  assert(!json.includes(`$${tag}$`), `Unsafe SQL delimiter in ${tag}`);
  return `$${tag}$${json}$${tag}$::jsonb`;
}

const menuText = await readFile(menuPath, 'utf8');
const menu = JSON.parse(menuText);
const translation = await loadTranslationParts();

assert(menu.categories.length === 12, 'Expected exactly 12 menu categories');
const sourceItems = menu.categories.flatMap((category) =>
  category.items.map((item, itemIndex) => ({
    ...item,
    category_id: category.id,
    item_sort_order: itemIndex + 1,
  })),
);
assert(sourceItems.length === 100, 'Expected exactly 100 menu items');
assert(
  new Set(sourceItems.map((item) => item.id)).size === sourceItems.length,
  'Menu external IDs must be unique',
);

const categories = menu.categories.map((category, index) => {
  const translated = translation.categories[category.id];
  assert(translated?.en && translated?.ar, `Missing category translation: ${category.id}`);
  assert(categorySlugs[category.id], `Missing category slug: ${category.id}`);
  return {
    external_id: category.id,
    slug: categorySlugs[category.id],
    sort_order: index + 1,
    ru_name: category.name,
    en_name: translated.en,
    ar_name: translated.ar,
  };
});

const items = sourceItems.map((item) => {
  const translated = translation.items[item.id];
  assert(translated?.en_name && translated?.ar_name, `Missing item name translation: ${item.id}`);
  assert(
    typeof translated.en_description === 'string' &&
      typeof translated.ar_description === 'string',
    `Missing item description translation: ${item.id}`,
  );

  return {
    external_id: item.id,
    category_external_id: item.category_id,
    sort_order: item.item_sort_order,
    image_url: fullImageUrl(item.image),
    heat_level: item.heatLevel ?? 0,
    ru_name: item.name,
    ru_description: item.description ?? '',
    en_name: translated.en_name,
    en_description: translated.en_description,
    ar_name: translated.ar_name,
    ar_description: translated.ar_description,
  };
});

const variants = sourceItems.flatMap((item) =>
  variantsFor(item, item.category_id).map((variant, index) => ({
    external_item_id: item.id,
    ...variant,
    sort_order: index + 1,
  })),
);

assert(variants.length === 118, `Expected 118 purchasable variants, got ${variants.length}`);
assert(
  variants.filter((variant) => variant.code !== 'standard').length === 36,
  'Expected 36 size-specific variants',
);

const sql = `-- GENERATED FILE. Do not hand-edit; regenerate with:
--   node tool/generate_menu_seed.mjs
-- Source: lib/menu-data.json
-- Source SHA-256: ${createHash('sha256').update(menuText).digest('hex')}
-- This is an initial, idempotent import. It does not overwrite later owner edits.

begin;

create temporary table spicy_seed_categories (
  external_id text primary key,
  slug text not null,
  sort_order integer not null,
  ru_name text not null,
  en_name text not null,
  ar_name text not null
) on commit drop;

insert into spicy_seed_categories
select *
from jsonb_to_recordset(${jsonSql(categories, 'spicy_categories')}) as source(
  external_id text,
  slug text,
  sort_order integer,
  ru_name text,
  en_name text,
  ar_name text
);

create temporary table spicy_seed_items (
  external_id text primary key,
  category_external_id text not null,
  sort_order integer not null,
  image_url text not null,
  heat_level smallint not null,
  ru_name text not null,
  ru_description text not null,
  en_name text not null,
  en_description text not null,
  ar_name text not null,
  ar_description text not null
) on commit drop;

insert into spicy_seed_items
select *
from jsonb_to_recordset(${jsonSql(items, 'spicy_items')}) as source(
  external_id text,
  category_external_id text,
  sort_order integer,
  image_url text,
  heat_level smallint,
  ru_name text,
  ru_description text,
  en_name text,
  en_description text,
  ar_name text,
  ar_description text
);

create temporary table spicy_seed_variants (
  external_item_id text not null,
  code text not null,
  price_kopeks integer not null,
  ru_name text not null,
  en_name text not null,
  ar_name text not null,
  sort_order integer not null,
  primary key (external_item_id, code)
) on commit drop;

insert into spicy_seed_variants
select *
from jsonb_to_recordset(${jsonSql(variants, 'spicy_variants')}) as source(
  external_item_id text,
  code text,
  price_kopeks integer,
  ru_name text,
  en_name text,
  ar_name text,
  sort_order integer
);

do $$
begin
  if (select count(*) from public.branches where address = any (array[
    ${branchAddresses.map((address) => `'${address.replaceAll("'", "''")}'`).join(',\n    ')}
  ])) <> 3 then
    raise exception 'The three Spicy branch records must exist before menu import';
  end if;
end;
$$;

insert into public.menu_categories (external_id, slug, sort_order)
select external_id, slug, sort_order
from spicy_seed_categories
on conflict (external_id) do nothing;

insert into public.menu_category_translations (category_id, language_code, name)
select category.id, translation.language_code, translation.name
from spicy_seed_categories source
join public.menu_categories category on category.external_id = source.external_id
cross join lateral (
  values
    ('ru', source.ru_name),
    ('en', source.en_name),
    ('ar', source.ar_name)
) as translation(language_code, name)
on conflict (category_id, language_code) do nothing;

insert into public.menu_items (
  external_id,
  category_id,
  image_url,
  heat_level,
  sort_order
)
select
  source.external_id,
  category.id,
  source.image_url,
  source.heat_level,
  source.sort_order
from spicy_seed_items source
join public.menu_categories category
  on category.external_id = source.category_external_id
on conflict (external_id) do nothing;

insert into public.menu_item_translations (
  menu_item_id,
  language_code,
  name,
  description
)
select item.id, translation.language_code, translation.name, translation.description
from spicy_seed_items source
join public.menu_items item on item.external_id = source.external_id
cross join lateral (
  values
    ('ru', source.ru_name, source.ru_description),
    ('en', source.en_name, source.en_description),
    ('ar', source.ar_name, source.ar_description)
) as translation(language_code, name, description)
on conflict (menu_item_id, language_code) do nothing;

insert into public.menu_item_variants (menu_item_id, code, sort_order)
select item.id, source.code, source.sort_order
from spicy_seed_variants source
join public.menu_items item on item.external_id = source.external_item_id
on conflict (menu_item_id, code) do nothing;

insert into public.menu_item_variant_translations (
  menu_item_variant_id,
  language_code,
  name
)
select variant.id, translation.language_code, translation.name
from spicy_seed_variants source
join public.menu_items item on item.external_id = source.external_item_id
join public.menu_item_variants variant
  on variant.menu_item_id = item.id
 and variant.code = source.code
cross join lateral (
  values
    ('ru', source.ru_name),
    ('en', source.en_name),
    ('ar', source.ar_name)
) as translation(language_code, name)
on conflict (menu_item_variant_id, language_code) do nothing;

insert into public.branch_menu_items (
  branch_id,
  menu_item_id,
  preparation_time_minutes,
  is_available,
  is_branch_only
)
select branch.id, item.id, 20, true, false
from public.branches branch
cross join spicy_seed_items source
join public.menu_items item on item.external_id = source.external_id
where branch.address = any (array[
  ${branchAddresses.map((address) => `'${address.replaceAll("'", "''")}'`).join(',\n  ')}
])
on conflict (branch_id, menu_item_id) do nothing;

insert into public.branch_menu_item_variants (
  branch_id,
  menu_item_id,
  menu_item_variant_id,
  price_kopeks,
  is_available
)
select
  branch_item.branch_id,
  item.id,
  variant.id,
  source.price_kopeks,
  true
from spicy_seed_variants source
join public.menu_items item on item.external_id = source.external_item_id
join public.menu_item_variants variant
  on variant.menu_item_id = item.id
 and variant.code = source.code
join public.branch_menu_items branch_item
  on branch_item.menu_item_id = item.id
join public.branches branch on branch.id = branch_item.branch_id
where branch.address = any (array[
  ${branchAddresses.map((address) => `'${address.replaceAll("'", "''")}'`).join(',\n  ')}
])
on conflict (branch_id, menu_item_variant_id) do nothing;

commit;

select
  (select count(*) from public.menu_categories) as category_count,
  (select count(*) from public.menu_items) as menu_item_count,
  (select count(*) from public.menu_item_variants) as price_option_count,
  (select count(*) from public.branch_menu_items) as branch_menu_item_count,
  (select count(*) from public.branch_menu_item_variants) as branch_price_count;
`;

const translationSql = `-- GENERATED FILE. Do not hand-edit; regenerate with:
--   node tool/generate_menu_seed.mjs
-- Adds or repairs only English and Arabic menu translations.
-- Prices, availability, branches, images, and Russian text are not changed.

begin;

create temporary table spicy_translation_categories (
  external_id text primary key,
  en_name text not null,
  ar_name text not null
) on commit drop;

insert into spicy_translation_categories
select external_id, en_name, ar_name
from jsonb_to_recordset(${jsonSql(categories, 'spicy_translation_categories')}) as source(
  external_id text,
  slug text,
  sort_order integer,
  ru_name text,
  en_name text,
  ar_name text
);

create temporary table spicy_translation_items (
  external_id text primary key,
  en_name text not null,
  en_description text not null,
  ar_name text not null,
  ar_description text not null
) on commit drop;

insert into spicy_translation_items
select external_id, en_name, en_description, ar_name, ar_description
from jsonb_to_recordset(${jsonSql(items, 'spicy_translation_items')}) as source(
  external_id text,
  category_external_id text,
  sort_order integer,
  image_url text,
  heat_level smallint,
  ru_name text,
  ru_description text,
  en_name text,
  en_description text,
  ar_name text,
  ar_description text
);

create temporary table spicy_translation_variants (
  external_item_id text not null,
  code text not null,
  en_name text not null,
  ar_name text not null,
  primary key (external_item_id, code)
) on commit drop;

insert into spicy_translation_variants
select external_item_id, code, en_name, ar_name
from jsonb_to_recordset(${jsonSql(variants, 'spicy_translation_variants')}) as source(
  external_item_id text,
  code text,
  price_kopeks integer,
  ru_name text,
  en_name text,
  ar_name text,
  sort_order integer
);

insert into public.menu_category_translations (category_id, language_code, name)
select category.id, translation.language_code, translation.name
from spicy_translation_categories source
join public.menu_categories category on category.external_id = source.external_id
cross join lateral (
  values ('en', source.en_name), ('ar', source.ar_name)
) as translation(language_code, name)
on conflict (category_id, language_code) do update
set name = excluded.name;

insert into public.menu_item_translations (
  menu_item_id,
  language_code,
  name,
  description
)
select item.id, translation.language_code, translation.name, translation.description
from spicy_translation_items source
join public.menu_items item on item.external_id = source.external_id
cross join lateral (
  values
    ('en', source.en_name, source.en_description),
    ('ar', source.ar_name, source.ar_description)
) as translation(language_code, name, description)
on conflict (menu_item_id, language_code) do update
set name = excluded.name,
    description = excluded.description;

insert into public.menu_item_variant_translations (
  menu_item_variant_id,
  language_code,
  name
)
select variant.id, translation.language_code, translation.name
from spicy_translation_variants source
join public.menu_items item on item.external_id = source.external_item_id
join public.menu_item_variants variant
  on variant.menu_item_id = item.id
 and variant.code = source.code
cross join lateral (
  values ('en', source.en_name), ('ar', source.ar_name)
) as translation(language_code, name)
on conflict (menu_item_variant_id, language_code) do update
set name = excluded.name;

commit;

select
  language_code,
  count(*) as translated_menu_items
from public.menu_item_translations
where language_code in ('ru', 'en', 'ar')
group by language_code
order by language_code;
`;

await mkdir(outputDirectory, { recursive: true });
await writeFile(outputPath, sql);
await mkdir(translationOutputDirectory, { recursive: true });
await writeFile(translationOutputPath, translationSql);
process.stdout.write(`Wrote ${outputPath}\n`);
process.stdout.write(`Wrote ${translationOutputPath}\n`);
