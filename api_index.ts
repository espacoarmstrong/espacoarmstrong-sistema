// =========================================================
// EDGE FUNCTION: api
// Fase 1 — Base do Sistema
// Usada para operações que exigem privilégio de administrador
// (criar login de colaborador, gerenciar permissões/comissões/horários).
// Leituras e CRUD simples de clientes/procedimentos/categorias são
// feitos direto pelo frontend via supabase-js, protegidos por RLS.
// =========================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getRequester(req: Request) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) return null;

  const { data: userData, error } = await admin.auth.getUser(token);
  if (error || !userData?.user) return null;

  const { data: usuario } = await admin
    .from("usuarios")
    .select("id, role, colaborador_id, ativo")
    .eq("id", userData.user.id)
    .single();

  if (!usuario || !usuario.ativo) return null;
  return usuario;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
        "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      },
    });
  }

  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/api/, "");
  const requester = await getRequester(req);

  if (!requester) return json({ error: "Não autenticado" }, 401);

  // ---------------------------------------------------
  // POST /colaboradores  — cria colaborador + login (admin)
  // body: { nome, telefone, cargo, email, senha }
  // ---------------------------------------------------
  if (path === "/colaboradores" && req.method === "POST") {
    if (requester.role !== "admin") return json({ error: "Apenas admin" }, 403);
    const body = await req.json();
    const { nome, telefone, cargo, email, senha } = body;

    if (!nome || !email || !senha) {
      return json({ error: "nome, email e senha são obrigatórios" }, 400);
    }

    const { data: authUser, error: authError } = await admin.auth.admin.createUser({
      email,
      password: senha,
      email_confirm: true,
    });
    if (authError) return json({ error: authError.message }, 400);

    const { data: colaborador, error: colabError } = await admin
      .from("colaboradores")
      .insert({ nome, telefone, cargo, user_id: authUser.user.id })
      .select()
      .single();
    if (colabError) return json({ error: colabError.message }, 400);

    const { error: usuarioError } = await admin.from("usuarios").insert({
      id: authUser.user.id,
      nome,
      role: "colaborador",
      colaborador_id: colaborador.id,
    });
    if (usuarioError) return json({ error: usuarioError.message }, 400);

    // cria linhas de permissão padrão (tudo negado) para o colaborador
    const chaves = [
      "agenda_visualizar", "agenda_criar", "agenda_editar", "agenda_cancelar",
      "clientes_visualizar", "clientes_criar", "clientes_editar", "clientes_excluir",
      "comanda_visualizar", "comanda_finalizar", "comanda_registrar_pagamento", "comanda_aplicar_desconto",
      "procedimentos_visualizar", "colaboradores_visualizar", "dashboard_visualizar",
    ];
    await admin.from("colaborador_permissoes").insert(
      chaves.map((permissao) => ({ colaborador_id: colaborador.id, permissao, concedida: false }))
    );

    return json({ colaborador });
  }

  // ---------------------------------------------------
  // PUT /colaboradores/:id/permissoes — admin
  // body: { permissoes: [{ permissao, concedida }, ...] }
  // ---------------------------------------------------
  const permMatch = path.match(/^\/colaboradores\/([0-9a-fA-F-]+)\/permissoes$/);
  if (permMatch && req.method === "PUT") {
    if (requester.role !== "admin") return json({ error: "Apenas admin" }, 403);
    const colaboradorId = permMatch[1];
    const { permissoes } = await req.json();

    for (const p of permissoes) {
      const { error } = await admin
        .from("colaborador_permissoes")
        .upsert({ colaborador_id: colaboradorId, permissao: p.permissao, concedida: p.concedida });
      if (error) return json({ error: error.message }, 400);
    }
    return json({ ok: true });
  }

  // ---------------------------------------------------
  // PUT /colaboradores/:id/horarios — admin
  // body: { horarios: [{ dia_semana, folga, horario_inicio, horario_fim }, ...] }
  // ---------------------------------------------------
  const horMatch = path.match(/^\/colaboradores\/([0-9a-fA-F-]+)\/horarios$/);
  if (horMatch && req.method === "PUT") {
    if (requester.role !== "admin") return json({ error: "Apenas admin" }, 403);
    const colaboradorId = horMatch[1];
    const { horarios } = await req.json();

    for (const h of horarios) {
      const { error } = await admin.from("colaborador_horarios").upsert({
        colaborador_id: colaboradorId,
        dia_semana: h.dia_semana,
        folga: h.folga,
        horario_inicio: h.folga ? null : h.horario_inicio,
        horario_fim: h.folga ? null : h.horario_fim,
      }, { onConflict: "colaborador_id,dia_semana" });
      if (error) return json({ error: error.message }, 400);
    }
    return json({ ok: true });
  }

  // ---------------------------------------------------
  // PUT /colaboradores/:id/comissoes — admin
  // body: { comissoes: [{ procedimento_id, percentual }, ...] }
  // ---------------------------------------------------
  const comMatch = path.match(/^\/colaboradores\/([0-9a-fA-F-]+)\/comissoes$/);
  if (comMatch && req.method === "PUT") {
    if (requester.role !== "admin") return json({ error: "Apenas admin" }, 403);
    const colaboradorId = comMatch[1];
    const { comissoes } = await req.json();

    for (const c of comissoes) {
      const { error } = await admin.from("colaborador_comissoes").upsert({
        colaborador_id: colaboradorId,
        procedimento_id: c.procedimento_id,
        percentual: c.percentual,
        updated_at: new Date().toISOString(),
      }, { onConflict: "colaborador_id,procedimento_id" });
      if (error) return json({ error: error.message }, 400);
    }
    return json({ ok: true });
  }

  // ---------------------------------------------------
  // PUT /colaboradores/:id/senha — admin (redefinir senha de acesso)
  // body: { senha }
  // ---------------------------------------------------
  const senhaMatch = path.match(/^\/colaboradores\/([0-9a-fA-F-]+)\/senha$/);
  if (senhaMatch && req.method === "PUT") {
    if (requester.role !== "admin") return json({ error: "Apenas admin" }, 403);
    const colaboradorId = senhaMatch[1];
    const { senha } = await req.json();

    if (!senha || senha.length < 6) {
      return json({ error: "A senha deve ter pelo menos 6 caracteres" }, 400);
    }

    const { data: colaborador, error: colabError } = await admin
      .from("colaboradores")
      .select("user_id")
      .eq("id", colaboradorId)
      .single();
    if (colabError || !colaborador?.user_id) {
      return json({ error: "Colaborador sem login vinculado" }, 400);
    }

    const { error: authError } = await admin.auth.admin.updateUserById(colaborador.user_id, {
      password: senha,
    });
    if (authError) return json({ error: authError.message }, 400);

    return json({ ok: true });
  }

  // ---------------------------------------------------
  // PUT /colaboradores/:id/status — admin (ativar/desativar)
  // body: { ativo: boolean }
  // ---------------------------------------------------
  const statusMatch = path.match(/^\/colaboradores\/([0-9a-fA-F-]+)\/status$/);
  if (statusMatch && req.method === "PUT") {
    if (requester.role !== "admin") return json({ error: "Apenas admin" }, 403);
    const colaboradorId = statusMatch[1];
    const { ativo } = await req.json();

    const { error } = await admin.from("colaboradores").update({ ativo }).eq("id", colaboradorId);
    if (error) return json({ error: error.message }, 400);

    await admin.from("usuarios").update({ ativo }).eq("colaborador_id", colaboradorId);
    return json({ ok: true });
  }

  return json({ error: "Rota não encontrada" }, 404);
});
