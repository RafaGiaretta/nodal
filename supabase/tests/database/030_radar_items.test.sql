-- Itens do radar, histórico e fontes (1.2.1.3 a 1.2.1.5, 1.2.2.1, 1.2.2.2).
begin;
create extension if not exists pgtap with schema extensions;

create function pg_temp.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.login_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'anon', true);
end $$;

select plan(39);

-- A e B concluíram o onboarding; C ainda não.
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'ana@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'bruno@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000c', 'carla@test.local', 'authenticated', 'authenticated');
update public.profiles set slug = 'ana', terms_version = 'v1' where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set slug = 'bruno', terms_version = 'v1' where id = '00000000-0000-0000-0000-00000000000b';

insert into public.topics (id, name) values
  ('10000000-0000-0000-0000-000000000001', 'Kubernetes'),
  ('10000000-0000-0000-0000-000000000002', 'Rust'),
  ('10000000-0000-0000-0000-000000000003', 'GraphQL');

-- Criação pelo dono -----------------------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select lives_ok(
  $$ insert into public.radar_items (id, topic_id, quadrant, ring, summary, status)
     values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
             'platforms', 'adopt', 'Uso em produção', 'published') $$,
  'dono com onboarding cria item publicado'
);
select isnt(
  (select published_at from public.radar_items where id = '20000000-0000-0000-0000-000000000001'),
  null, 'publicação registra a data'
);
select results_eq(
  $$ select from_ring::text, to_ring::text, from_quadrant::text, to_quadrant::text, reason
     from public.ring_history where item_id = '20000000-0000-0000-0000-000000000001' $$,
  $$ values (null::text, 'adopt', null::text, 'platforms', null::text) $$,
  'criação gera registro inicial no histórico, sem motivo'
);
select throws_ok(
  $$ insert into public.radar_items (topic_id, quadrant, ring)
     values ('10000000-0000-0000-0000-000000000001', 'tools', 'trial') $$,
  '23505', null, 'um item por usuário por tema'
);
select lives_ok(
  $$ insert into public.radar_items (id, topic_id, quadrant, ring)
     values ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002',
             'languages_frameworks', 'assess') $$,
  'dono cria rascunho'
);
select lives_ok(
  $$ insert into public.radar_items (id, topic_id, quadrant, ring, status, visibility)
     values ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003',
             'languages_frameworks', 'hold', 'published', 'private') $$,
  'dono cria item publicado privado'
);
select throws_ok(
  $$ insert into public.radar_items (topic_id, quadrant, ring, linkedin_post_url)
     values ('10000000-0000-0000-0000-000000000002', 'tools', 'trial', 'https://evil.example.com/post') $$,
  '23514', null, 'link do post precisa ser do LinkedIn'
);
reset role;

-- Onboarding obrigatório para publicar ----------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000c');
select throws_ok(
  $$ insert into public.radar_items (topic_id, quadrant, ring, status)
     values ('10000000-0000-0000-0000-000000000001', 'tools', 'trial', 'published') $$,
  '42501', null, 'sem slug e aceite dos termos, usuário não publica'
);
select lives_ok(
  $$ insert into public.radar_items (id, topic_id, quadrant, ring)
     values ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000001', 'tools', 'trial') $$,
  'sem onboarding, usuário cria rascunho'
);
select throws_ok(
  $$ update public.radar_items set status = 'published' where id = '20000000-0000-0000-0000-000000000009' $$,
  '42501', null, 'sem onboarding, usuário não publica rascunho'
);
reset role;

-- Leitura por terceiros -------------------------------------------------------

select pg_temp.login_anon();
select results_eq(
  $$ select id from public.radar_items $$,
  $$ values ('20000000-0000-0000-0000-000000000001'::uuid) $$,
  'visitante vê apenas itens publicados e públicos'
);
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b');
select results_eq(
  $$ select id from public.radar_items $$,
  $$ values ('20000000-0000-0000-0000-000000000001'::uuid) $$,
  'outro usuário não vê rascunhos nem itens privados'
);

-- Escrita por terceiros -------------------------------------------------------

update public.radar_items set summary = 'invadido' where id = '20000000-0000-0000-0000-000000000001';
delete from public.radar_items where id = '20000000-0000-0000-0000-000000000001';
select throws_ok(
  $$ insert into public.radar_items (user_id, topic_id, quadrant, ring)
     values ('00000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000002', 'tools', 'trial') $$,
  '42501', null, 'usuário B não cria item em nome de A'
);
select throws_ok(
  $$ update public.radar_items set user_id = '00000000-0000-0000-0000-00000000000b'
     where id = '20000000-0000-0000-0000-000000000001' $$,
  '42501', null, 'dono do item não é alterado pela API'
);
reset role;
select is(
  (select summary from public.radar_items where id = '20000000-0000-0000-0000-000000000001'),
  'Uso em produção', 'usuário B não altera item de A'
);
select is(
  (select count(*)::int from public.radar_items where id = '20000000-0000-0000-0000-000000000001'),
  1, 'usuário B não remove item de A'
);

