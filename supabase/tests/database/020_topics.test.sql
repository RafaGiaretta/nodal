-- Catálogo de temas: normalização, apelidos e permissões por papel (1.2.1.2, 1.2.2.1, 1.2.2.3).
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

select plan(22);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'ana@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000c', 'admin@test.local', 'authenticated', 'authenticated');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-00000000000c';

-- Normalização
select is(public.normalize_name('  Next.js '), 'nextjs', 'remove espaços e pontos');
select is(public.normalize_name('Next JS'), 'nextjs', 'remove espaços internos');
select is(public.normalize_name('Programação Funcional'), 'programacaofuncional', 'remove acentos');
select is(public.normalize_name('event_driven-architecture'), 'eventdrivenarchitecture', 'remove hífens e sublinhados');
select isnt(public.normalize_name('C#'), public.normalize_name('C'), 'C# é diferente de C');
select isnt(public.normalize_name('C++'), public.normalize_name('C#'), 'C++ é diferente de C#');

-- Visitante
select pg_temp.login_anon();
select throws_ok(
  $$ insert into public.topics (name) values ('Kubernetes') $$,
  '42501', null, 'visitante não cria tema'
);
reset role;

-- Usuário autenticado cria tema
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select lives_ok($$ insert into public.topics (name) values ('Next.js') $$, 'usuário autenticado cria tema');
select is(
  (select created_by from public.topics where name = 'Next.js'),
  '00000000-0000-0000-0000-00000000000a'::uuid, 'criador registrado automaticamente'
);
select throws_ok(
  $$ insert into public.topics (name) values ('next js') $$,
  '23505', null, 'nome que normaliza igual a um tema existente é recusado'
);
select throws_ok(
  $$ insert into public.topics (name) values (' ... ') $$,
  '23514', null, 'nome que normaliza para vazio é recusado'
);
select throws_ok(
  $$ insert into public.topics (name, created_by) values ('Rust', '00000000-0000-0000-0000-00000000000c') $$,
  '42501', null, 'usuário não atribui a criação a outra pessoa'
);

-- Usuário não edita catálogo
update public.topics set description = 'alterado' where name = 'Next.js';
select throws_ok(
  $$ insert into public.topic_aliases (topic_id, alias)
     select id, 'NextJS App Router' from public.topics where name = 'Next.js' $$,
  '42501', null, 'usuário não cria apelido'
);
delete from public.topics where name = 'Next.js';
reset role;
select is(
  (select description from public.topics where name = 'Next.js'),
  null, 'usuário não edita tema, nem o que criou'
);
select is((select count(*)::int from public.topics where name = 'Next.js'), 1, 'usuário não remove tema');

-- Admin edita o catálogo
select pg_temp.login('00000000-0000-0000-0000-00000000000c');
update public.topics set description = 'Framework React' where name = 'Next.js';
select lives_ok(
  $$ insert into public.topic_aliases (topic_id, alias)
     select id, 'Nextjs Framework' from public.topics where name = 'Next.js' $$,
  'admin cria apelido'
);
select throws_ok(
  $$ insert into public.topic_aliases (topic_id, alias)
     select id, 'NEXT.JS' from public.topics where name = 'Next.js' $$,
  '23505', null, 'apelido que coincide com nome de tema é recusado'
);
reset role;
select is(
  (select description from public.topics where name = 'Next.js'),
  'Framework React', 'admin edita tema'
);

-- Tema novo não pode coincidir com apelido
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select throws_ok(
  $$ insert into public.topics (name) values ('nextjs-framework') $$,
  '23505', null, 'tema novo que coincide com apelido é recusado'
);

-- Resolução para o tema canônico
select is(
  public.resolve_topic('next.js framework'),
  (select id from public.topics where name = 'Next.js'),
  'apelido resolve para o tema canônico'
);
select is(public.resolve_topic('Inexistente'), null, 'nome desconhecido não resolve');

-- Leitura pública
select pg_temp.login_anon();
select is(
  (select count(*)::int from public.topics t join public.topic_aliases a on a.topic_id = t.id),
  1, 'visitante lê temas e apelidos'
);

select * from finish();
rollback;
