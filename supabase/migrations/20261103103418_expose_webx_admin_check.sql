create or replace function public.webx_is_admin()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select webx_private.is_admin();
$function$;
revoke all on function public.webx_is_admin() from public, anon;
grant execute on function public.webx_is_admin() to authenticated;