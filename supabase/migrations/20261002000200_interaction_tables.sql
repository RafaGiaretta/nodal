-- Tabelas de interação usadas nas etapas 2 e 3 (item 1.2.1.6).
-- Nascem com RLS habilitado e sem políticas: ninguém acessa pela API até que
-- cada política entre, com teste, na etapa correspondente.

create type public.comment_status as enum ('visible', 'hidden', 'removed');
create type public.suggestion_status as enum ('pending', 'accepted', 'rejected');
create type public.proposal_status as enum ('open', 'accepted', 'rejected', 'withdrawn');
create type public.topic_suggestion_status as enum ('pending', 'accepted', 'dismissed');
create type public.report_target as enum ('comment', 'item', 'profile');
create type public.report_status as enum ('open', 'resolved', 'dismissed');

-- Comentários -----------------------------------------------------------------

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.radar_items (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  parent_id uuid references public.comments (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 5000),
  status public.comment_status not null default 'visible',
  edited_at timestamptz,
  created_at timestamptz not null default now()
);

create index comments_item_id_idx on public.comments (item_id, created_at);
create index comments_author_id_idx on public.comments (author_id);
create index comments_parent_id_idx on public.comments (parent_id);

-- Votos de anel ---------------------------------------------------------------

create table public.ring_votes (
  item_id uuid not null references public.radar_items (id) on delete cascade,
  voter_id uuid not null references public.profiles (id) on delete cascade,
  ring public.ring not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (item_id, voter_id)
);

create index ring_votes_voter_id_idx on public.ring_votes (voter_id);

create trigger ring_votes_set_updated_at
  before update on public.ring_votes
  for each row execute function public.set_updated_at();

-- Referências sugeridas -------------------------------------------------------

create table public.reference_suggestions (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.radar_items (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  url text not null check (url ~ '^https?://[^[:space:]/]+\.[^[:space:]]+$' and char_length(url) <= 2048),
  title text not null check (char_length(btrim(title)) between 1 and 300),
  note text check (char_length(note) <= 2000),
  status public.suggestion_status not null default 'pending',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index reference_suggestions_item_id_idx on public.reference_suggestions (item_id);
create index reference_suggestions_author_id_idx on public.reference_suggestions (author_id);

-- Propostas de movimentação ---------------------------------------------------

create table public.move_proposals (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.radar_items (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  proposed_ring public.ring not null,
  rationale text not null check (char_length(btrim(rationale)) between 1 and 5000),
  status public.proposal_status not null default 'open',
  owner_response text check (char_length(owner_response) <= 5000),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (status in ('open', 'withdrawn') or char_length(btrim(coalesce(owner_response, ''))) > 0)
);

-- No máximo uma proposta aberta por usuário por item (2.1.4.3).
create unique index move_proposals_one_open_idx
  on public.move_proposals (item_id, author_id) where status = 'open';
create index move_proposals_author_id_idx on public.move_proposals (author_id);

create table public.move_proposal_references (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.move_proposals (id) on delete cascade,
  url text not null check (url ~ '^https?://[^[:space:]/]+\.[^[:space:]]+$' and char_length(url) <= 2048),
  title text not null check (char_length(btrim(title)) between 1 and 300)
);

create index move_proposal_references_proposal_id_idx
  on public.move_proposal_references (proposal_id);

alter table public.ring_history
  add constraint ring_history_proposal_id_fkey
  foreign key (proposal_id) references public.move_proposals (id) on delete set null;

create index ring_history_proposal_id_idx on public.ring_history (proposal_id);

-- Rede ------------------------------------------------------------------------

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create index follows_followee_id_idx on public.follows (followee_id);

create table public.topic_suggestions (
  id uuid primary key default gen_random_uuid(),
  from_user uuid references public.profiles (id) on delete set null,
  to_user uuid not null references public.profiles (id) on delete cascade,
  topic_id uuid not null references public.topics (id) on delete cascade,
  note text check (char_length(note) <= 2000),
  status public.topic_suggestion_status not null default 'pending',
  created_at timestamptz not null default now(),
  check (from_user <> to_user)
);

create index topic_suggestions_to_user_idx on public.topic_suggestions (to_user, status);
create index topic_suggestions_from_user_idx on public.topic_suggestions (from_user);
create index topic_suggestions_topic_id_idx on public.topic_suggestions (topic_id);

-- Moderação -------------------------------------------------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles (id) on delete set null,
  target_type public.report_target not null,
  target_id uuid not null,
  reason text not null check (char_length(btrim(reason)) between 1 and 2000),
  status public.report_status not null default 'open',
  resolved_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index reports_status_idx on public.reports (status, created_at);
create index reports_reporter_id_idx on public.reports (reporter_id);
create index reports_resolved_by_idx on public.reports (resolved_by);

create table public.user_blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index user_blocks_blocked_id_idx on public.user_blocks (blocked_id);

-- Notificações ----------------------------------------------------------------

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_id_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;

create table public.notification_preferences (
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  email_enabled boolean not null default true,
  digest boolean not null default false,
  primary key (user_id, type)
);

-- RLS habilitado, sem políticas -----------------------------------------------

alter table public.comments enable row level security;
alter table public.ring_votes enable row level security;
alter table public.reference_suggestions enable row level security;
alter table public.move_proposals enable row level security;
alter table public.move_proposal_references enable row level security;
alter table public.follows enable row level security;
alter table public.topic_suggestions enable row level security;
alter table public.reports enable row level security;
alter table public.user_blocks enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
