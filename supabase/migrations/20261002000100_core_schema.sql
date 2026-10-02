-- Núcleo do modelo multiusuário: perfis, catálogo de temas, itens do radar,
-- fontes e histórico de movimentações (itens 1.2.1.1 a 1.2.1.5 e 1.2.1.7).

create extension if not exists unaccent with schema extensions;

-- Tipos -----------------------------------------------------------------------

create type public.quadrant as enum ('techniques', 'tools', 'platforms', 'languages_frameworks');
create type public.ring as enum ('adopt', 'trial', 'assess', 'hold');
create type public.user_role as enum ('user', 'admin');
create type public.visibility as enum ('public', 'private');
create type public.item_status as enum ('draft', 'published');
create type public.source_kind as enum (
  'article', 'video', 'book', 'course', 'documentation', 'repository', 'podcast', 'other'
);

-- Funções utilitárias ---------------------------------------------------------

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Normaliza nomes de temas e apelidos: minúsculas, sem acento e sem espaços,
-- pontos, hífens ou sublinhados. Mantém # e + para distinguir C, C# e C++.
create function public.normalize_name(value text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select regexp_replace(
    lower(extensions.unaccent('extensions.unaccent'::regdictionary, btrim(value))),
    '[[:space:]._-]+', '', 'g'
  );
$$;

-- Perfis ----------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  slug text unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'),
  display_name text not null default '' check (char_length(display_name) <= 100),
  avatar_url text check (avatar_url ~ '^https?://'),
  headline text check (char_length(headline) <= 220),
  role public.user_role not null default 'user',
  terms_version text,
  terms_accepted_at timestamptz,
  radar_visibility public.visibility not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.profiles.role is
  'Atribuído apenas por migration ou pelo painel do Supabase, nunca pela API.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- O aceite dos termos sempre usa o horário do servidor.
create function public.profiles_stamp_terms()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.terms_version is distinct from old.terms_version then
    new.terms_accepted_at := case when new.terms_version is null then null else now() end;
  end if;
  return new;
end;
$$;

create trigger profiles_stamp_terms
  before update on public.profiles
  for each row execute function public.profiles_stamp_terms();

-- Cria o perfil no primeiro login, com nome e foto vindos do LinkedIn (OIDC).
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    left(coalesce(new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name', ''), 100),
    nullif(coalesce(new.raw_user_meta_data ->> 'picture', new.raw_user_meta_data ->> 'avatar_url'), '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'admin' from public.profiles where id = (select auth.uid())),
    false
  );
$$;

-- Sem slug público e aceite dos termos, o usuário não publica itens (1.3.1.3).
create function public.has_completed_onboarding()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and slug is not null
      and terms_accepted_at is not null
  );
$$;

-- Catálogo de temas -----------------------------------------------------------

create table public.topics (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  normalized_name text generated always as (public.normalize_name(name)) stored unique
    check (normalized_name <> ''),
  description text check (char_length(description) <= 1000),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger topics_set_updated_at
  before update on public.topics
  for each row execute function public.set_updated_at();

create table public.topic_aliases (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics (id) on delete cascade,
  alias text not null check (char_length(btrim(alias)) between 1 and 80),
  normalized_alias text generated always as (public.normalize_name(alias)) stored unique
    check (normalized_alias <> ''),
  created_at timestamptz not null default now()
);

create index topic_aliases_topic_id_idx on public.topic_aliases (topic_id);

-- Nome e apelido compartilham o mesmo espaço: um apelido não pode coincidir com
-- o nome de um tema, e um tema novo não pode coincidir com um apelido existente.
create function public.topics_check_alias_collision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.topic_aliases
    where normalized_alias = public.normalize_name(new.name)
  ) then
    raise exception 'O nome "%" já é apelido de outro tema', new.name
      using errcode = 'unique_violation';
  end if;
  return new;
end;
$$;

create trigger topics_check_alias_collision
  before insert or update of name on public.topics
  for each row execute function public.topics_check_alias_collision();

create function public.topic_aliases_check_name_collision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.topics
    where normalized_name = public.normalize_name(new.alias)
  ) then
    raise exception 'O apelido "%" já é nome de um tema', new.alias
      using errcode = 'unique_violation';
  end if;
  return new;
end;
$$;

create trigger topic_aliases_check_name_collision
  before insert or update of alias on public.topic_aliases
  for each row execute function public.topic_aliases_check_name_collision();

-- Resolve um nome ou apelido para o tema canônico.
create function public.resolve_topic(query text)
returns uuid
language sql
stable
set search_path = ''
as $$
  select id from public.topics where normalized_name = public.normalize_name(query)
  union all
  select topic_id from public.topic_aliases where normalized_alias = public.normalize_name(query)
  limit 1;
$$;

-- Itens do radar --------------------------------------------------------------

create table public.radar_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  topic_id uuid not null references public.topics (id) on delete restrict,
  quadrant public.quadrant not null,
  ring public.ring not null,
  summary text not null default '' check (char_length(summary) <= 5000),
  rationale text not null default '' check (char_length(rationale) <= 5000),
  linkedin_post_url text check (linkedin_post_url ~ '^https://([a-z0-9-]+\.)*linkedin\.com/'),
  status public.item_status not null default 'draft',
  visibility public.visibility not null default 'public',
  studied_at date,
  last_reviewed_at timestamptz not null default now(),
  published_at timestamptz,
  -- Campo transitório: recebe o motivo de uma mudança de anel ou quadrante,
  -- que a trigger grava em ring_history. Nunca fica armazenado.
  move_reason text check (move_reason is null),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, topic_id)
);

