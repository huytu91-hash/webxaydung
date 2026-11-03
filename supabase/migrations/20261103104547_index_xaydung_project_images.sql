-- Index gallery lookups by project and display order.
create index webx_project_images_project_sort_idx
  on public.webx_project_images(project_id, sort_order, created_at);