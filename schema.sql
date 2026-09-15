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
  'procedimentos_visualizar', 'colaboradores_visualizar', 'dashboard_visualizar'
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
  criado_por uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_agendamentos_colaborador on public.agendamentos(colaborador_id, data_hora);
create index idx_agendamentos_data on public.agendamentos(data_hora);

create trigger trg_agendamentos_updated_at
  before update on public.agendamentos
  for each row execute function set_updated_at();

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

-- AGENDAMENTOS (admin sempre tem acesso; colaborador precisa da permissão concedida)
create policy agendamentos_select on public.agendamentos for select
  using (public.tem_permissao('agenda_visualizar'));
create policy agendamentos_insert on public.agendamentos for insert
  with check (public.tem_permissao('agenda_criar'));
create policy agendamentos_update on public.agendamentos for update
  using (public.tem_permissao('agenda_editar') or public.tem_permissao('agenda_cancelar'));
create policy agendamentos_delete on public.agendamentos for delete
  using (public.is_admin());

-- BLOQUEIOS DE HORÁRIO
create policy bloqueios_select on public.bloqueios_horario for select
  using (public.tem_permissao('agenda_visualizar'));
create policy bloqueios_insert on public.bloqueios_horario for insert
  with check (public.tem_permissao('agenda_editar'));
create policy bloqueios_delete on public.bloqueios_horario for delete
  using (public.tem_permissao('agenda_editar'));
