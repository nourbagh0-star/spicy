-- Public customers may read menu photos; only the owner may upload or replace them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true;

create policy "menu images: public read"
on storage.objects for select
to public
using (bucket_id = 'menu-images');

create policy "menu images: owner upload"
on storage.objects for insert
to authenticated
with check (bucket_id = 'menu-images' and public.is_owner());

create policy "menu images: owner update"
on storage.objects for update
to authenticated
using (bucket_id = 'menu-images' and public.is_owner())
with check (bucket_id = 'menu-images' and public.is_owner());