create index radar_items_topic_id_idx on public.radar_items (topic_id);
create index radar_items_public_idx on public.radar_items (user_id)
  where status = 'published' and visibility = 'public';

create trigger radar_items_set_updated_at
  before update on public.radar_items
  for each row execute function public.set_updated_at();

-- Fontes do item --------------------------------------------------------------

create table public.item_sources (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.radar_items (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 300),
  url text not null check (url ~ '^https?://[^[:space:]/]+\.[^[:space:]]+$' and char_length(url) <= 2048),
  kind public.source_kind not null default 'other',
  suggested_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index item_sources_item_id_idx on public.item_sources (item_id);

-- Histórico de movimentações --------------------------------------------------

create table public.ring_history (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.radar_items (id) on delete cascade,
  from_quadrant public.quadrant,
  to_quadrant public.quadrant not null,
  from_ring public.ring,
  to_ring public.ring not null,
  reason text,
  changed_by uuid references public.profiles (id) on delete set null,
  proposal_id uuid,
  created_at timestamptz not null default now(),
  -- O registro de criação não exige motivo; toda mudança exige.
  check (
    (from_ring is null and from_quadrant is null)
    or (from_ring is not null and from_quadrant is not null and char_length(btrim(coalesce(reason, ''))) > 0)
  )
);

create index ring_history_item_id_idx on public.ring_history (item_id, created_at);

create function public.radar_items_track_move()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.ring_history (item_id, to_quadrant, to_ring, changed_by)
    values (new.id, new.quadrant, new.ring, (select auth.uid()));
    return null;
  end if;

  if new.ring is distinct from old.ring or new.quadrant is distinct from old.quadrant then
    if char_length(btrim(coalesce(new.move_reason, ''))) = 0 then
      raise exception 'Informe o motivo da mudança de anel ou quadrante'
        using errcode = 'check_violation', hint = 'Envie o campo move_reason.';
    end if;

    insert into public.ring_history
      (item_id, from_quadrant, to_quadrant, from_ring, to_ring, reason, changed_by)
    values
      (new.id, old.quadrant, new.quadrant, old.ring, new.ring, btrim(new.move_reason), (select auth.uid()));

    new.last_reviewed_at := now();
  end if;

  if new.status = 'published' and old.status = 'draft' and new.published_at is null then
    new.published_at := now();
  end if;

  new.move_reason := null;
  return new;
end;
$$;

create trigger radar_items_track_move_update
  before update on public.radar_items
  for each row execute function public.radar_items_track_move();

create trigger radar_items_track_move_insert
  after insert on public.radar_items
  for each row execute function public.radar_items_track_move();

create function public.radar_items_stamp_published()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.move_reason := null;
  if new.status = 'published' and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$$;

create trigger radar_items_stamp_published
  before insert on public.radar_items
  for each row execute function public.radar_items_stamp_published();
