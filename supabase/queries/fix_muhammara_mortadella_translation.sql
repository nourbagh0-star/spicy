-- Corrects the ingredient wording for the Muhammara item.
-- The restaurant uses mortadella, not sausage.
update public.menu_item_translations as translation
set name = case translation.language_code
      when 'en' then 'Muhammara with Mortadella'
      when 'ar' then 'محمرة بالمرتديلا'
      else translation.name
    end,
    description = case translation.language_code
      when 'en' then 'Spicy sauce, mozzarella, mortadella and parsley.'
      when 'ar' then 'صلصة حارة، جبن موزاريلا، مرتديلا وبقدونس.'
      else translation.description
    end
from public.menu_items as item
where item.id = translation.menu_item_id
  and item.external_id = 'блинчики-мухамара-с-колбасой-1'
  and translation.language_code in ('en', 'ar');

-- Verification: this must return exactly two rows, one for en and one for ar.
select
  item.external_id,
  translation.language_code,
  translation.name,
  translation.description
from public.menu_items as item
join public.menu_item_translations as translation
  on translation.menu_item_id = item.id
where item.external_id = 'блинчики-мухамара-с-колбасой-1'
  and translation.language_code in ('en', 'ar')
order by translation.language_code;
