\if :{?avaryn_local_test}
\else
\echo 'Refusing Phase 5 Alpha product recovery SQL outside local test mode.'
\quit 2
\endif

\set ON_ERROR_STOP on

begin;

do $$
declare
  category_attnotnull boolean;
  category_default text;
begin
  select attribute.attnotnull, pg_catalog.pg_get_expr(default_value.adbin, default_value.adrelid)
    into category_attnotnull, category_default
  from pg_catalog.pg_attribute attribute
  left join pg_catalog.pg_attrdef default_value
    on default_value.adrelid = attribute.attrelid
   and default_value.adnum = attribute.attnum
  where attribute.attrelid = 'public.feeding_plan_items'::regclass
    and attribute.attname = 'item_category'
    and not attribute.attisdropped;

  if category_attnotnull is distinct from true
    or category_default not like '%feed%'
  then
    raise exception 'Feeding item category is not safely additive/defaulted';
  end if;

  if to_regprocedure(
    'public.list_schedule_calendar(uuid,date,date)'
  ) is null
    or to_regprocedure(
      'public.create_schedule_task_with_assignment_v2(uuid,uuid,text,text,text,text,text,timestamptz,timestamptz,text,date,time,uuid,uuid,uuid)'
    ) is null
    or to_regprocedure(
      'public.create_schedule_series_with_occurrences_v2(uuid,uuid,text,text,text,text,text,text,integer,smallint[],time,integer,date,date,integer,text,date,uuid,uuid,uuid)'
    ) is null
    or to_regprocedure(
      'public.update_schedule_series_scope_materialized(uuid,bigint,text,uuid,date,uuid,text,text,text,text,integer,smallint[],time,integer,date,integer,text,date,uuid)'
    ) is null
    or to_regprocedure(
      'public.upsert_feeding_plan_item_v2(uuid,uuid,bigint,text,text,text,text,text,numeric,text,text,text,time,smallint[],integer,text,uuid,text,date,text,uuid)'
    ) is null
  then
    raise exception 'One or more recovery RPCs are missing';
  end if;

  if has_function_privilege(
    'anon',
    'public.list_schedule_calendar(uuid,date,date)',
    'execute'
  )
    or has_function_privilege(
      'anon',
      'public.upsert_feeding_plan_item_v2(uuid,uuid,bigint,text,text,text,text,text,numeric,text,text,text,time,smallint[],integer,text,uuid,text,date,text,uuid)',
      'execute'
    )
  then
    raise exception 'Anonymous role can execute a recovery RPC';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.list_schedule_calendar(uuid,date,date)',
    'execute'
  )
  then
    raise exception 'Authenticated role cannot read the RLS-aware calendar';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000099',
  true
);

do $$
begin
  if exists (
    select 1
    from public.list_schedule_calendar(
      '00000000-0000-0000-0000-000000000098',
      current_date,
      current_date + 31
    )
  ) then
    raise exception 'Calendar leaked rows without active stable membership';
  end if;
end;
$$;

rollback;

\echo 'PASS: Phase 5 Alpha product recovery SQL contract is green.'
