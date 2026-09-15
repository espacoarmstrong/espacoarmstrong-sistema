<template>
  <div>
    <div class="cabecalho">
      <h1>Procedimentos</h1>
      <button v-if="ehAdmin && aba === 'procedimentos'" class="btn btn-primary" @click="abrirNovoProcedimento">+ Novo procedimento</button>
      <button v-if="ehAdmin && aba === 'categorias'" class="btn btn-primary" @click="abrirNovaCategoria">+ Nova categoria</button>
    </div>

    <div class="abas">
      <button :class="['aba', { ativa: aba === 'procedimentos' }]" @click="aba = 'procedimentos'">Procedimentos</button>
      <button :class="['aba', { ativa: aba === 'categorias' }]" @click="aba = 'categorias'">Categorias</button>
    </div>

    <!-- ABA PROCEDIMENTOS -->
    <template v-if="aba === 'procedimentos'">
      <div class="field" style="max-width:280px; margin-bottom: 16px;">
        <input v-model="busca" class="input" placeholder="Buscar por nome ou categoria" />
      </div>

      <div class="card tabela-wrap">
        <table>
          <thead>
            <tr><th>Nome</th><th>Categoria</th><th>Duração</th><th>Valor</th><th>Status</th><th v-if="ehAdmin"></th></tr>
          </thead>
          <tbody>
            <tr v-for="p in filtrados" :key="p.id">
              <td>{{ p.nome }}</td>
              <td>{{ nomeCategoria(p.categoria_id) }}</td>
              <td>{{ p.duracao_minutos }} min</td>
              <td>{{ formatarMoeda(p.valor) }}</td>
              <td>
                <span :class="['badge', p.ativo ? 'badge-success' : 'badge-danger']">{{ p.ativo ? 'Ativo' : 'Inativo' }}</span>
              </td>
              <td v-if="ehAdmin" style="text-align:right; white-space:nowrap;">
                <button class="btn btn-ghost" @click="abrirEdicaoProcedimento(p)">Editar</button>
                <button class="btn btn-danger" @click="confirmarExclusaoProcedimento(p)">Excluir</button>
              </td>
            </tr>
            <tr v-if="!filtrados.length"><td colspan="6" style="color:var(--ink-muted);">Nenhum procedimento encontrado.</td></tr>
          </tbody>
        </table>
      </div>
    </template>

    <!-- ABA CATEGORIAS -->
    <template v-if="aba === 'categorias'">
      <div class="card tabela-wrap">
        <table>
          <thead>
            <tr><th>Nome</th><th>Procedimentos</th><th>Status</th><th v-if="ehAdmin"></th></tr>
          </thead>
          <tbody>
            <tr v-for="c in categorias" :key="c.id">
              <td>{{ c.nome }}</td>
              <td>{{ contagemPorCategoria(c.id) }}</td>
              <td>
                <span :class="['badge', c.ativo ? 'badge-success' : 'badge-danger']">
                  {{ c.ativo ? 'Ativa' : 'Inativa' }}
                </span>
              </td>
              <td v-if="ehAdmin" style="text-align:right; white-space:nowrap;">
                <button class="btn btn-ghost" @click="abrirEdicaoCategoria(c)">Editar</button>
                <button class="btn btn-danger" @click="confirmarExclusaoCategoria(c)">Excluir</button>
              </td>
            </tr>
            <tr v-if="!categorias.length"><td colspan="4" style="color:var(--ink-muted);">Nenhuma categoria cadastrada.</td></tr>
          </tbody>
        </table>
      </div>
    </template>

    <!-- MODAL: novo/editar procedimento -->
    <div v-if="modalProcedimento" class="modal-backdrop" @click.self="modalProcedimento = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">{{ editandoProcedimento?.id ? 'Editar procedimento' : 'Novo procedimento' }}</h2>
        <div class="field">
          <label>Nome</label>
          <input v-model="editandoProcedimento.nome" class="input" />
        </div>
        <div class="field">
          <label>Categoria</label>
          <select v-model="editandoProcedimento.categoria_id" class="input">
            <option value="" disabled>Selecione</option>
            <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nome }}</option>
          </select>
        </div>
        <div class="field">
          <label>Descrição (opcional)</label>
          <textarea v-model="editandoProcedimento.descricao" class="input" rows="2"></textarea>
        </div>
        <div class="linha-dupla">
          <div class="field" style="flex:1;">
            <label>Duração (minutos)</label>
            <input v-model.number="editandoProcedimento.duracao_minutos" type="number" min="1" class="input" />
          </div>
          <div class="field" style="flex:1;">
            <label>Valor (R$)</label>
            <input v-model.number="editandoProcedimento.valor" type="number" min="0" step="0.01" class="input" />
          </div>
        </div>
        <div class="field" v-if="editandoProcedimento?.id">
          <label>Status</label>
          <select v-model="editandoProcedimento.ativo" class="input">
            <option :value="true">Ativo</option>
            <option :value="false">Inativo</option>
          </select>
        </div>
        <p v-if="erro" class="erro-msg">{{ erro }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" @click="salvarProcedimento">Salvar</button>
          <button class="btn btn-ghost" @click="modalProcedimento = false">Cancelar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: nova/editar categoria -->
    <div v-if="modalCategoria" class="modal-backdrop" @click.self="modalCategoria = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">{{ editandoCategoria?.id ? 'Editar categoria' : 'Nova categoria' }}</h2>
        <div class="field">
          <label>Nome</label>
          <input v-model="editandoCategoria.nome" class="input" />
        </div>
        <div class="field" v-if="editandoCategoria?.id">
          <label>Status</label>
          <select v-model="editandoCategoria.ativo" class="input">
            <option :value="true">Ativa</option>
            <option :value="false">Inativa</option>
          </select>
        </div>
        <p v-if="erroCategoria" class="erro-msg">{{ erroCategoria }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" @click="salvarCategoria">Salvar</button>
          <button class="btn btn-ghost" @click="modalCategoria = false">Cancelar</button>
        </div>
      </div>
    </div>

    <ConfirmarExclusao
      v-if="excluindoProcedimento"
      titulo="Excluir procedimento?"
      mensagem="Se ele já estiver vinculado a agendamentos, pacotes ou comissões, prefira desativá-lo em vez de excluir."
      @confirmar="excluirProcedimento"
      @cancelar="excluindoProcedimento = null"
    />

    <ConfirmarExclusao
      v-if="excluindoCategoria"
      titulo="Excluir categoria?"
      mensagem="Só é possível excluir categorias sem procedimentos cadastrados. Mova ou exclua os procedimentos antes."
      @confirmar="excluirCategoria"
      @cancelar="excluindoCategoria = null"
    />
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { ehAdmin } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const aba = ref<"procedimentos" | "categorias">("procedimentos");

const procedimentos = ref<any[]>([]);
const categorias = ref<any[]>([]);
const busca = ref("");

// ---------- procedimentos ----------
const modalProcedimento = ref(false);
const editandoProcedimento = ref<any>({ nome: "", categoria_id: "", descricao: "", duracao_minutos: 30, valor: 0, ativo: true });
const erro = ref("");

// ---------- categorias ----------
const modalCategoria = ref(false);
const editandoCategoria = ref<any>({ nome: "", ativo: true });
const erroCategoria = ref("");
const excluindoProcedimento = ref<any>(null);
const excluindoCategoria = ref<any>(null);

const carregar = async () => {
  const [{ data: procs }, { data: cats }] = await Promise.all([
    supabase.from("procedimentos").select("*").order("nome"),
    supabase.from("categorias").select("*").order("nome"),
  ]);
  procedimentos.value = procs || [];
  categorias.value = cats || [];
};

const nomeCategoria = (id: string) => categorias.value.find((c) => c.id === id)?.nome || "—";
const contagemPorCategoria = (id: string) => procedimentos.value.filter((p) => p.categoria_id === id).length;
const formatarMoeda = (v: number) => (v ?? 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

const filtrados = computed(() => {
  const termo = busca.value.toLowerCase().trim();
  if (!termo) return procedimentos.value;
  return procedimentos.value.filter(
    (p) => p.nome.toLowerCase().includes(termo) || nomeCategoria(p.categoria_id).toLowerCase().includes(termo)
  );
});

const abrirNovoProcedimento = () => {
  editandoProcedimento.value = { nome: "", categoria_id: categorias.value[0]?.id || "", descricao: "", duracao_minutos: 30, valor: 0, ativo: true };
  erro.value = "";
  modalProcedimento.value = true;
};
const abrirEdicaoProcedimento = (p: any) => {
  editandoProcedimento.value = { ...p };
  erro.value = "";
  modalProcedimento.value = true;
};

const salvarProcedimento = async () => {
  if (!editandoProcedimento.value.nome?.trim()) { erro.value = "Informe o nome."; return; }
  if (!editandoProcedimento.value.categoria_id) { erro.value = "Selecione a categoria."; return; }
  const payload = {
    nome: editandoProcedimento.value.nome,
    categoria_id: editandoProcedimento.value.categoria_id,
    descricao: editandoProcedimento.value.descricao,
    duracao_minutos: editandoProcedimento.value.duracao_minutos,
    valor: editandoProcedimento.value.valor,
    ativo: editandoProcedimento.value.ativo,
  };
  const ehEdicao = !!editandoProcedimento.value.id;
  const query = ehEdicao
    ? supabase.from("procedimentos").update(payload).eq("id", editandoProcedimento.value.id)
    : supabase.from("procedimentos").insert(payload);
  const { error } = await query;
  if (error) { erro.value = error.message; toastErro("Não foi possível salvar o procedimento."); return; }
  modalProcedimento.value = false;
  await carregar();
  sucesso(ehEdicao ? "Procedimento atualizado com sucesso." : "Procedimento criado com sucesso.");
};

const abrirNovaCategoria = () => {
  editandoCategoria.value = { nome: "", ativo: true };
  erroCategoria.value = "";
  modalCategoria.value = true;
};
const abrirEdicaoCategoria = (c: any) => {
  editandoCategoria.value = { ...c };
  erroCategoria.value = "";
  modalCategoria.value = true;
};

const salvarCategoria = async () => {
  if (!editandoCategoria.value.nome?.trim()) { erroCategoria.value = "Informe o nome."; return; }
  const payload = { nome: editandoCategoria.value.nome, ativo: editandoCategoria.value.ativo };
  const ehEdicao = !!editandoCategoria.value.id;
  const query = ehEdicao
    ? supabase.from("categorias").update(payload).eq("id", editandoCategoria.value.id)
    : supabase.from("categorias").insert(payload);
  const { error } = await query;
  if (error) { erroCategoria.value = error.message; toastErro("Não foi possível salvar a categoria."); return; }
  modalCategoria.value = false;
  await carregar();
  sucesso(ehEdicao ? "Categoria atualizada com sucesso." : "Categoria criada com sucesso.");
};

const confirmarExclusaoProcedimento = (p: any) => { excluindoProcedimento.value = p; };
const excluirProcedimento = async () => {
  const { error } = await supabase.from("procedimentos").delete().eq("id", excluindoProcedimento.value.id);
  excluindoProcedimento.value = null;
  if (error) {
    toastErro(error.code === "23503"
      ? "Este procedimento está vinculado a agendamentos, pacotes ou comissões. Desative-o em vez de excluir."
      : "Não foi possível excluir o procedimento.");
    return;
  }
  await carregar();
  sucesso("Procedimento excluído com sucesso.");
};

const confirmarExclusaoCategoria = (c: any) => { excluindoCategoria.value = c; };
const excluirCategoria = async () => {
  const { error } = await supabase.from("categorias").delete().eq("id", excluindoCategoria.value.id);
  excluindoCategoria.value = null;
  if (error) {
    toastErro(error.code === "23503"
      ? "Esta categoria possui procedimentos cadastrados. Mova ou exclua-os antes de remover a categoria."
      : "Não foi possível excluir a categoria.");
    return;
  }
  await carregar();
  sucesso("Categoria excluída com sucesso.");
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 10px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
.abas { display: flex; gap: 4px; border-bottom: 1px solid var(--border); margin-bottom: 16px; }
.aba { padding: 10px 16px; border: none; background: none; font-size: 14px; font-weight: 500; color: var(--ink-muted); border-bottom: 2px solid transparent; }
.aba.ativa { color: var(--primary-dark); border-bottom-color: var(--primary); }
</style>
