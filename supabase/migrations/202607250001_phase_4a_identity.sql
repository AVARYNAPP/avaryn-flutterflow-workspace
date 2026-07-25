begin;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  last_name text,
  display_name text not null default 'AVARYN-gebruiker',
  avatar_object_path text,
  phone_e164 text,
  locale text not null default 'nl',
  theme_mode text not null default 'system',
  onboarding_intent text,
  onboarding_completed_at timestamptz,
  accepted_terms_version text,
  accepted_privacy_version text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint profiles_first_name_not_blank
    check (first_name is null or length(btrim(first_name)) > 0),
  constraint profiles_last_name_not_blank
    check (last_name is null or length(btrim(last_name)) > 0),
  constraint profiles_display_name_not_blank
    check (length(btrim(display_name)) > 0),
  constraint profiles_phone_e164
    check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  constraint profiles_theme_mode
    check (theme_mode in ('system', 'light', 'dark')),
  constraint profiles_onboarding_intent
    check (
      onboarding_intent is null
      or onboarding_intent in (
        'createStable',
        'joinStable',
        'individualHorse'
      )
    )
);

alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists display_name text not null default 'AVARYN-gebruiker',
  add column if not exists avatar_object_path text,
  add column if not exists phone_e164 text,
  add column if not exists locale text not null default 'nl',
  add column if not exists theme_mode text not null default 'system',
  add column if not exists onboarding_intent text,
  add column if not exists onboarding_completed_at timestamptz,
  add column if not exists accepted_terms_version text,
  add column if not exists accepted_privacy_version text,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

create or replace function public.phase_4a_profile_before_write()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  resolved_name text;
begin
  new.first_name := nullif(btrim(new.first_name), '');
  new.last_name := nullif(btrim(new.last_name), '');
  new.phone_e164 := nullif(btrim(new.phone_e164), '');
  new.avatar_object_path := nullif(btrim(new.avatar_object_path), '');
  new.locale := coalesce(nullif(btrim(new.locale), ''), 'nl');
  new.theme_mode := coalesce(nullif(btrim(new.theme_mode), ''), 'system');

  resolved_name := nullif(
    btrim(concat_ws(' ', new.first_name, new.last_name)),
    ''
  );
  new.display_name := coalesce(
    nullif(btrim(new.display_name), ''),
    resolved_name,
    'AVARYN-gebruiker'
  );
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists phase_4a_profile_before_write on public.profiles;
create trigger phase_4a_profile_before_write
before insert or update on public.profiles
for each row execute function public.phase_4a_profile_before_write();

create or replace function public.phase_4a_create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  supplied_first_name text;
  supplied_last_name text;
  supplied_display_name text;
begin
  supplied_first_name := nullif(
    btrim(
      coalesce(
        new.raw_user_meta_data ->> 'given_name',
        new.raw_user_meta_data ->> 'first_name'
      )
    ),
    ''
  );
  supplied_last_name := nullif(
    btrim(
      coalesce(
        new.raw_user_meta_data ->> 'family_name',
        new.raw_user_meta_data ->> 'last_name'
      )
    ),
    ''
  );
  supplied_display_name := nullif(
    btrim(
      coalesce(
        new.raw_user_meta_data ->> 'full_name',
        new.raw_user_meta_data ->> 'name',
        concat_ws(' ', supplied_first_name, supplied_last_name)
      )
    ),
    ''
  );

  insert into public.profiles (
    id,
    first_name,
    last_name,
    display_name,
    locale,
    theme_mode
  )
  values (
    new.id,
    supplied_first_name,
    supplied_last_name,
    coalesce(supplied_display_name, 'AVARYN-gebruiker'),
    'nl',
    'system'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists phase_4a_auth_user_profile on auth.users;
create trigger phase_4a_auth_user_profile
after insert on auth.users
for each row execute function public.phase_4a_create_profile_for_auth_user();

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon;
grant select, insert, update on table public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id)
with check ((select auth.uid()) is not null and (select auth.uid()) = id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars_select_own" on storage.objects;
create policy "avatars_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

commit;
