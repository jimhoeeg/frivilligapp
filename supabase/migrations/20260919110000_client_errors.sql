-- ============================================================================
-- RVK Frivillig – fejl fra medlemmernes telefoner
--
-- Før: gik noget i stykker hos et medlem, endte fejlen i browserens konsol,
-- hvor ingen nogensinde kigger. Klubben hørte først om det, hvis personen
-- selv sagde det — og de fleste siger det ikke, de holder bare op med at
-- bruge appen.
--
-- Efter: uventede fejl skrives hertil, og admins kan se dem i panelet.
--
-- Det er ikke en erstatning for et rigtigt overvågningsværktøj, men det
-- kræver ingen konto hos nogen, og det fanger det vigtigste: at noget er
-- gået galt, hvor, og for hvem.
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- ============================================================================

create table if not exists public.client_errors (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles(id) on delete set null,
  message    text not null,
  source     text,                      -- 'error' | 'unhandledrejection' | 'render'
  stack      text,
  url        text,
  user_agent text,
  created_at timestamptz default now()
);

create index if not exists client_errors_created_idx on public.client_errors (created_at desc);
create index if not exists client_errors_user_idx    on public.client_errors (user_id, created_at desc);

alter table public.client_errors enable row level security;

drop policy if exists "client_errors_select" on public.client_errors;
drop policy if exists "client_errors_insert" on public.client_errors;

-- Kun admins læser dem. Et medlem skal ikke kunne se andres fejl — en
-- stak-sporing kan indeholde hvad som helst.
create policy "client_errors_select" on public.client_errors for select
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- Indrapportering
--
-- Går gennem en funktion i stedet for en insert-politik, så der kan sættes
-- en grænse: én bruger kan højst lægge 20 fejl ind i timen. Ellers ville en
-- fejl inde i en render-løkke kunne fylde tabellen på få sekunder.
-- ============================================================================

create or replace function public.log_client_error(
  p_message    text,
  p_source     text default null,
  p_stack      text default null,
  p_url        text default null,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_recent int;
begin
  if auth.uid() is null then
    return;                                  -- ikke logget ind: drop den
  end if;

  select count(*) into v_recent
    from public.client_errors
   where user_id = auth.uid()
     and created_at > now() - interval '1 hour';

  if v_recent >= 20 then
    return;                                  -- nok for nu
  end if;

  insert into public.client_errors (user_id, message, source, stack, url, user_agent)
  values (
    auth.uid(),
    left(coalesce(nullif(p_message, ''), 'Ukendt fejl'), 500),
    left(p_source, 40),
    left(p_stack, 4000),
    left(p_url, 500),
    left(p_user_agent, 300)
  );
end;
$$;

grant execute on function public.log_client_error(text, text, text, text, text) to authenticated;


-- ============================================================================
-- Oprydning
--
-- Fejl ældre end 90 dage har ingen værdi og er personhenførbare, så de
-- slettes. Kører sammen med den daglige bekræftelse, hvis pg_cron er slået
-- til; ellers kan linjen køres i hånden en gang imellem.
-- ============================================================================

create or replace function public.prune_client_errors()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count int;
begin
  delete from public.client_errors where created_at < now() - interval '90 days';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

do $outer$
begin
  if exists (select 1 from cron.job where jobname = 'rvk_prune_errors') then
    perform cron.unschedule('rvk_prune_errors');
  end if;
  perform cron.schedule('rvk_prune_errors', '30 3 * * *',
                        $job$ select public.prune_client_errors(); $job$);
  raise notice 'pg_cron: fejl ældre end 90 dage ryddes kl. 03:30 UTC';
exception when others then
  raise notice 'pg_cron ikke tilgængelig (%). Kør select public.prune_client_errors(); i hånden en gang imellem.', sqlerrm;
end
$outer$;
