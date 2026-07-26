begin;

alter table public.stable_security_events
  add column horse_id uuid;

comment on column public.stable_security_events.horse_id is
  'Typed Horse correlation. Horse events are forbidden until phase 4C.2A adds the composite same-stable foreign key and server-side event writers.';

alter table public.stable_security_events
  drop constraint stable_security_events_event_type_check;

alter table public.stable_security_events
  add constraint stable_security_events_event_type_check
  check (
    event_type in (
      'stable_created',
      'stable_updated',
      'invitation_created',
      'invitation_resent',
      'invitation_revoked',
      'invitation_accepted',
      'invitation_declined',
      'role_changed',
      'membership_removed',
      'membership_suspended',
      'membership_left',
      'stable_member_linked',
      'ownership_transferred',
      'stable_archived',
      'horse_access_granted',
      'horse_access_revoked'
    )
  );

alter table public.stable_security_events
  add constraint stable_security_events_horse_correlation_check
  check (
    (
      event_type in ('horse_access_granted', 'horse_access_revoked')
      and horse_id is not null
    )
    or
    (
      event_type not in ('horse_access_granted', 'horse_access_revoked')
      and horse_id is null
    )
  );

comment on constraint stable_security_events_horse_correlation_check
  on public.stable_security_events is
  'Horse access events require typed Horse correlation; all phase-4B events forbid it.';

commit;
