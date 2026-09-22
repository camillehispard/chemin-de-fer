-- V3 : utilisateurs internes, mentions, notifications, fichiers et nouveaux statuts
create extension if not exists pgcrypto;

alter table public.pages add column if not exists writer text;
alter table public.pages add column if not exists word_path text;

create table if not exists public.app_users (
 id uuid primary key default gen_random_uuid(),
 username text unique not null check (username ~ '^[A-Za-z0-9._-]{2,40}$'),
 display_name text not null,
 password_hash text not null,
 role text not null default 'user' check (role in ('admin','user')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.app_sessions (
 token uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.app_users(id) on delete cascade,
 expires_at timestamptz not null default now() + interval '30 days',
 created_at timestamptz not null default now()
);
create table if not exists public.page_comments (
 id uuid primary key default gen_random_uuid(), page_id uuid not null references public.pages(id) on delete cascade,
 author_id uuid not null references public.app_users(id), body text not null, created_at timestamptz not null default now()
);
create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.app_users(id) on delete cascade,
 actor_id uuid references public.app_users(id) on delete set null, page_id uuid references public.pages(id) on delete cascade,
 comment_id uuid references public.page_comments(id) on delete cascade, message text not null, read_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.page_files (
 id uuid primary key default gen_random_uuid(), page_id uuid not null references public.pages(id) on delete cascade,
 uploader_id uuid references public.app_users(id) on delete set null, kind text not null check(kind in ('word','photo')),
 path text not null, filename text not null, created_at timestamptz not null default now()
);

insert into storage.buckets (id,name,public) values ('page-files','page-files',false) on conflict(id) do nothing;

create or replace function public.app_user_id() returns uuid language sql stable as $$
 select s.user_id from public.app_sessions s
 where s.token::text = coalesce((current_setting('request.headers',true)::jsonb ->> 'x-app-token'),'') and s.expires_at > now()
 limit 1 $$;
create or replace function public.app_is_admin() returns boolean language sql stable as $$
 select exists(select 1 from public.app_users u where u.id=public.app_user_id() and u.active and u.role='admin') $$;

create or replace function public.app_login(p_username text,p_password text)
returns table(token uuid,user_id uuid,username text,display_name text,role text) language plpgsql security definer set search_path=public as $$
declare u public.app_users; t uuid;
begin
 select * into u from public.app_users where lower(app_users.username)=lower(p_username) and active limit 1;
 if u.id is null or u.password_hash <> crypt(p_password,u.password_hash) then raise exception 'Identifiant ou mot de passe incorrect'; end if;
 insert into public.app_sessions(user_id) values(u.id) returning app_sessions.token into t;
 return query select t,u.id,u.username,u.display_name,u.role;
end $$;
create or replace function public.app_logout(p_token uuid) returns void language sql security definer set search_path=public as $$ delete from public.app_sessions where token=p_token $$;
create or replace function public.app_create_user(p_username text,p_display_name text,p_password text,p_role text default 'user')
returns uuid language plpgsql security definer set search_path=public as $$ declare nid uuid; begin
 if exists(select 1 from public.app_users) and not public.app_is_admin() then raise exception 'Admin requis'; end if;
 insert into public.app_users(username,display_name,password_hash,role) values(lower(trim(p_username)),trim(p_display_name),crypt(p_password,gen_salt('bf')),p_role) returning id into nid; return nid; end $$;
create or replace function public.app_reset_password(p_user uuid,p_password text) returns void language plpgsql security definer set search_path=public as $$ begin if not public.app_is_admin() then raise exception 'Admin requis'; end if; update public.app_users set password_hash=crypt(p_password,gen_salt('bf')) where id=p_user; end $$;
create or replace function public.app_set_user_active(p_user uuid,p_active boolean) returns void language plpgsql security definer set search_path=public as $$ begin if not public.app_is_admin() then raise exception 'Admin requis'; end if; update public.app_users set active=p_active where id=p_user; end $$;

-- Convertit les anciens statuts sans perdre les pages.
update public.pages set status=case
 when status in ('Terminé','BAT','En maquette') then 'Maquetté'
 when status='Relu' then 'Relu'
 when status in ('À relire','Reçu') then 'À relire'
 when status in ('En cours','Commandé') then 'En cours d’écriture'
 else 'À distribuer à un pigiste' end;

-- RLS : accès uniquement avec une session interne valide.
alter table public.app_users enable row level security; alter table public.app_sessions enable row level security;
alter table public.page_comments enable row level security; alter table public.notifications enable row level security; alter table public.page_files enable row level security;

do $$ declare t text; begin
 foreach t in array array['magazines','pages','ideas','app_users','page_comments','notifications','page_files'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists app_access on public.%I',t);
  execute format('create policy app_access on public.%I for all to anon, authenticated using (public.app_user_id() is not null) with check (public.app_user_id() is not null)',t);
 end loop;
end $$;
-- Supprime les anciennes policies permissives connues sur les tables métier.
do $$ declare r record; begin for r in select schemaname,tablename,policyname from pg_policies where schemaname='public' and tablename in ('magazines','pages','ideas') and policyname <> 'app_access' loop execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename); end loop; end $$;

drop policy if exists app_files on storage.objects;
create policy app_files on storage.objects for all to anon, authenticated using (bucket_id='page-files' and public.app_user_id() is not null) with check (bucket_id='page-files' and public.app_user_id() is not null);

grant execute on function public.app_login(text,text) to anon,authenticated;
grant execute on function public.app_logout(uuid) to anon,authenticated;
grant execute on function public.app_create_user(text,text,text,text) to anon,authenticated;
grant execute on function public.app_reset_password(uuid,text) to anon,authenticated;
grant execute on function public.app_set_user_active(uuid,boolean) to anon,authenticated;
grant select,insert,update,delete on public.magazines,public.pages,public.ideas,public.app_users,public.page_comments,public.notifications,public.page_files to anon,authenticated;

-- Premier lancement : si aucun utilisateur n'existe, exécuter ensuite :
-- select public.app_create_user('camille','Camille','CHANGE-MOI','admin');
