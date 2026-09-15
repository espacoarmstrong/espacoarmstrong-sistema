-- =========================================================
-- MIGRAÇÃO: pacotes — PARTE 2 de 2
-- Rode SOMENTE depois que a parte 1 já tiver sido executada com sucesso.
-- =========================================================

-- ---------------------------------------------------------
-- 1. PACOTES (catálogo)
-- ---------------------------------------------------------
create table if not exists public.pacotes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  validade_dias integer not null check (validade_dias > 0),
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_pacotes_updated_at on public.pacotes;
create trigger trg_pacotes_updated_at
  before update on public.pacotes
  for each row execute function set_updated_at();

-- Itens do catálogo: quais procedimentos entram, quantidade e valor de cada um dentro do pacote
create table if not exists public.pacote_itens (
  id uuid primary key default gen_random_uuid(),
  pacote_id uuid not null references public.pacotes(id) on delete cascade,
  procedimento_id uuid not null references public.procedimentos(id),
  quantidade integer not null check (quantidade > 0),
  valor_procedimento numeric(10,2) not null check (valor_procedimento >= 0),
  unique (pacote_id, procedimento_id)
);

-- ---------------------------------------------------------
-- 2. VENDA DO PACOTE (compra vinculada a um cliente)
-- ---------------------------------------------------------
create table if not exists public.pacote_vendas (
  id uuid primary key default gen_random_uuid(),
  pacote_id uuid references public.pacotes(id),
  pacote_nome text not null,
  cliente_id uuid not null references public.clientes(id),
  valor_total numeric(10,2) not null,
  data_compra timestamptz not null default now(),
  data_validade date not null,
  status text not null default 'ativo' check (status in ('ativo', 'cancelado')),
  criado_por uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_pacote_vendas_cliente on public.pacote_vendas(cliente_id);

-- Saldo por procedimento dentro dessa compra específica (não acumula entre compras)
create table if not exists public.pacote_venda_itens (
  id uuid primary key default gen_random_uuid(),
  pacote_venda_id uuid not null references public.pacote_vendas(id) on delete cascade,
  procedimento_id uuid not null references public.procedimentos(id),
  procedimento_nome text not null,
  quantidade_total integer not null check (quantidade_total > 0),
  quantidade_usada integer not null default 0 check (quantidade_usada >= 0),
  valor_procedimento numeric(10,2) not null
);

create index if not exists idx_pacote_venda_itens_venda on public.pacote_venda_itens(pacote_venda_id);
create index if not exists idx_pacote_venda_itens_proc on public.pacote_venda_itens(procedimento_id);

-- Log de cada uso do crédito (auditoria / permite reverter se o agendamento for excluído)
create table if not exists public.pacote_venda_usos (
  id uuid primary key default gen_random_uuid(),
  pacote_venda_item_id uuid not null references public.pacote_venda_itens(id) on delete cascade,
  agendamento_id uuid references public.agendamentos(id),
  usado_em timestamptz not null default now(),
  registrado_por uuid references auth.users(id)
);

-- ---------------------------------------------------------
-- 2.1 AJUSTES DE VALIDADE (reativação manual de um pacote vencido)
-- ---------------------------------------------------------
create table if not exists public.pacote_venda_ajustes (
  id uuid primary key default gen_random_uuid(),
  pacote_venda_id uuid not null references public.pacote_vendas(id) on delete cascade,
  validade_anterior date not null,
  validade_nova date not null,
  observacao text,
  ajustado_por uuid references auth.users(id),
  ajustado_em timestamptz not null default now()
);

create index if not exists idx_pacote_venda_ajustes_venda on public.pacote_venda_ajustes(pacote_venda_id);

-- ---------------------------------------------------------
-- 3. LIGAÇÃO COM AGENDAMENTOS
-- ---------------------------------------------------------
alter table public.agendamentos add column if not exists pacote_venda_item_id uuid references public.pacote_venda_itens(id);

alter table public.agendamentos drop constraint if exists agendamentos_forma_pagamento_check;
alter table public.agendamentos add constraint agendamentos_forma_pagamento_check
  check (forma_pagamento in ('debito', 'credito', 'dinheiro', 'pix', 'pacote'));

-- ---------------------------------------------------------
-- 4. COMISSÃO: usa o valor cadastrado no pacote quando pago com crédito
-- ---------------------------------------------------------
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

  if new.pacote_venda_item_id is not null then
    select valor_procedimento into v_valor_procedimento
    from public.pacote_venda_itens where id = new.pacote_venda_item_id;
  else
    select valor into v_valor_procedimento from public.procedimentos where id = new.procedimento_id;
  end if;

  select percentual into v_percentual from public.colaborador_comissoes
    where colaborador_id = new.colaborador_id and procedimento_id = new.procedimento_id;
  v_percentual := coalesce(v_percentual, 0);
  new.percentual_comissao := v_percentual;
  new.valor_comissao := round((coalesce(v_valor_procedimento,0) - coalesce(new.valor_desconto,0)) * v_percentual / 100, 2);
  return new;
end;
$$ language plpgsql security definer;

-- ---------------------------------------------------------
-- 5. FUNÇÃO: usar 1 crédito do pacote para pagar um agendamento
-- Escolhe automaticamente o pacote mais antigo com saldo (FIFO),
-- a menos que um pacote_venda_item específico seja informado.
-- ---------------------------------------------------------
create or replace function public.registrar_pagamento_pacote(
  p_agendamento_id uuid,
  p_pacote_venda_item_id uuid default null
)
returns public.agendamentos as $$
declare
  v_agendamento public.agendamentos;
  v_item_id uuid;
begin
  if not public.tem_permissao('comanda_registrar_pagamento') then
    raise exception 'Sem permissão para registrar pagamento';
  end if;

  select * into v_agendamento from public.agendamentos where id = p_agendamento_id;
  if v_agendamento is null then
    raise exception 'Agendamento não encontrado';
  end if;

  if p_pacote_venda_item_id is not null then
    v_item_id := p_pacote_venda_item_id;
  else
    select pvi.id into v_item_id
    from public.pacote_venda_itens pvi
    join public.pacote_vendas pv on pv.id = pvi.pacote_venda_id
    where pv.cliente_id = v_agendamento.cliente_id
      and pvi.procedimento_id = v_agendamento.procedimento_id
      and pv.status = 'ativo'
      and pv.data_validade >= current_date
      and pvi.quantidade_usada < pvi.quantidade_total
    order by pv.data_compra asc
    limit 1;
  end if;

  if v_item_id is null then
    raise exception 'Nenhum saldo de pacote disponível para este procedimento';
  end if;

  update public.pacote_venda_itens
    set quantidade_usada = quantidade_usada + 1
    where id = v_item_id and quantidade_usada < quantidade_total;

  if not found then
    raise exception 'Saldo do pacote esgotado';
  end if;

  insert into public.pacote_venda_usos (pacote_venda_item_id, agendamento_id, registrado_por)
  values (v_item_id, p_agendamento_id, auth.uid());

  delete from public.pagamentos_comanda where agendamento_id = p_agendamento_id;

  update public.agendamentos
  set pago = true,
      forma_pagamento = 'pacote',
      parcelas = null,
      valor_desconto = 0,
      pacote_venda_item_id = v_item_id,
      data_pagamento = coalesce(data_pagamento, now())
  where id = p_agendamento_id
  returning * into v_agendamento;

  return v_agendamento;
end;
$$ language plpgsql security definer;

-- ---------------------------------------------------------
-- 6. Reverter crédito se o agendamento for excluído
-- ---------------------------------------------------------
create or replace function public.reverter_uso_pacote()
returns trigger as $$
begin
  if old.pacote_venda_item_id is not null then
    update public.pacote_venda_itens
      set quantidade_usada = greatest(0, quantidade_usada - 1)
      where id = old.pacote_venda_item_id;
    delete from public.pacote_venda_usos where agendamento_id = old.id;
  end if;
  return old;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_reverter_uso_pacote on public.agendamentos;
create trigger trg_reverter_uso_pacote
  after delete on public.agendamentos
  for each row execute function public.reverter_uso_pacote();

-- ---------------------------------------------------------
-- 7. FUNÇÃO: reativar / estender validade de um pacote (ação manual do admin)
-- Não é automático em nenhuma hipótese — só roda quando o admin aciona.
-- ---------------------------------------------------------
create or replace function public.estender_validade_pacote(
  p_pacote_venda_id uuid,
  p_nova_validade date,
  p_observacao text default null
)
returns public.pacote_vendas as $$
declare
  v_venda public.pacote_vendas;
  v_validade_anterior date;
  v_status text;
begin
  if not public.is_admin() then
    raise exception 'Apenas admin pode reativar/estender a validade de um pacote.';
  end if;

  select data_validade, status into v_validade_anterior, v_status
  from public.pacote_vendas where id = p_pacote_venda_id;

  if v_validade_anterior is null then
    raise exception 'Venda de pacote não encontrada';
  end if;
  if v_status = 'cancelado' then
    raise exception 'Um pacote cancelado não pode ser reativado.';
  end if;
  if p_nova_validade <= current_date then
    raise exception 'A nova validade deve ser uma data futura';
  end if;

  insert into public.pacote_venda_ajustes (pacote_venda_id, validade_anterior, validade_nova, observacao, ajustado_por)
  values (p_pacote_venda_id, v_validade_anterior, p_nova_validade, p_observacao, auth.uid());

  update public.pacote_vendas
    set data_validade = p_nova_validade
    where id = p_pacote_venda_id
    returning * into v_venda;

  return v_venda;
end;
$$ language plpgsql security definer;

-- ---------------------------------------------------------
-- 8. RLS
-- ---------------------------------------------------------
alter table public.pacotes enable row level security;
alter table public.pacote_itens enable row level security;
alter table public.pacote_vendas enable row level security;
alter table public.pacote_venda_itens enable row level security;
alter table public.pacote_venda_usos enable row level security;
alter table public.pacote_venda_ajustes enable row level security;

drop policy if exists pacotes_select on public.pacotes;
create policy pacotes_select on public.pacotes for select
  using (public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender'));
drop policy if exists pacotes_admin on public.pacotes;
create policy pacotes_admin on public.pacotes for all
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists pacote_itens_select on public.pacote_itens;
create policy pacote_itens_select on public.pacote_itens for select
  using (public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender'));
drop policy if exists pacote_itens_admin on public.pacote_itens;
create policy pacote_itens_admin on public.pacote_itens for all
  using (public.is_admin()) with check (public.is_admin());

-- leitura de vendas/saldos também liberada para quem registra pagamento de comanda,
-- pois é ele quem precisa ver se o cliente tem crédito disponível na hora de pagar
drop policy if exists pacote_vendas_select on public.pacote_vendas;
create policy pacote_vendas_select on public.pacote_vendas for select
  using (
    public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender')
    or public.tem_permissao('comanda_registrar_pagamento')
  );
drop policy if exists pacote_vendas_insert on public.pacote_vendas;
create policy pacote_vendas_insert on public.pacote_vendas for insert
  with check (public.tem_permissao('pacotes_vender'));
drop policy if exists pacote_vendas_admin on public.pacote_vendas;
create policy pacote_vendas_admin on public.pacote_vendas for all
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists pacote_venda_itens_select on public.pacote_venda_itens;
create policy pacote_venda_itens_select on public.pacote_venda_itens for select
  using (
    public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender')
    or public.tem_permissao('comanda_registrar_pagamento')
  );
drop policy if exists pacote_venda_itens_insert on public.pacote_venda_itens;
create policy pacote_venda_itens_insert on public.pacote_venda_itens for insert
  with check (public.tem_permissao('pacotes_vender'));
drop policy if exists pacote_venda_itens_admin on public.pacote_venda_itens;
create policy pacote_venda_itens_admin on public.pacote_venda_itens for all
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists pacote_venda_usos_select on public.pacote_venda_usos;
create policy pacote_venda_usos_select on public.pacote_venda_usos for select
  using (public.tem_permissao('pacotes_visualizar'));

drop policy if exists pacote_venda_ajustes_select on public.pacote_venda_ajustes;
create policy pacote_venda_ajustes_select on public.pacote_venda_ajustes for select
  using (public.tem_permissao('pacotes_visualizar'));
