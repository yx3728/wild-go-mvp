create extension if not exists "pgcrypto";

create table if not exists public.observations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  client_id text not null default 'anonymous',
  common_name text not null,
  latin_name text not null,
  rarity text not null,
  finish text not null,
  stars integer not null check (stars between 1 and 6),
  confidence numeric(5, 4) not null check (confidence >= 0 and confidence <= 1),
  locality text not null default 'Approx location',
  note text not null default '',
  latitude double precision,
  longitude double precision,
  image_path text,
  source text not null default 'cloud_api' check (source in ('cloud_api', 'local_vision_coreml', 'fallback')),
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.observations add column if not exists client_id text not null default 'anonymous';
alter table public.observations add column if not exists source text not null default 'cloud_api';
alter table public.observations add column if not exists captured_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'observations_source_check'
      and conrelid = 'public.observations'::regclass
  ) then
    alter table public.observations
    add constraint observations_source_check
    check (source in ('cloud_api', 'local_vision_coreml', 'fallback'));
  end if;
end;
$$;

alter table public.observations enable row level security;

drop policy if exists "observations are readable by everyone" on public.observations;
drop policy if exists "authenticated users can read own observations" on public.observations;
create policy "authenticated users can read own observations"
on public.observations
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "authenticated users can create observations" on public.observations;
create policy "authenticated users can create observations"
on public.observations
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "authenticated users can update own observations" on public.observations;
create policy "authenticated users can update own observations"
on public.observations
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "authenticated users can delete own observations" on public.observations;
create policy "authenticated users can delete own observations"
on public.observations
for delete
to authenticated
using (auth.uid() = user_id);

create index if not exists observations_client_id_created_at_idx
on public.observations (client_id, created_at desc);

create index if not exists observations_user_id_created_at_idx
on public.observations (user_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists observations_set_updated_at on public.observations;
create trigger observations_set_updated_at
before update on public.observations
for each row
execute function public.set_updated_at();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'observations',
  'observations',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "app clients can upload observation images" on storage.objects;
drop policy if exists "app clients can read observation images" on storage.objects;
drop policy if exists "app clients can update observation images" on storage.objects;

drop policy if exists "authenticated users can upload own observation images" on storage.objects;
create policy "authenticated users can upload own observation images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'observations'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "authenticated users can read own observation images" on storage.objects;
create policy "authenticated users can read own observation images"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'observations'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "authenticated users can update own observation images" on storage.objects;
create policy "authenticated users can update own observation images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'observations'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'observations'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "authenticated users can delete own observation images" on storage.objects;
create policy "authenticated users can delete own observation images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'observations'
  and (storage.foldername(name))[1] = auth.uid()::text
);
