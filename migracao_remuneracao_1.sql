-- =========================================================
-- MIGRAÇÃO: Remuneração — PASSO 1 de 2
-- Rode este bloco sozinho no SQL Editor do Supabase.
-- Só rode o PASSO 2 depois deste ter concluído com sucesso.
-- =========================================================

alter type public.permissao_chave add value if not exists 'remuneracao_visualizar';
alter type public.permissao_chave add value if not exists 'remuneracao_pagar';
