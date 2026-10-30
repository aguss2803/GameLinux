-- Run this script in Supabase SQL Editor before enabling GitHub Pages.
-- For each teammate, add their lower-case email to team_members and invite that
-- same existing user from Authentication > Users. Public sign-ups stay disabled.
-- Example after running this script:
-- insert into public.team_members (email) values (lower('teammate@example.com'));

create table if not exists public.team_members (
    email text primary key check (email = lower(email))
);

create table if not exists public.report_posts (
    id text primary key,
    consigna_id smallint not null check (consigna_id between 1 and 5),
    author text not null,
    body text not null,
    created_at timestamptz not null,
    updated_at timestamptz not null default now()
);

create table if not exists public.report_images (
    image_id text primary key check (image_id in ('ubuntu', 'monitor', 'before', 'after')),
    path text not null unique,
    name text not null,
    author text not null,
    created_at timestamptz not null,
    updated_at timestamptz not null default now()
);

alter table public.team_members enable row level security;
alter table public.report_posts enable row level security;
alter table public.report_images enable row level security;
alter table public.report_posts replica identity full;
alter table public.report_images replica identity full;

create or replace function public.is_report_team_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.team_members
        where email = lower(coalesce((select auth.jwt() ->> 'email'), ''))
    );
$$;

revoke all on function public.is_report_team_member() from public;
grant execute on function public.is_report_team_member() to authenticated;

grant select on public.team_members to authenticated;
grant select, insert, update, delete on public.report_posts to authenticated;
grant select, insert, update, delete on public.report_images to authenticated;

drop policy if exists "Team members can read their own membership" on public.team_members;
create policy "Team members can read their own membership"
    on public.team_members for select to authenticated
    using (email = lower(coalesce((select auth.jwt() ->> 'email'), '')));

drop policy if exists "Team members can collaborate on report posts" on public.report_posts;
create policy "Team members can collaborate on report posts"
    on public.report_posts for all to authenticated
    using ((select public.is_report_team_member()))
    with check ((select public.is_report_team_member()));

drop policy if exists "Team members can collaborate on report images" on public.report_images;
create policy "Team members can collaborate on report images"
    on public.report_images for all to authenticated
    using ((select public.is_report_team_member()))
    with check ((select public.is_report_team_member()));

insert into storage.buckets (id, name, public)
values ('report-images', 'report-images', false)
on conflict (id) do update set public = false;

drop policy if exists "Team members can read report captures" on storage.objects;
create policy "Team members can read report captures"
    on storage.objects for select to authenticated
    using (bucket_id = 'report-images' and (select public.is_report_team_member()));

drop policy if exists "Team members can upload report captures" on storage.objects;
create policy "Team members can upload report captures"
    on storage.objects for insert to authenticated
    with check (bucket_id = 'report-images' and (select public.is_report_team_member()));

drop policy if exists "Team members can replace report captures" on storage.objects;
create policy "Team members can replace report captures"
    on storage.objects for update to authenticated
    using (bucket_id = 'report-images' and (select public.is_report_team_member()))
    with check (bucket_id = 'report-images' and (select public.is_report_team_member()));

drop policy if exists "Team members can delete report captures" on storage.objects;
create policy "Team members can delete report captures"
    on storage.objects for delete to authenticated
    using (bucket_id = 'report-images' and (select public.is_report_team_member()));

do $$
begin
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'report_posts'
    ) then
        alter publication supabase_realtime add table public.report_posts;
    end if;
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'report_images'
    ) then
        alter publication supabase_realtime add table public.report_images;
    end if;
end
$$;
/*insert into public.team_members (email)
values (lower('correo-del-companero@example.com'));
En Authentication → Users, invita esos mismos correos.*/