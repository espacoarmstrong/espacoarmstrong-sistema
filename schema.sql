-- =========================================================
-- SISTEMA DE GESTÃO PARA SALÃO — FASE 1: BASE DO SISTEMA
-- Auth, Colaboradores, Permissões, Clientes, Procedimentos, Categorias
-- =========================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------
-- FUNÇÃO AUXILIAR: updated_at automático
-- ---------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- =========================================================
-- 1. USUÁRIOS (vínculo com auth.users do Supabase)
-- =========================================================
create table public.usuarios (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  role text not null check (role in ('admin', 'colaborador')),
  colaborador_id uuid, -- preenchido após criar o colaborador (FK adicionada abaixo)
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_usuarios_updated_at
  before update on public.usuarios
  for each row execute function set_updated_at();

-- =========================================================
-- 2. CATEGORIAS
-- =========================================================
create table public.categorias (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_categorias_updated_at
  before update on public.categorias
  for each row execute function set_updated_at();

-- =========================================================
-- 3. PROCEDIMENTOS
-- =========================================================
create table public.procedimentos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  categoria_id uuid not null references public.categorias(id),
  descricao text,
  duracao_minutos integer not null check (duracao_minutos > 0),
  valor numeric(10,2) not null check (valor >= 0),
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_procedimentos_categoria on public.procedimentos(categoria_id);

create trigger trg_procedimentos_updated_at
  before update on public.procedimentos
  for each row execute function set_updated_at();

-- =========================================================
-- 4. COLABORADORES
-- =========================================================
create table public.colaboradores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  nome text not null,
  telefone text,
  foto_url text,
  cargo text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.usuarios
  add constraint fk_usuarios_colaborador
  foreign key (colaborador_id) references public.colaboradores(id) on delete set null;

create trigger trg_colaboradores_updated_at
  before update on public.colaboradores
  for each row execute function set_updated_at();

-- ---------------------------------------------------------
-- 4.1 Procedimentos que cada colaborador realiza (N:N)
-- ---------------------------------------------------------
create table public.colaborador_procedimentos (
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  procedimento_id uuid not null references public.procedimentos(id) on delete cascade,
  primary key (colaborador_id, procedimento_id)
);

-- ---------------------------------------------------------
-- 4.2 Horário de trabalho / folgas por dia da semana
-- dia_semana: 0=domingo ... 6=sábado
-- ---------------------------------------------------------
create table public.colaborador_horarios (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  dia_semana smallint not null check (dia_semana between 0 and 6),
  folga boolean not null default false,
  horario_inicio time,
  horario_fim time,
  unique (colaborador_id, dia_semana)
);

-- ---------------------------------------------------------
-- 4.3 Comissão vigente por colaborador + procedimento
-- (histórico real é preservado depois, na fase de Remunerações)
-- ---------------------------------------------------------
create table public.colaborador_comissoes (
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  procedimento_id uuid not null references public.procedimentos(id) on delete cascade,
  percentual numeric(5,2) not null check (percentual >= 0 and percentual <= 100),
  updated_at timestamptz not null default now(),
  primary key (colaborador_id, procedimento_id)
);

-- =========================================================
-- 5. PERMISSÕES DOS COLABORADORES
-- =========================================================
create type public.permissao_chave as enum (
  'agenda_visualizar', 'agenda_criar', 'agenda_editar', 'agenda_cancelar',
  'clientes_visualizar', 'clientes_criar', 'clientes_editar', 'clientes_excluir',
  'comanda_visualizar', 'comanda_finalizar', 'comanda_registrar_pagamento', 'comanda_aplicar_desconto',
  'procedimentos_visualizar', 'colaboradores_visualizar', 'dashboard_visualizar',
  'remuneracao_visualizar', 'remuneracao_pagar',
  'pacotes_visualizar', 'pacotes_vender'
);

create table public.colaborador_permissoes (
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  permissao public.permissao_chave not null,
  concedida boolean not null default false,
  primary key (colaborador_id, permissao)
);

-- =========================================================
-- 6. CLIENTES
-- =========================================================
create table public.clientes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  telefone text,
  foto_url text,
  observacoes text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_clientes_nome on public.clientes using gin (to_tsvector('portuguese', nome));

create trigger trg_clientes_updated_at
  before update on public.clientes
  for each row execute function set_updated_at();

-- =========================================================
-- 6.5 REMUNERAÇÃO (pagamentos de comissão aos colaboradores)
-- =========================================================
create table public.remuneracoes_pagamentos (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id),
  valor_total numeric(10,2) not null,
  observacoes text,
  pago_em timestamptz not null default now(),
  pago_por uuid references auth.users(id)
);

create index idx_remuneracoes_colaborador on public.remuneracoes_pagamentos(colaborador_id, pago_em);

-- =========================================================
-- 7. AGENDAMENTOS
-- =========================================================
create table public.agendamentos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clientes(id),
  colaborador_id uuid not null references public.colaboradores(id),
  procedimento_id uuid not null references public.procedimentos(id),
  data_hora timestamptz not null,
  status text not null default 'agendado' check (status in ('agendado','confirmado','concluido','cancelado')),
  observacoes text,
  motivo_cancelamento text,
  forma_pagamento text check (forma_pagamento in ('debito','credito','dinheiro','pix')),
  parcelas smallint check (parcelas between 1 and 24),
  valor_desconto numeric(10,2) not null default 0 check (valor_desconto >= 0),
  data_pagamento timestamptz,
  pago boolean not null default false,
  percentual_comissao numeric(5,2),
  valor_comissao numeric(10,2),
  remuneracao_pagamento_id uuid references public.remuneracoes_pagamentos(id),
  criado_por uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_agendamentos_colaborador on public.agendamentos(colaborador_id, data_hora);
create index idx_agendamentos_data on public.agendamentos(data_hora);
create index idx_agendamentos_remuneracao on public.agendamentos(colaborador_id, remuneracao_pagamento_id);

-- Detalhamento das formas de pagamento de uma comanda (permite combinar mais de uma forma)
create table public.pagamentos_comanda (
  id uuid primary key default gen_random_uuid(),
  agendamento_id uuid not null references public.agendamentos(id) on delete cascade,
  forma_pagamento text not null check (forma_pagamento in ('debito','credito','dinheiro','pix')),
  valor numeric(10,2) not null check (valor > 0),
  parcelas smallint check (parcelas between 1 and 24),
  created_at timestamptz not null default now()
);

create index idx_pagamentos_comanda_agendamento on public.pagamentos_comanda(agendamento_id);

create trigger trg_agendamentos_updated_at
  before update on public.agendamentos
  for each row execute function set_updated_at();

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

create trigger trg_calcular_comissao
  before insert or update on public.agendamentos
  for each row execute function public.calcular_comissao_agendamento();

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

-- =========================================================
-- 7.1 BLOQUEIOS DE HORÁRIO (folgas pontuais, almoço, etc.)
-- =========================================================
create table public.bloqueios_horario (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  data_inicio timestamptz not null,
  data_fim timestamptz not null check (data_fim > data_inicio),
  motivo text,
  criado_por uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index idx_bloqueios_colaborador on public.bloqueios_horario(colaborador_id, data_inicio);

-- =========================================================
-- 8. PACOTES DE PROCEDIMENTOS (crédito pré-pago do cliente)
-- =========================================================
create table public.pacotes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  validade_dias integer not null check (validade_dias > 0),
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_pacotes_updated_at
  before update on public.pacotes
  for each row execute function set_updated_at();

-- Itens do catálogo: quais procedimentos entram, quantidade e valor de cada um dentro do pacote
create table public.pacote_itens (
  id uuid primary key default gen_random_uuid(),
  pacote_id uuid not null references public.pacotes(id) on delete cascade,
  procedimento_id uuid not null references public.procedimentos(id),
  quantidade integer not null check (quantidade > 0),
  valor_procedimento numeric(10,2) not null check (valor_procedimento >= 0),
  unique (pacote_id, procedimento_id)
);

-- ---------------------------------------------------------
-- 8.1 VENDA DO PACOTE (compra vinculada a um cliente)
-- ---------------------------------------------------------
create table public.pacote_vendas (
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

create index idx_pacote_vendas_cliente on public.pacote_vendas(cliente_id);

-- Saldo por procedimento dentro dessa compra específica (não acumula entre compras)
create table public.pacote_venda_itens (
  id uuid primary key default gen_random_uuid(),
  pacote_venda_id uuid not null references public.pacote_vendas(id) on delete cascade,
  procedimento_id uuid not null references public.procedimentos(id),
  procedimento_nome text not null,
  quantidade_total integer not null check (quantidade_total > 0),
  quantidade_usada integer not null default 0 check (quantidade_usada >= 0),
  valor_procedimento numeric(10,2) not null
);

create index idx_pacote_venda_itens_venda on public.pacote_venda_itens(pacote_venda_id);
create index idx_pacote_venda_itens_proc on public.pacote_venda_itens(procedimento_id);

-- Log de cada uso do crédito (auditoria / permite reverter se o agendamento for excluído)
create table public.pacote_venda_usos (
  id uuid primary key default gen_random_uuid(),
  pacote_venda_item_id uuid not null references public.pacote_venda_itens(id) on delete cascade,
  agendamento_id uuid references public.agendamentos(id),
  usado_em timestamptz not null default now(),
  registrado_por uuid references auth.users(id)
);

-- ---------------------------------------------------------
-- 8.2 AJUSTES DE VALIDADE (reativação manual de um pacote vencido)
-- ---------------------------------------------------------
create table public.pacote_venda_ajustes (
  id uuid primary key default gen_random_uuid(),
  pacote_venda_id uuid not null references public.pacote_vendas(id) on delete cascade,
  validade_anterior date not null,
  validade_nova date not null,
  observacao text,
  ajustado_por uuid references auth.users(id),
  ajustado_em timestamptz not null default now()
);

create index idx_pacote_venda_ajustes_venda on public.pacote_venda_ajustes(pacote_venda_id);

-- ---------------------------------------------------------
-- 8.3 Ligação com agendamentos + pagamento via crédito do pacote
-- ---------------------------------------------------------
alter table public.agendamentos add column pacote_venda_item_id uuid references public.pacote_venda_itens(id);

alter table public.agendamentos drop constraint agendamentos_forma_pagamento_check;
alter table public.agendamentos add constraint agendamentos_forma_pagamento_check
  check (forma_pagamento in ('debito', 'credito', 'dinheiro', 'pix', 'pacote'));

-- Recalcula a comissão usando o valor do pacote quando o pagamento foi feito com crédito
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

-- Usa 1 crédito do pacote para pagar um agendamento (FIFO: pacote mais antigo com saldo)
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

-- Reverte o crédito do pacote se o agendamento for excluído
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

create trigger trg_reverter_uso_pacote
  after delete on public.agendamentos
  for each row execute function public.reverter_uso_pacote();

-- Reativar / estender validade de um pacote vencido — sempre uma ação manual do admin
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

-- =========================================================
-- STORAGE: bucket "fotos" (fotos de clientes e colaboradores)
-- =========================================================
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', true)
on conflict (id) do nothing;

create policy "fotos_select_public" on storage.objects for select
  using (bucket_id = 'fotos');
create policy "fotos_insert_auth" on storage.objects for insert
  with check (bucket_id = 'fotos' and auth.role() = 'authenticated');
create policy "fotos_update_auth" on storage.objects for update
  using (bucket_id = 'fotos' and auth.role() = 'authenticated');
create policy "fotos_delete_auth" on storage.objects for delete
  using (bucket_id = 'fotos' and auth.role() = 'authenticated');

-- =========================================================
-- FUNÇÕES AUXILIARES DE PERMISSÃO (usadas nas policies)
-- =========================================================
create or replace function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from public.usuarios
    where id = auth.uid() and role = 'admin' and ativo = true
  );
$$ language sql stable security definer;

create or replace function public.colaborador_atual_id()
returns uuid as $$
  select colaborador_id from public.usuarios where id = auth.uid();
$$ language sql stable security definer;

create or replace function public.tem_permissao(chave public.permissao_chave)
returns boolean as $$
  select public.is_admin() or exists (
    select 1 from public.colaborador_permissoes
    where colaborador_id = public.colaborador_atual_id()
      and permissao = chave
      and concedida = true
  );
$$ language sql stable security definer;

-- =========================================================
-- RLS
-- =========================================================
alter table public.usuarios enable row level security;
alter table public.categorias enable row level security;
alter table public.procedimentos enable row level security;
alter table public.colaboradores enable row level security;
alter table public.colaborador_procedimentos enable row level security;
alter table public.colaborador_horarios enable row level security;
alter table public.colaborador_comissoes enable row level security;
alter table public.colaborador_permissoes enable row level security;
alter table public.clientes enable row level security;
alter table public.agendamentos enable row level security;
alter table public.bloqueios_horario enable row level security;

-- USUÁRIOS: cada um vê o próprio registro; admin vê todos
create policy usuarios_select on public.usuarios for select
  using (id = auth.uid() or public.is_admin());
create policy usuarios_admin_all on public.usuarios for all
  using (public.is_admin()) with check (public.is_admin());

-- CATEGORIAS: leitura para autenticados; escrita só admin
create policy categorias_select on public.categorias for select
  using (auth.role() = 'authenticated');
create policy categorias_admin_write on public.categorias for insert
  with check (public.is_admin());
create policy categorias_admin_update on public.categorias for update
  using (public.is_admin());
create policy categorias_admin_delete on public.categorias for delete
  using (public.is_admin());

-- PROCEDIMENTOS
create policy procedimentos_select on public.procedimentos for select
  using (public.tem_permissao('procedimentos_visualizar'));
create policy procedimentos_admin_write on public.procedimentos for insert
  with check (public.is_admin());
create policy procedimentos_admin_update on public.procedimentos for update
  using (public.is_admin());
create policy procedimentos_admin_delete on public.procedimentos for delete
  using (public.is_admin());

-- COLABORADORES
create policy colaboradores_select on public.colaboradores for select
  using (public.tem_permissao('colaboradores_visualizar'));
create policy colaboradores_admin_write on public.colaboradores for insert
  with check (public.is_admin());
create policy colaboradores_admin_update on public.colaboradores for update
  using (public.is_admin());
create policy colaboradores_admin_delete on public.colaboradores for delete
  using (public.is_admin());

-- RELAÇÕES DE COLABORADOR (procedimentos/horários/comissões/permissões): leitura ampla, escrita só admin
create policy colab_proc_select on public.colaborador_procedimentos for select using (auth.role() = 'authenticated');
create policy colab_proc_admin on public.colaborador_procedimentos for all using (public.is_admin()) with check (public.is_admin());

create policy colab_hor_select on public.colaborador_horarios for select using (auth.role() = 'authenticated');
create policy colab_hor_admin on public.colaborador_horarios for all using (public.is_admin()) with check (public.is_admin());

create policy colab_com_select on public.colaborador_comissoes for select using (public.is_admin());
create policy colab_com_admin on public.colaborador_comissoes for all using (public.is_admin()) with check (public.is_admin());

create policy colab_perm_select on public.colaborador_permissoes for select
  using (colaborador_id = public.colaborador_atual_id() or public.is_admin());
create policy colab_perm_admin on public.colaborador_permissoes for all
  using (public.is_admin()) with check (public.is_admin());

-- CLIENTES
create policy clientes_select on public.clientes for select
  using (public.tem_permissao('clientes_visualizar'));
create policy clientes_insert on public.clientes for insert
  with check (public.tem_permissao('clientes_criar'));
create policy clientes_update on public.clientes for update
  using (public.tem_permissao('clientes_editar'));
create policy clientes_delete on public.clientes for delete
  using (public.tem_permissao('clientes_excluir'));

-- REMUNERAÇÃO (inserts/updates só acontecem via função registrar_remuneracao, security definer)
alter table public.remuneracoes_pagamentos enable row level security;
create policy remuneracoes_select on public.remuneracoes_pagamentos for select
  using (public.tem_permissao('remuneracao_visualizar'));

-- AGENDAMENTOS (admin sempre tem acesso; colaborador precisa da permissão concedida)
create policy agendamentos_select on public.agendamentos for select
  using (
    public.tem_permissao('agenda_visualizar') or public.tem_permissao('comanda_visualizar')
    or public.tem_permissao('remuneracao_visualizar')
  );
create policy agendamentos_insert on public.agendamentos for insert
  with check (public.tem_permissao('agenda_criar'));
create policy agendamentos_update on public.agendamentos for update
  using (
    public.tem_permissao('agenda_editar') or public.tem_permissao('agenda_cancelar')
    or public.tem_permissao('comanda_finalizar') or public.tem_permissao('comanda_registrar_pagamento')
    or public.tem_permissao('comanda_aplicar_desconto')
  );
create policy agendamentos_delete on public.agendamentos for delete
  using (public.is_admin());

-- PAGAMENTOS DA COMANDA (inserts/updates/deletes só acontecem via função registrar_pagamento_comanda)
alter table public.pagamentos_comanda enable row level security;
create policy pagamentos_comanda_select on public.pagamentos_comanda for select
  using (public.tem_permissao('comanda_visualizar'));

-- BLOQUEIOS DE HORÁRIO
create policy bloqueios_select on public.bloqueios_horario for select
  using (public.tem_permissao('agenda_visualizar'));
create policy bloqueios_insert on public.bloqueios_horario for insert
  with check (public.tem_permissao('agenda_editar'));
create policy bloqueios_delete on public.bloqueios_horario for delete
  using (public.tem_permissao('agenda_editar'));

-- PACOTES (catálogo: leitura ampla, escrita só admin)
alter table public.pacotes enable row level security;
alter table public.pacote_itens enable row level security;
alter table public.pacote_vendas enable row level security;
alter table public.pacote_venda_itens enable row level security;
alter table public.pacote_venda_usos enable row level security;
alter table public.pacote_venda_ajustes enable row level security;

create policy pacotes_select on public.pacotes for select
  using (public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender'));
create policy pacotes_admin on public.pacotes for all
  using (public.is_admin()) with check (public.is_admin());

create policy pacote_itens_select on public.pacote_itens for select
  using (public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender'));
create policy pacote_itens_admin on public.pacote_itens for all
  using (public.is_admin()) with check (public.is_admin());

-- leitura de vendas/saldos também liberada para quem registra pagamento de comanda,
-- pois é ele quem precisa ver se o cliente tem crédito disponível na hora de pagar
create policy pacote_vendas_select on public.pacote_vendas for select
  using (
    public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender')
    or public.tem_permissao('comanda_registrar_pagamento')
  );
create policy pacote_vendas_insert on public.pacote_vendas for insert
  with check (public.tem_permissao('pacotes_vender'));
create policy pacote_vendas_admin on public.pacote_vendas for all
  using (public.is_admin()) with check (public.is_admin());

create policy pacote_venda_itens_select on public.pacote_venda_itens for select
  using (
    public.tem_permissao('pacotes_visualizar') or public.tem_permissao('pacotes_vender')
    or public.tem_permissao('comanda_registrar_pagamento')
  );
create policy pacote_venda_itens_insert on public.pacote_venda_itens for insert
  with check (public.tem_permissao('pacotes_vender'));
create policy pacote_venda_itens_admin on public.pacote_venda_itens for all
  using (public.is_admin()) with check (public.is_admin());

create policy pacote_venda_usos_select on public.pacote_venda_usos for select
  using (public.tem_permissao('pacotes_visualizar'));

create policy pacote_venda_ajustes_select on public.pacote_venda_ajustes for select
  using (public.tem_permissao('pacotes_visualizar'));
