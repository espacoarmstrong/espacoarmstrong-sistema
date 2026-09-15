-- =========================================================
-- MIGRAÇÃO: Remuneração — PASSO 2 de 2
-- Rode no SQL Editor do Supabase, somente após o PASSO 1.
-- =========================================================

-- Tabela de pagamentos de remuneração (histórico de repasses aos colaboradores)
create table if not exists public.remuneracoes_pagamentos (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id),
  valor_total numeric(10,2) not null,
  observacoes text,
  pago_em timestamptz not null default now(),
  pago_por uuid references auth.users(id)
);

create index if not exists idx_remuneracoes_colaborador on public.remuneracoes_pagamentos(colaborador_id, pago_em);

alter table public.agendamentos
  add column if not exists percentual_comissao numeric(5,2),
  add column if not exists valor_comissao numeric(10,2),
  add column if not exists remuneracao_pagamento_id uuid references public.remuneracoes_pagamentos(id);

create index if not exists idx_agendamentos_remuneracao on public.agendamentos(colaborador_id, remuneracao_pagamento_id);

-- Calcula automaticamente a comissão (percentual e valor) sempre que a comanda é paga.
-- Não recalcula se o atendimento já tiver sido incluído em um pagamento de remuneração.
create or replace function public.calcular_comissao_agendamento()
returns trigger as $$
declare
  v_valor_procedimento numeric(10,2);
  v_percentual numeric(5,2);
begin
  if new.remuneracao_pagamento_id is not null then
    return new;
  end if;
  if new.forma_pagamento is null then
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

drop trigger if exists trg_calcular_comissao on public.agendamentos;
create trigger trg_calcular_comissao
  before insert or update on public.agendamentos
  for each row execute function public.calcular_comissao_agendamento();

-- Registra o pagamento de remuneração de um colaborador e trava os atendimentos incluídos
create or replace function public.registrar_remuneracao(
  p_colaborador_id uuid,
  p_agendamento_ids uuid[],
  p_observacoes text default null
)
returns public.remuneracoes_pagamentos as $$
declare
  v_total numeric(10,2);
  v_pagamento public.remuneracoes_pagamentos;
begin
  if not public.tem_permissao('remuneracao_pagar') then
    raise exception 'Sem permissão para pagar remuneração';
  end if;

  select coalesce(sum(valor_comissao), 0) into v_total
  from public.agendamentos
  where id = any(p_agendamento_ids)
    and colaborador_id = p_colaborador_id
    and remuneracao_pagamento_id is null
    and valor_comissao is not null;

  insert into public.remuneracoes_pagamentos (colaborador_id, valor_total, observacoes, pago_por)
  values (p_colaborador_id, v_total, p_observacoes, auth.uid())
  returning * into v_pagamento;

  update public.agendamentos
  set remuneracao_pagamento_id = v_pagamento.id
  where id = any(p_agendamento_ids)
    and colaborador_id = p_colaborador_id
    and remuneracao_pagamento_id is null;

  return v_pagamento;
end;
$$ language plpgsql security definer;

-- RLS
alter table public.remuneracoes_pagamentos enable row level security;

drop policy if exists remuneracoes_select on public.remuneracoes_pagamentos;
create policy remuneracoes_select on public.remuneracoes_pagamentos for select
  using (public.tem_permissao('remuneracao_visualizar'));

-- Amplia a leitura de agendamentos para quem tem a permissão de remuneração
drop policy if exists agendamentos_select on public.agendamentos;
create policy agendamentos_select on public.agendamentos for select
  using (
    public.tem_permissao('agenda_visualizar') or public.tem_permissao('comanda_visualizar')
    or public.tem_permissao('remuneracao_visualizar')
  );

-- Adiciona as novas permissões (negadas por padrão) para colaboradores já existentes
insert into public.colaborador_permissoes (colaborador_id, permissao, concedida)
select c.id, p.chave, false
from public.colaboradores c
cross join (values ('remuneracao_visualizar'::public.permissao_chave), ('remuneracao_pagar'::public.permissao_chave)) as p(chave)
on conflict (colaborador_id, permissao) do nothing;
