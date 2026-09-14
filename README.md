# Sistema de Gestão para Salão — Frontend

Nuxt 3 + Supabase. Fase 1 (Base do Sistema): login, colaboradores, permissões, clientes, procedimentos, categorias.

## Configuração

1. Copie `.env.example` para `.env` e preencha com os dados do seu projeto Supabase.
2. No GitHub, configure os mesmos valores como "Secrets/Variables" do provedor de publicação (Vercel/Netlify) usando os nomes: `SUPABASE_URL`, `SUPABASE_KEY`, `NUXT_PUBLIC_API_BASE`.

## Publicação (GitHub Pages)

1. Suba estes arquivos para um repositório no GitHub.
2. Em Settings → Secrets and variables → Actions, cadastre os secrets: `SUPABASE_URL`, `SUPABASE_KEY`, `NUXT_PUBLIC_API_BASE`.
3. Em Settings → Pages, defina Source como "GitHub Actions".
4. A cada push na branch `main`, o site é gerado e publicado automaticamente (veja `.github/workflows/deploy.yml`).

## Rodando localmente (opcional — não obrigatório para você)

```
npm install
npm run dev
```
