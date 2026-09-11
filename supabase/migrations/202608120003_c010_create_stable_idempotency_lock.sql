begin;

-- A simultaneous retry can pass the optimistic receipt read in both sessions.
-- Serialize the exact actor/request pair before any stable side effect and
-- re-read the receipt after the lock. Distinct requests remain independent.
create or replace function public.create_c010_stable(
  p_name text,p_location_name text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; created record; organization public.organizations%rowtype;
  result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if actor_user is null or p_request_id is null
    or pg_catalog.length(pg_catalog.btrim(coalesce(p_name,''))) not between 1 and 160
    or(nullif(pg_catalog.btrim(p_location_name),'') is not null
      and pg_catalog.length(pg_catalog.btrim(p_location_name))>240)
  then raise exception using errcode='22023',message='C010_STABLE_INPUT_INVALID'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'name',pg_catalog.btrim(p_name),
    'location_name',nullif(pg_catalog.btrim(p_location_name),'')
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'create_stable',payload_hash
  );
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'c010:create_stable:'||actor_user::text||':'||p_request_id::text,0
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'create_stable',payload_hash
  );
  if replay is not null then return replay; end if;
  select * into created from public.create_stable_account(
    p_name,null,p_request_id
  );
  update public.organizations value set
    location_name=nullif(pg_catalog.btrim(p_location_name),''),
    row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where value.id=created.organization_id returning * into organization;
  perform private.c010_seed_role_templates(organization.id,actor_profile);
  perform private.c003b_write_audit(
    'organization.updated','organization',organization.id,organization.id,
    actor_profile,private.schedule_derived_request_id(p_request_id,'location'),
    'ORGANIZATION_UPDATED','active','active',1,organization.row_version,
    organization.access_version,organization.access_version,
    pg_catalog.jsonb_build_object('operation_code','c010_create_stable_location')
  );
  result:=pg_catalog.jsonb_build_object(
    'organization_id',organization.id,'membership_id',created.membership_id,
    'row_version',organization.row_version,'access_version',organization.access_version,
    'name',organization.name,'location_name',organization.location_name,
    'idempotent',false
  );
  insert into private.c010_mutation_receipts(
    actor_user_id,request_id,operation_name,payload_hash,result
  ) values(actor_user,p_request_id,'create_stable',payload_hash,result);
  return result;
end;
$$;

commit;
