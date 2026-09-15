-- =========================================================
-- MIGRAÇÃO: motivo de cancelamento + forma de pagamento
-- Rode no SQL Editor do Supabase
-- =========================================================

alter table public.agendamentos
  add column if not exists motivo_cancelamento text,
  add column if not exists forma_pagamento text,
  add column if not exists parcelas smallint;

alter table public.agendamentos
  drop constraint if exists agendamentos_forma_pagamento_check;
alter table public.agendamentos
  add constraint agendamentos_forma_pagamento_check
  check (forma_pagamento in ('debito','credito','dinheiro','pix'));

alter table public.agendamentos
  drop constraint if exists agendamentos_parcelas_check;
alter table public.agendamentos
  add constraint agendamentos_parcelas_check
  check (parcelas between 1 and 24);
