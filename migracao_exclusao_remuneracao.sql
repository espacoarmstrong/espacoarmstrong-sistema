-- =========================================================
-- MIGRAÇÃO: admin pode excluir pagamento de remuneração
-- Rode este script uma vez no SQL Editor do Supabase.
-- (Exclusão de venda de pacote e de pacote do catálogo já eram
-- permitidas ao admin pelas policies existentes — nenhuma mudança
-- de banco foi necessária para esses dois.)
-- =========================================================

-- ao excluir um pagamento, os atendimentos que estavam ligados a ele
-- voltam a ficar pendentes (remuneracao_pagamento_id = null) em vez
-- de bloquear a exclusão.
alter table public.agendamentos
  drop constraint if exists agendamentos_remuneracao_pagamento_id_fkey,
  add constraint agendamentos_remuneracao_pagamento_id_fkey
    foreign key (remuneracao_pagamento_id) references public.remuneracoes_pagamentos(id)
    on delete set null;

create policy remuneracoes_delete on public.remuneracoes_pagamentos for delete
  using (public.is_admin());
