-- =========================================================
-- MIGRAÇÃO: bloqueios de horário + storage de fotos
-- Rode no SQL Editor do Supabase (projeto que já tem Fase 1 + Agendamentos)
-- =========================================================

-- ---------------------------------------------------------
-- Tabela de bloqueios de horário
-- ---------------------------------------------------------
create table if not exists public.bloqueios_horario (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  data_inicio timestamptz not null,
  data_fim timestamptz not null check (data_fim > data_inicio),
  motivo text,
  criado_por uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_bloqueios_colaborador on public.bloqueios_horario(colaborador_id, data_inicio);

alter table public.bloqueios_horario enable row level security;

drop policy if exists bloqueios_select on public.bloqueios_horario;
create policy bloqueios_select on public.bloqueios_horario for select
  using (public.tem_permissao('agenda_visualizar'));

drop policy if exists bloqueios_insert on public.bloqueios_horario;
create policy bloqueios_insert on public.bloqueios_horario for insert
  with check (public.tem_permissao('agenda_editar'));

drop policy if exists bloqueios_delete on public.bloqueios_horario;
create policy bloqueios_delete on public.bloqueios_horario for delete
  using (public.tem_permissao('agenda_editar'));

-- ---------------------------------------------------------
-- Storage: bucket "fotos" (fotos de clientes e colaboradores)
-- ---------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', true)
on conflict (id) do nothing;

drop policy if exists "fotos_select_public" on storage.objects;
create policy "fotos_select_public" on storage.objects for select
  using (bucket_id = 'fotos');

drop policy if exists "fotos_insert_auth" on storage.objects;
create policy "fotos_insert_auth" on storage.objects for insert
  with check (bucket_id = 'fotos' and auth.role() = 'authenticated');

drop policy if exists "fotos_update_auth" on storage.objects;
create policy "fotos_update_auth" on storage.objects for update
  using (bucket_id = 'fotos' and auth.role() = 'authenticated');

drop policy if exists "fotos_delete_auth" on storage.objects;
create policy "fotos_delete_auth" on storage.objects for delete
  using (bucket_id = 'fotos' and auth.role() = 'authenticated');
