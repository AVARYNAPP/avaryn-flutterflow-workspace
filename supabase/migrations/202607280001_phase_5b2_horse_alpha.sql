begin;

create or replace function public.get_horse_capabilities(
  p_horse_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_horse public.horses%rowtype;
  actor_membership public.stable_memberships%rowtype;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_horse_id is null then
    raise exception using
      errcode = '22023',
      message = 'HORSE_ID_REQUIRED';
  end if;

  select h.* into target_horse
  from public.horses h
  join public.stables s on s.id = h.stable_id
  where h.id = p_horse_id
    and h.status = 'active'
    and s.status = 'active';
  if target_horse.id is null then
    raise exception using
      errcode = '42501',
      message = 'HORSE_UNAVAILABLE';
  end if;

  select m.* into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_horse.stable_id
    and m.user_id = actor_id
    and m.status = 'active';
  if actor_membership.id is null
    or not private.has_horse_capability(
      target_horse.id,
      'horse.basic',
      'view'
    )
  then
    raise exception using
      errcode = '42501',
      message = 'HORSE_UNAVAILABLE';
  end if;

  return jsonb_build_object(
    'horse_id', target_horse.id,
    'stable_id', target_horse.stable_id,
    'membership_id', actor_membership.id,
    'role', actor_membership.role,
    'can_edit_profile', private.has_horse_capability(
      target_horse.id,
      'horse.basic',
      'edit'
    ),
    'can_archive', actor_membership.role in ('owner', 'admin'),
    'can_manage_basic_access', private.can_manage_horse_grants(
      target_horse.id,
      'horse.basic'
    ),
    'can_manage_schedule_access', private.can_manage_horse_grants(
      target_horse.id,
      'horse.schedule'
    ),
    'can_manage_relationships',
      actor_membership.role in ('owner', 'admin')
  );
end;
$$;

revoke execute on function public.get_horse_capabilities(uuid)
  from public, anon;
grant execute on function public.get_horse_capabilities(uuid)
  to authenticated;

comment on function public.get_horse_capabilities(uuid) is
  'Returns only the authenticated actor capabilities for one already-visible active Horse; it never grants authority.';

commit;