-- Mudança de anel e histórico -------------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select throws_ok(
  $$ update public.radar_items set ring = 'trial' where id = '20000000-0000-0000-0000-000000000001' $$,
  '23514', null, 'mudança de anel sem motivo é bloqueada'
);
select throws_ok(
  $$ update public.radar_items set quadrant = 'tools', move_reason = '   '
     where id = '20000000-0000-0000-0000-000000000001' $$,
  '23514', null, 'mudança de quadrante com motivo em branco é bloqueada'
);
select lives_ok(
  $$ update public.radar_items set ring = 'trial', move_reason = 'Custo operacional alto'
     where id = '20000000-0000-0000-0000-000000000001' $$,
  'mudança de anel com motivo é aceita'
);
select results_eq(
  $$ select from_ring::text, to_ring::text, reason, changed_by from public.ring_history
     where item_id = '20000000-0000-0000-0000-000000000001' and from_ring is not null $$,
  $$ values ('adopt', 'trial', 'Custo operacional alto', '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'histórico registra anel anterior, novo anel, motivo e autor'
);
select is(
  (select move_reason from public.radar_items where id = '20000000-0000-0000-0000-000000000001'),
  null, 'motivo não fica armazenado no item'
);
select lives_ok(
  $$ update public.radar_items set quadrant = 'tools', move_reason = 'Uso como ferramenta'
     where id = '20000000-0000-0000-0000-000000000001' $$,
  'mudança de quadrante com motivo é aceita'
);
update public.radar_items set summary = 'Resumo revisado' where id = '20000000-0000-0000-0000-000000000001';
select is(
  (select count(*)::int from public.ring_history where item_id = '20000000-0000-0000-0000-000000000001'),
  3, 'edição sem mudança de posição não gera histórico'
);
select throws_ok(
  $$ insert into public.ring_history (item_id, to_quadrant, to_ring)
     values ('20000000-0000-0000-0000-000000000001', 'tools', 'adopt') $$,
  '42501', null, 'histórico não é escrito pela API'
);
select throws_ok(
  $$ delete from public.ring_history where item_id = '20000000-0000-0000-0000-000000000001' $$,
  '42501', null, 'histórico não é apagado pela API'
);
reset role;
select throws_ok(
  $$ insert into public.ring_history (item_id, from_quadrant, to_quadrant, from_ring, to_ring)
     values ('20000000-0000-0000-0000-000000000001', 'tools', 'tools', 'trial', 'hold') $$,
  '23514', null, 'restrição do histórico exige motivo em mudança, mesmo fora da trigger'
);

-- Fontes ----------------------------------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select lives_ok(
  $$ insert into public.item_sources (item_id, title, url, kind) values
       ('20000000-0000-0000-0000-000000000001', 'Documentação', 'https://kubernetes.io/docs/', 'documentation'),
       ('20000000-0000-0000-0000-000000000001', 'Palestra', 'https://youtube.com/watch?v=x', 'video') $$,
  'item aceita várias fontes'
);
select throws_ok(
  $$ insert into public.item_sources (item_id, title, url)
     values ('20000000-0000-0000-0000-000000000001', 'XSS', 'javascript:alert(1)') $$,
  '23514', null, 'URL da fonte é validada'
);
select throws_ok(
  $$ insert into public.item_sources (item_id, title, url, suggested_by)
     values ('20000000-0000-0000-0000-000000000001', 'Crédito', 'https://example.com/a',
             '00000000-0000-0000-0000-00000000000b') $$,
  '42501', null, 'crédito de sugestão não é escrito pela API'
);
insert into public.item_sources (item_id, title, url)
  values ('20000000-0000-0000-0000-000000000002', 'Livro', 'https://doc.rust-lang.org/book/');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b');
select throws_ok(
  $$ insert into public.item_sources (item_id, title, url)
     values ('20000000-0000-0000-0000-000000000001', 'Spam', 'https://spam.example.com') $$,
  '42501', null, 'usuário B não adiciona fonte no item de A'
);
update public.item_sources set title = 'invadido' where item_id = '20000000-0000-0000-0000-000000000001';
delete from public.item_sources where item_id = '20000000-0000-0000-0000-000000000001';
reset role;
select is(
  (select count(*)::int from public.item_sources
   where item_id = '20000000-0000-0000-0000-000000000001' and title <> 'invadido'),
  2, 'usuário B não altera nem remove fontes de A'
);

-- Fontes e histórico seguem a visibilidade do item ----------------------------

select pg_temp.login_anon();
select is(
  (select count(*)::int from public.item_sources), 2,
  'visitante vê fontes apenas de itens públicos'
);
select is(
  (select count(distinct item_id)::int from public.ring_history), 1,
  'visitante vê histórico apenas de itens públicos'
);
reset role;

-- Radar privado ---------------------------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
update public.profiles set radar_visibility = 'private' where id = '00000000-0000-0000-0000-00000000000a';
select is((select count(*)::int from public.radar_items), 3, 'dono continua vendo o próprio radar privado');
reset role;

select pg_temp.login_anon();
select is_empty($$ select id from public.radar_items $$, 'radar privado não aparece para visitante');
select is_empty($$ select id from public.item_sources $$, 'fontes de radar privado não aparecem');
select is_empty($$ select id from public.ring_history $$, 'histórico de radar privado não aparece');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b');
select is_empty($$ select id from public.radar_items $$, 'radar privado não aparece para outro usuário');
reset role;

-- Remoção pelo dono -----------------------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
delete from public.radar_items where id = '20000000-0000-0000-0000-000000000002';
reset role;
select is(
  (select count(*)::int from public.item_sources where item_id = '20000000-0000-0000-0000-000000000002'),
  0, 'dono remove item e as fontes vão junto'
);

select * from finish();
rollback;
