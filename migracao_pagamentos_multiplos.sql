-- =========================================================
-- MIGRAÇÃO: Pagamentos combinados (mais de uma forma por comanda)
-- Rode no SQL Editor do Supabase.
-- =========================================================

create table if not exists public.pagamentos_comanda (
  id uuid primary key default gen_random_uuid(),
  agendamento_id uuid not null references public.agendamentos(id) on delete cascade,
  forma_pagamento text not null check (forma_pagamento in ('debito','credito','dinheiro','pix')),
  valor numeric(10,2) not null check (valor > 0),
  parcelas smallint check (parcelas between 1 and 24),
  created_at timestamptz not null default now()
);

create index if not exists idx_pagamentos_comanda_agendamento on public.pagamentos_comanda(agendamento_id);

alter table public.agendamentos
  add column if not exists pago boolean not null default false;

-- Marca como pago quem já tinha forma_pagamento preenchida (dados existentes)
update public.agendamentos set pago = true where forma_pagamento is not null and pago = false;

-- Migra pagamentos já existentes (forma única) para a nova tabela de detalhamento
insert into public.pagamentos_comanda (agendamento_id, forma_pagamento, valor, parcelas, created_at)
select a.id, a.forma_pagamento, coalesce(p.valor,0) - coalesce(a.valor_desconto,0), a.parcelas, coalesce(a.data_pagamento, a.updated_at)
from public.agendamentos a
join public.procedimentos p on p.id = a.procedimento_id
where a.forma_pagamento is not null
  and not exists (select 1 from public.pagamentos_comanda pc where pc.agendamento_id = a.id);

-- Recalcula a comissão considerando "pago" em vez de "forma_pagamento"
create or replace function public.calcular_comissao_agendamento()
returns trigger as $$
declare
  v_valor_procedimento numeric(10,2);
  v_percentual numeric(5,2);
begin
  if new.remuneracao_pagamento_id is not null then
    return new;
  end if;
  if new.pago is not true then
    new.valor_comissao := null;
    new.percentual_comissao := null;
    return new;
  end if;
  select valor into v_valor_procedimento from public.procedimentos where id = new.procedimento_id;
  select percentual into v_percentual from public.colaborador_comissoes
    where colaborador_id = new.colaborador_id and procedimento_id = new.procedimento_id;
  v_percentual := coalesce(v_percentual, 0);
  new.percentual_comissao := v_percentual;
  new.valor_comissao := round((coalesce(v_valor_procedimento,0) - coalesce(new.valor_desconto,0)) * v_percentual / 100, 2);
  return new;
end;
$$ language plpgsql security definer;

-- Registra uma ou mais formas de pagamento de uma comanda de uma só vez
create or replace function public.registrar_pagamento_comanda(
  p_agendamento_id uuid,
  p_pagamentos jsonb,
  p_valor_desconto numeric default 0
)
returns public.agendamentos as $$
declare
  v_agendamento public.agendamentos;
  v_item jsonb;
  v_qtd int;
begin
  if not public.tem_permissao('comanda_registrar_pagamento') then
    raise exception 'Sem permissão para registrar pagamento';
  end if;
  if coalesce(p_valor_desconto,0) > 0 and not public.tem_permissao('comanda_aplicar_desconto') then
    raise exception 'Sem permissão para aplicar desconto';
  end if;

  v_qtd := jsonb_array_length(p_pagamentos);
  if v_qtd is null or v_qtd = 0 then
    raise exception 'Informe ao menos uma forma de pagamento';
  end if;

  delete from public.pagamentos_comanda where agendamento_id = p_agendamento_id;

  for v_item in select * from jsonb_array_elements(p_pagamentos)
  loop
    insert into public.pagamentos_comanda (agendamento_id, forma_pagamento, valor, parcelas)
    values (
      p_agendamento_id,
      v_item->>'forma_pagamento',
      (v_item->>'valor')::numeric,
      nullif(v_item->>'parcelas','')::smallint
    );
  end loop;

  update public.agendamentos
  set
    valor_desconto = coalesce(p_valor_desconto, 0),
    pago = true,
    data_pagamento = coalesce(data_pagamento, now()),
    forma_pagamento = case when v_qtd = 1 then p_pagamentos->0->>'forma_pagamento' else null end,
    parcelas = case when v_qtd = 1 and p_pagamentos->0->>'forma_pagamento' = 'credito'
                    then nullif(p_pagamentos->0->>'parcelas','')::smallint else null end
  where id = p_agendamento_id
  returning * into v_agendamento;

  return v_agendamento;
end;
$$ language plpgsql security definer;

-- RLS de pagamentos_comanda
alter table public.pagamentos_comanda enable row level security;

drop policy if exists pagamentos_comanda_select on public.pagamentos_comanda;
create policy pagamentos_comanda_select on public.pagamentos_comanda for select
  using (public.tem_permissao('comanda_visualizar'));
-- inserts/updates/deletes só acontecem via função registrar_pagamento_comanda (security definer)
