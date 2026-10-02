-- Políticas de acesso das tabelas do núcleo (itens 1.2.2.1 a 1.2.2.3).
-- Permissões por coluna complementam o RLS: colunas como role, user_id e
-- suggested_by não podem ser escritas pela API.

alter table public.profiles enable row level security;
alter table public.topics enable row level security;
alter table public.topic_aliases enable row level security;
alter table public.radar_items enable row level security;
alter table public.item_sources enable row level security;
alter table public.ring_history enable row level security;

revoke insert, update, delete on
  public.profiles, public.topics, public.topic_aliases,
  public.radar_items, public.item_sources, public.ring_history
from anon;

-- Perfis ----------------------------------------------------------------------
-- Criados apenas pela trigger de primeiro login; o dono edita os próprios dados,
-- exceto o papel.

revoke insert, update, delete on public.profiles from authenticated;
grant update (slug, display_name, avatar_url, headline, terms_version, radar_visibility)
  on public.profiles to authenticated;

create policy "Perfis são públicos"
  on public.profiles for select
  to anon, authenticated
  using (true);

create policy "Dono edita o próprio perfil"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Catálogo de temas -----------------------------------------------------------
-- Qualquer usuário autenticado cria tema; edição e remoção apenas por admin.

revoke insert, update on public.topics from authenticated;
grant insert (name, description), update (name, description) on public.topics to authenticated;

create policy "Catálogo é público"
  on public.topics for select
  to anon, authenticated
  using (true);

create policy "Usuário autenticado cria tema"
  on public.topics for insert
  to authenticated
  with check (created_by = (select auth.uid()));

create policy "Admin edita tema"
  on public.topics for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "Admin remove tema"
  on public.topics for delete
  to authenticated
  using ((select public.is_admin()));

revoke insert, update on public.topic_aliases from authenticated;
grant insert (topic_id, alias), update (topic_id, alias) on public.topic_aliases to authenticated;

create policy "Apelidos são públicos"
  on public.topic_aliases for select
  to anon, authenticated
  using (true);

create policy "Admin cria apelido"
  on public.topic_aliases for insert
  to authenticated
  with check ((select public.is_admin()));

create policy "Admin edita apelido"
  on public.topic_aliases for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "Admin remove apelido"
  on public.topic_aliases for delete
  to authenticated
  using ((select public.is_admin()));

-- Itens do radar --------------------------------------------------------------
-- Terceiros só veem itens publicados e públicos de radares públicos.
-- Apenas o dono escreve, e só publica depois do onboarding.

revoke insert, update on public.radar_items from authenticated;
grant insert (
  id, topic_id, quadrant, ring, summary, rationale, linkedin_post_url,
  status, visibility, studied_at
) on public.radar_items to authenticated;
grant update (
  quadrant, ring, summary, rationale, linkedin_post_url,
  status, visibility, studied_at, last_reviewed_at, move_reason
) on public.radar_items to authenticated;

create function public.is_item_public(item public.radar_items)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select item.status = 'published'
    and item.visibility = 'public'
    and exists (
      select 1 from public.profiles p
      where p.id = item.user_id and p.radar_visibility = 'public'
    );
$$;

create policy "Itens públicos e os próprios são legíveis"
  on public.radar_items for select
  to anon, authenticated
  using (user_id = (select auth.uid()) or public.is_item_public(radar_items));

create policy "Dono cria item"
  on public.radar_items for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and (status = 'draft' or (select public.has_completed_onboarding()))
  );

create policy "Dono edita item"
  on public.radar_items for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (status = 'draft' or (select public.has_completed_onboarding()))
  );

create policy "Dono remove item"
  on public.radar_items for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- Fontes do item --------------------------------------------------------------
-- Visíveis junto com o item; apenas o dono do item escreve.

revoke insert, update on public.item_sources from authenticated;
grant insert (item_id, title, url, kind), update (title, url, kind)
  on public.item_sources to authenticated;

create function public.owns_item(target_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.radar_items
    where id = target_item_id and user_id = (select auth.uid())
  );
$$;

create policy "Fontes seguem a visibilidade do item"
  on public.item_sources for select
  to anon, authenticated
  using (exists (select 1 from public.radar_items i where i.id = item_id));

create policy "Dono do item cria fonte"
  on public.item_sources for insert
  to authenticated
  with check (public.owns_item(item_id));

create policy "Dono do item edita fonte"
  on public.item_sources for update
  to authenticated
  using (public.owns_item(item_id))
  with check (public.owns_item(item_id));

create policy "Dono do item remove fonte"
  on public.item_sources for delete
  to authenticated
  using (public.owns_item(item_id));

-- Histórico -------------------------------------------------------------------
-- Escrito apenas pela trigger; visível junto com o item.

revoke insert, update, delete on public.ring_history from authenticated;

create policy "Histórico segue a visibilidade do item"
  on public.ring_history for select
  to anon, authenticated
  using (exists (select 1 from public.radar_items i where i.id = item_id));
