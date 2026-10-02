-- Perfis: criação no primeiro login, leitura pública e escrita só pelo dono (1.2.1.1, 1.2.1.7, 1.2.2.1, 1.2.2.2).
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

select plan(14);

insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-00000000000a', 'ana@test.local',
   '{"name":"Ana Souza","picture":"https://media.licdn.com/ana.jpg"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000b', 'bruno@test.local',
   '{"name":"Bruno"}', 'authenticated', 'authenticated');

-- Trigger de primeiro login
select results_eq(
  $$ select display_name, avatar_url, role::text, slug from public.profiles
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  $$ values ('Ana Souza', 'https://media.licdn.com/ana.jpg', 'user', null::text) $$,
  'primeiro login cria perfil com nome e foto do LinkedIn, papel user e sem slug'
);

-- Leitura pública
select pg_temp.login_anon();
select is((select count(*)::int from public.profiles), 2, 'visitante anônimo lê perfis');
select throws_ok(
  $$ update public.profiles set headline = 'x' where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null, 'visitante anônimo não altera perfil'
);
reset role;

-- Escrita pelo dono
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select lives_ok(
  $$ update public.profiles set slug = 'ana-souza', headline = 'Engenheira de dados'
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  'dono altera slug e headline'
);
select is(
  (select headline from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'Engenheira de dados', 'alteração do dono persiste'
);
select throws_ok(
  $$ update public.profiles set slug = 'Ana Souza!' where id = '00000000-0000-0000-0000-00000000000a' $$,
  '23514', null, 'slug fora do formato é recusado'
);

-- Outro usuário
select pg_temp.login('00000000-0000-0000-0000-00000000000b');
update public.profiles set headline = 'invadido' where id = '00000000-0000-0000-0000-00000000000a';
select throws_ok(
  $$ update public.profiles set slug = 'ana-souza' where id = '00000000-0000-0000-0000-00000000000b' $$,
  '23505', null, 'slug é único'
);
reset role;
select is(
  (select headline from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'Engenheira de dados', 'usuário B não altera o perfil de A'
);

-- Papel de admin nunca pela API
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select throws_ok(
  $$ update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null, 'usuário não atribui o papel de admin a si mesmo'
);
select throws_ok(
  $$ insert into public.profiles (id, display_name) values (gen_random_uuid(), 'falso') $$,
  '42501', null, 'perfil não é criado pela API'
);
select throws_ok(
  $$ update public.profiles set terms_accepted_at = '2000-01-01' where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null, 'data de aceite dos termos não é escrita pela API'
);
select throws_ok(
  $$ delete from public.profiles where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null, 'perfil não é removido pela API'
);

-- Aceite dos termos com horário do servidor
update public.profiles set terms_version = '2026-10' where id = '00000000-0000-0000-0000-00000000000a';
reset role;
select isnt(
  (select terms_accepted_at from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  null, 'aceitar uma versão dos termos registra a data'
);

-- Admin só por migration ou painel
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.login('00000000-0000-0000-0000-00000000000b');
select ok(public.is_admin(), 'papel atribuído fora da API é reconhecido por is_admin');

select * from finish();
rollback;
