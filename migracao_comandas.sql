-- =========================================================
-- MIGRAÇÃO: Comandas (aberta/paga, desconto, data de pagamento)
-- Rode no SQL Editor do Supabase
-- =========================================================

alter table public.agendamentos
  add column if not exists valor_desconto numeric(10,2) not null default 0,
  add column if not exists data_pagamento timestamptz;

alter table public.agendamentos
  drop constraint if exists agendamentos_valor_desconto_check;
alter table public.agendamentos
  add constraint agendamentos_valor_desconto_check
  check (valor_desconto >= 0);

drop policy if exists agendamentos_select on public.agendamentos;
create policy agendamentos_select on public.agendamentos for select
  using (public.tem_permissao('agenda_visualizar') or public.tem_permissao('comanda_visualizar'));

drop policy if exists agendamentos_update on public.agendamentos;
create policy agendamentos_update on public.agendamentos for update
  using (
    public.tem_permissao('agenda_editar') or public.tem_permissao('agenda_cancelar')
    or public.tem_permissao('comanda_finalizar') or public.tem_permissao('comanda_registrar_pagamento')
    or public.tem_permissao('comanda_aplicar_desconto')
  );
