-- Run this migration in Supabase SQL Editor after supabase-setup.sql.
-- Public visitors can read the shared mural and publish text contributions.
-- Only authorized team members can edit/delete group work or upload images.

alter table public.report_posts
    add column if not exists source text not null default 'team';

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conrelid = 'public.report_posts'::regclass
          and conname = 'report_posts_source_check'
    ) then
        alter table public.report_posts
            add constraint report_posts_source_check check (source in ('team', 'public'));
    end if;
end
$$;

grant select, insert on public.report_posts to anon, authenticated;
grant select on public.report_images to anon, authenticated;

drop policy if exists "Anyone can read the public mural" on public.report_posts;
create policy "Anyone can read the public mural"
    on public.report_posts for select to anon, authenticated
    using (true);

drop policy if exists "Visitors can publish public contributions" on public.report_posts;
create policy "Visitors can publish public contributions"
    on public.report_posts for insert to anon, authenticated
    with check (
        source = 'public'
        and char_length(btrim(author)) between 2 and 60
        and char_length(btrim(body)) between 3 and 2000
    );

drop policy if exists "Anyone can read public capture comments" on public.report_images;
create policy "Anyone can read public capture comments"
    on public.report_images for select to anon, authenticated
    using (true);

drop policy if exists "Anyone can view shared report captures" on storage.objects;
create policy "Anyone can view shared report captures"
    on storage.objects for select to anon, authenticated
    using (bucket_id = 'report-images');

update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/gif', 'image/webp']
where id = 'report-images';
