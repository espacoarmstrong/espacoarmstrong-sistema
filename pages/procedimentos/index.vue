<template>
  <div>
    <div class="cabecalho">
      <h1>Procedimentos</h1>
      <button v-if="ehAdmin" class="btn btn-primary" @click="abrirNovo">+ Novo procedimento</button>
    </div>

    <div class="field" style="max-width:280px; margin-bottom: 16px;">
      <input v-model="busca" class="input" placeholder="Buscar por nome ou categoria" />
    </div>

    <div class="card" style="padding: 4px;">
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
            <td v-if="ehAdmin" style="text-align:right;">
              <button class="btn btn-ghost" @click="abrirEdicao(p)">Editar</button>
            </td>
          </tr>
          <tr v-if="!filtrados.length"><td colspan="6" style="color:var(--ink-muted);">Nenhum procedimento encontrado.</td></tr>
        </tbody>
      </table>
    </div>

    <div v-if="modalAberto" class="modal-backdrop" @click.self="modalAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">{{ editando?.id ? 'Editar procedimento' : 'Novo procedimento' }}</h2>
        <div class="field">
          <label>Nome</label>
          <input v-model="editando.nome" class="input" />
        </div>
        <div class="field">
          <label>Categoria</label>
          <select v-model="editando.categoria_id" class="input">
            <option value="" disabled>Selecione</option>
            <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nome }}</option>
          </select>
        </div>
        <div class="field">
          <label>Descrição (opcional)</label>
          <textarea v-model="editando.descricao" class="input" rows="2"></textarea>
        </div>
        <div style="display:flex; gap:12px;">
          <div class="field" style="flex:1;">
            <label>Duração (minutos)</label>
            <input v-model.number="editando.duracao_minutos" type="number" min="1" class="input" />
          </div>
          <div class="field" style="flex:1;">
            <label>Valor (R$)</label>
            <input v-model.number="editando.valor" type="number" min="0" step="0.01" class="input" />
          </div>
        </div>
        <div class="field" v-if="editando?.id">
          <label>Status</label>
          <select v-model="editando.ativo" class="input">
            <option :value="true">Ativo</option>
            <option :value="false">Inativo</option>
          </select>
        </div>
        <p v-if="erro" class="erro-msg">{{ erro }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" @click="salvar">Salvar</button>
          <button class="btn btn-ghost" @click="modalAberto = false">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { ehAdmin } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const procedimentos = ref<any[]>([]);
const categorias = ref<any[]>([]);
const busca = ref("");
const modalAberto = ref(false);
const editando = ref<any>({ nome: "", categoria_id: "", descricao: "", duracao_minutos: 30, valor: 0, ativo: true });
const erro = ref("");

const carregar = async () => {
  const [{ data: procs }, { data: cats }] = await Promise.all([
    supabase.from("procedimentos").select("*").order("nome"),
    supabase.from("categorias").select("*").order("nome"),
  ]);
  procedimentos.value = procs || [];
  categorias.value = cats || [];
};

const nomeCategoria = (id: string) => categorias.value.find((c) => c.id === id)?.nome || "—";
const formatarMoeda = (v: number) => (v ?? 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

const filtrados = computed(() => {
  const termo = busca.value.toLowerCase().trim();
  if (!termo) return procedimentos.value;
  return procedimentos.value.filter(
    (p) => p.nome.toLowerCase().includes(termo) || nomeCategoria(p.categoria_id).toLowerCase().includes(termo)
  );
});

const abrirNovo = () => {
  editando.value = { nome: "", categoria_id: categorias.value[0]?.id || "", descricao: "", duracao_minutos: 30, valor: 0, ativo: true };
  erro.value = "";
  modalAberto.value = true;
};
const abrirEdicao = (p: any) => {
  editando.value = { ...p };
  erro.value = "";
  modalAberto.value = true;
};

const salvar = async () => {
  if (!editando.value.nome?.trim()) { erro.value = "Informe o nome."; return; }
  if (!editando.value.categoria_id) { erro.value = "Selecione a categoria."; return; }
  const payload = {
    nome: editando.value.nome,
    categoria_id: editando.value.categoria_id,
    descricao: editando.value.descricao,
    duracao_minutos: editando.value.duracao_minutos,
    valor: editando.value.valor,
    ativo: editando.value.ativo,
  };
  const ehEdicao = !!editando.value.id;
  const query = ehEdicao
    ? supabase.from("procedimentos").update(payload).eq("id", editando.value.id)
    : supabase.from("procedimentos").insert(payload);
  const { error } = await query;
  if (error) { erro.value = error.message; toastErro("Não foi possível salvar o procedimento."); return; }
  modalAberto.value = false;
  await carregar();
  sucesso(ehEdicao ? "Procedimento atualizado com sucesso." : "Procedimento criado com sucesso.");
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
</style>
