-- Step 8: fixes from the security audit, and the daily clean-up of unused photos.

-- ---- Reports. People who report something only hear that it was looked at, so
-- they must not be able to read the outcome, the admin or the private note.
-- Admins read all of these through admin_list_reports.

revoke select on public.reports from authenticated;
grant select (id, reporter_id, target_type, target_id, reason, details, created_at)
  on public.reports to authenticated;

-- ---- Settings. Changes must go through admin_update_settings, which checks the
-- values and writes the admin record. A direct update would skip both.

drop policy "Admins can update platform settings" on public.platform_settings;
revoke update on public.platform_settings from authenticated;

-- ---- Unused photos.

-- Files that nothing in the database points to. Order items count, because past
-- orders keep showing the photo after a listing changes. New files are left
-- alone, because the app uploads a photo before it saves the listing.
create function public.find_unused_photos(p_limit integer default 200)
returns table (bucket_id text, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select o.bucket_id, o.name
  from storage.objects o
  where o.created_at < now() - interval '2 days'
    and (
      (o.bucket_id = 'product-images'
        and not exists (select 1 from public.product_images i where i.storage_path = o.name)
        and not exists (select 1 from public.order_items x where x.image_path = o.name))
      or (o.bucket_id = 'shop-assets'
        and not exists (
          select 1 from public.shops s where o.name in (s.logo_path, s.banner_path)
        ))
      or (o.bucket_id = 'avatars'
        and not exists (select 1 from public.profiles p where p.avatar_path = o.name))
      or (o.bucket_id = 'banners'
        and not exists (select 1 from public.home_banners b where b.image_path = o.name))
    )
  order by o.created_at
  limit least(greatest(coalesce(p_limit, 200), 1), 1000);
$$;

revoke all on function public.find_unused_photos(integer) from public, anon, authenticated;
grant execute on function public.find_unused_photos(integer) to service_role;

-- Files can only be removed through the Storage API, so this wakes a server
-- function to do it. Without the secrets it does nothing.
create function public.run_photo_cleanup()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'cleanup_secret';
  if v_url is null or v_secret is null then
    return;
  end if;

  perform net.http_post(
    url := v_url || '/functions/v1/clean-photos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cleanup-secret', v_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
exception when others then
  raise warning 'Could not start the photo clean-up: %', sqlerrm;
end;
$$;

revoke all on function public.run_photo_cleanup() from public, anon, authenticated;

-- 02:00 in Bangladesh.
select cron.schedule('clean-unused-photos', '0 20 * * *', 'select public.run_photo_cleanup()');
