<template>
  <div>
    <div class="cabecalho">
      <h1>Categorias</h1>
      <button v-if="ehAdmin" class="btn btn-primary" @click="abrirNovo">+ Nova categoria</button>
    </div>

    <div class="card" style="padding: 4px;">
      <table>
        <thead>
          <tr><th>Nome</th><th>Status</th><th v-if="ehAdmin"></th></tr>
        </thead>
        <tbody>
          <tr v-for="c in categorias" :key="c.id">
            <td>{{ c.nome }}</td>
            <td>
              <span :class="['badge', c.ativo ? 'badge-success' : 'badge-danger']">
                {{ c.ativo ? 'Ativa' : 'Inativa' }}
              </span>
            </td>
            <td v-if="ehAdmin" style="text-align:right;">
              <button class="btn btn-ghost" @click="abrirEdicao(c)">Editar</button>
            </td>
          </tr>
          <tr v-if="!categorias.length"><td colspan="3" style="color:var(--ink-muted);">Nenhuma categoria cadastrada.</td></tr>
        </tbody>
      </table>
    </div>

    <div v-if="modalAberto" class="modal-backdrop" @click.self="modalAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">{{ editando?.id ? 'Editar categoria' : 'Nova categoria' }}</h2>
        <div class="field">
          <label>Nome</label>
          <input v-model="editando.nome" class="input" />
        </div>
        <div class="field" v-if="editando?.id">
          <label>Status</label>
          <select v-model="editando.ativo" class="input">
            <option :value="true">Ativa</option>
            <option :value="false">Inativa</option>
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

const categorias = ref<any[]>([]);
const modalAberto = ref(false);
const editando = ref<any>({ nome: "", ativo: true });
const erro = ref("");

const carregar = async () => {
  const { data } = await supabase.from("categorias").select("*").order("nome");
  categorias.value = data || [];
};

const abrirNovo = () => {
  editando.value = { nome: "", ativo: true };
  erro.value = "";
  modalAberto.value = true;
};
const abrirEdicao = (c: any) => {
  editando.value = { ...c };
  erro.value = "";
  modalAberto.value = true;
};

const salvar = async () => {
  if (!editando.value.nome?.trim()) { erro.value = "Informe o nome."; return; }
  const payload = { nome: editando.value.nome, ativo: editando.value.ativo };
  const ehEdicao = !!editando.value.id;
  const query = ehEdicao
    ? supabase.from("categorias").update(payload).eq("id", editando.value.id)
    : supabase.from("categorias").insert(payload);
  const { error } = await query;
  if (error) { erro.value = error.message; toastErro("Não foi possível salvar a categoria."); return; }
  modalAberto.value = false;
  await carregar();
  sucesso(ehEdicao ? "Categoria atualizada com sucesso." : "Categoria criada com sucesso.");
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
</style>
