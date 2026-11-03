begin;

create schema if not exists webx_private;
revoke all on schema webx_private from public, anon, authenticated;
grant usage on schema webx_private to authenticated;

create table if not exists webx_private.admin_emails (
  email text primary key check (email = lower(email) and position('@' in email) > 1),
  created_at timestamptz not null default now()
);
revoke all on webx_private.admin_emails from public, anon, authenticated;

create or replace function webx_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from auth.users as u
    join webx_private.admin_emails as allowed
      on allowed.email = lower(u.email)
    where u.id = (select auth.uid())
      and u.email_confirmed_at is not null
  );
$function$;
revoke all on function webx_private.is_admin() from public, anon;
grant execute on function webx_private.is_admin() to authenticated;

create table if not exists public.webx_projects (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 160),
  description text not null default '' check (char_length(description) <= 800),
  type text not null check (type in ('thiet-ke', 'thi-cong')),
  image_path text not null unique,
  created_at timestamptz not null default now()
);
alter table public.webx_projects enable row level security;
grant select on public.webx_projects to anon, authenticated;
grant insert, update, delete on public.webx_projects to authenticated;

create policy webx_projects_public_read
  on public.webx_projects for select to anon, authenticated
  using (true);
create policy webx_projects_admin_insert
  on public.webx_projects for insert to authenticated
  with check ((select webx_private.is_admin()));
create policy webx_projects_admin_update
  on public.webx_projects for update to authenticated
  using ((select webx_private.is_admin()))
  with check ((select webx_private.is_admin()));
create policy webx_projects_admin_delete
  on public.webx_projects for delete to authenticated
  using ((select webx_private.is_admin()));

create table if not exists public.webx_contacts (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  phone text not null check (
    char_length(regexp_replace(phone, '[^0-9]', '', 'g')) between 9 and 15
  ),
  message text not null default '' check (char_length(message) <= 3000),
  created_at timestamptz not null default now()
);
alter table public.webx_contacts enable row level security;
grant insert on public.webx_contacts to anon, authenticated;
grant select on public.webx_contacts to authenticated;

create policy webx_contacts_public_insert
  on public.webx_contacts for insert to anon, authenticated
  with check (
    char_length(btrim(name)) between 1 and 120
    and char_length(regexp_replace(phone, '[^0-9]', '', 'g')) between 9 and 15
    and char_length(message) <= 3000
  );
create policy webx_contacts_admin_read
  on public.webx_contacts for select to authenticated
  using ((select webx_private.is_admin()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('webx-projects', 'webx-projects', true, 8388608, array['image/jpeg'])
on conflict (id) do nothing;

create policy webx_project_images_public_read
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'webx-projects');
create policy webx_project_images_admin_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'webx-projects'
    and (select webx_private.is_admin())
    and lower(storage.extension(name)) = 'jpg'
  );
create policy webx_project_images_admin_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'webx-projects'
    and (select webx_private.is_admin())
  );

commit;