-- =========================================================
-- MIGRAÇÃO: pacotes — PARTE 1 de 2
-- Rode este bloco PRIMEIRO e sozinho (adicionar valores a um enum
-- exige commit antes de poder usá-los nas políticas da parte 2).
-- =========================================================

alter type public.permissao_chave add value if not exists 'pacotes_visualizar';
alter type public.permissao_chave add value if not exists 'pacotes_vender';
