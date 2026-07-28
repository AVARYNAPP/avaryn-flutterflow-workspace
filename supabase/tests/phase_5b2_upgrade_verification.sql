do $$
declare
  capabilities jsonb;
begin
  if to_regprocedure('public.get_horse_capabilities(uuid)') is null then
    raise exception 'Phase 5B.2 capability RPC is missing after upgrade';
  end if;
  if (
    select count(*)
    from public.horses h
    where h.id = 'b52f0000-0000-0000-0000-000000000001'
      and h.stable_id = 'b52b0000-0000-0000-0000-000000000001'
      and h.display_name = 'Upgrade preserved Horse'
      and h.status = 'active'
      and h.row_version = 1
  ) <> 1 then
    raise exception 'Existing Horse data changed during Phase 5B.2 upgrade';
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    'b52a0000-0000-0000-0000-000000000001',
    true
  );
  capabilities := public.get_horse_capabilities(
    'b52f0000-0000-0000-0000-000000000001'
  );
  if capabilities ->> 'role' <> 'owner'
    or (capabilities ->> 'can_edit_profile')::boolean is not true
    or (capabilities ->> 'can_manage_basic_access')::boolean is not true
  then
    raise exception 'Upgraded capability RPC returned incorrect owner rights';
  end if;
end;
$$;
