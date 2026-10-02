-- Toda tabela do schema public precisa ter Row Level Security habilitado.
begin;
create extension if not exists pgtap with schema extensions;

select plan(1);

select is_empty(
  $$
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity
  $$,
  'toda tabela do schema public tem RLS habilitado'
);

select * from finish();
rollback;
