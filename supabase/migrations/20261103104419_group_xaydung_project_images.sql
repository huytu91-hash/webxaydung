-- One project can own a gallery of images instead of one project row per upload.
begin;
alter table public.webx_projects alter column image_path drop not null;
create table public.webx_project_images (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.webx_projects(id) on delete cascade,
  image_path text not null unique,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now()
);
alter table public.webx_project_images enable row level security;
grant select on public.webx_project_images to anon, authenticated;
grant insert, delete on public.webx_project_images to authenticated;
create policy webx_project_images_public_read on public.webx_project_images for select to anon, authenticated using (true);
create policy webx_project_images_admin_insert on public.webx_project_images for insert to authenticated with check ((select webx_private.is_admin()));
create policy webx_project_images_admin_delete on public.webx_project_images for delete to authenticated using ((select webx_private.is_admin()));
insert into public.webx_project_images(project_id,image_path,sort_order,created_at)
select id,image_path,
  case when title ~ ' \([0-9]+\)$' then substring(title from '\(([0-9]+)\)$')::integer else 1 end,
  created_at
from public.webx_projects where image_path is not null;
do $$
declare g record;
declare parent_id uuid;
begin
  for g in
    select regexp_replace(title, ' \([0-9]+\)$', '') as base_title, type, description
    from public.webx_projects
    where title ~ ' \([0-9]+\)$'
    group by regexp_replace(title, ' \([0-9]+\)$', ''), type, description
    having count(*) > 1
  loop
    select id into parent_id from public.webx_projects
    where title = g.base_title || ' (1)' and type = g.type and description = g.description
    order by created_at asc limit 1;
    if parent_id is not null then
      update public.webx_project_images i set project_id = parent_id
      from public.webx_projects p
      where i.project_id = p.id and p.id <> parent_id
        and regexp_replace(p.title, ' \([0-9]+\)$', '') = g.base_title
        and p.type = g.type and p.description = g.description;
      update public.webx_projects set title = g.base_title where id = parent_id;
      delete from public.webx_projects p
      where p.id <> parent_id and regexp_replace(p.title, ' \([0-9]+\)$', '') = g.base_title
        and p.type = g.type and p.description = g.description;
    end if;
    parent_id := null;
  end loop;
end $$;
commit;