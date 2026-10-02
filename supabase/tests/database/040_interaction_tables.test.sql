-- Tabelas de interação: fechadas para a API até a etapa 2, com restrições já ativas (1.2.1.6).
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

select plan(21);

select tables_are(
  'public',
  array[
    'profiles', 'topics', 'topic_aliases', 'radar_items', 'item_sources', 'ring_history',
    'comments', 'ring_votes', 'reference_suggestions', 'move_proposals', 'move_proposal_references',
    'follows', 'topic_suggestions', 'reports', 'user_blocks', 'notifications', 'notification_preferences'
  ],
  'schema public tem exatamente as tabelas previstas'
);

select is_empty(
  $$ select tablename from pg_policies
     where schemaname = 'public'
       and tablename in ('comments', 'ring_votes', 'reference_suggestions', 'move_proposals',
                         'move_proposal_references', 'follows', 'topic_suggestions', 'reports',
                         'user_blocks', 'notifications', 'notification_preferences') $$,
  'tabelas de interação ainda não têm políticas'
);

-- Dados criados fora da API
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'ana@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'bruno@test.local', 'authenticated', 'authenticated');
update public.profiles set slug = 'ana', terms_version = 'v1' where id = '00000000-0000-0000-0000-00000000000a';
insert into public.topics (id, name) values ('10000000-0000-0000-0000-000000000001', 'Kubernetes');
insert into public.radar_items (id, user_id, topic_id, quadrant, ring, status) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a',
   '10000000-0000-0000-0000-000000000001', 'platforms', 'adopt', 'published');
insert into public.comments (item_id, author_id, body) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'Ótimo estudo');
insert into public.ring_votes (item_id, voter_id, ring) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'trial');
insert into public.follows (follower_id, followee_id) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
insert into public.notifications (user_id, type) values ('00000000-0000-0000-0000-00000000000a', 'comment');

-- Fechadas para visitante e para usuário autenticado
select pg_temp.login_anon();
select is_empty($$ select id from public.comments $$, 'visitante não lê comentários');
select is_empty($$ select item_id from public.ring_votes $$, 'visitante não lê votos');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select is_empty($$ select id from public.notifications $$, 'usuário ainda não lê as próprias notificações');
select is_empty($$ select follower_id from public.follows $$, 'usuário ainda não lê seguidores');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b');
select throws_ok(
  $$ insert into public.comments (item_id, author_id, body)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'Oi') $$,
  '42501', null, 'usuário ainda não comenta pela API'
);
select throws_ok(
  $$ insert into public.ring_votes (item_id, voter_id, ring)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'hold') $$,
  '42501', null, 'usuário ainda não vota pela API'
);
select throws_ok(
  $$ insert into public.move_proposals (item_id, author_id, proposed_ring, rationale)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'hold', 'x') $$,
  '42501', null, 'usuário ainda não propõe pela API'
);
select throws_ok(
  $$ insert into public.reports (reporter_id, target_type, target_id, reason)
     values ('00000000-0000-0000-0000-00000000000b', 'item', '20000000-0000-0000-0000-000000000001', 'spam') $$,
  '42501', null, 'usuário ainda não denuncia pela API'
);
reset role;

-- Restrições já válidas no schema
select throws_ok(
  $$ insert into public.ring_votes (item_id, voter_id, ring)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'hold') $$,
  '23505', null, 'um voto por usuário por item'
);

insert into public.move_proposals (item_id, author_id, proposed_ring, rationale) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'trial', 'Custo alto');
select throws_ok(
  $$ insert into public.move_proposals (item_id, author_id, proposed_ring, rationale)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'hold', 'Outra') $$,
  '23505', null, 'no máximo uma proposta aberta por usuário por item'
);
select throws_ok(
  $$ update public.move_proposals set status = 'rejected' where status = 'open' $$,
  '23514', null, 'rejeição exige resposta do dono'
);
update public.move_proposals set status = 'rejected', owner_response = 'Ainda uso em produção' where status = 'open';
select lives_ok(
  $$ insert into public.move_proposals (item_id, author_id, proposed_ring, rationale)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'hold', 'Nova evidência') $$,
  'nova proposta é aceita depois que a anterior foi resolvida'
);

select throws_ok(
  $$ insert into public.follows (follower_id, followee_id)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a') $$,
  '23514', null, 'usuário não segue a si mesmo'
);
select throws_ok(
  $$ insert into public.user_blocks (blocker_id, blocked_id)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a') $$,
  '23514', null, 'usuário não bloqueia a si mesmo'
);
select throws_ok(
  $$ insert into public.comments (item_id, author_id, body)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', '   ') $$,
  '23514', null, 'comentário vazio é recusado'
);
select throws_ok(
  $$ insert into public.reference_suggestions (item_id, author_id, url, title)
     values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'ftp://x', 'X') $$,
  '23514', null, 'URL de referência sugerida é validada'
);

-- Exclusão de conta preserva contribuições anonimizadas
delete from auth.users where id = '00000000-0000-0000-0000-00000000000b';
select is(
  (select author_id from public.comments limit 1), null,
  'comentário de conta excluída fica sem autor'
);
select is_empty($$ select voter_id from public.ring_votes $$, 'votos de conta excluída são removidos');
select is_empty($$ select follower_id from public.follows $$, 'seguidores de conta excluída são removidos');

select * from finish();
rollback;
