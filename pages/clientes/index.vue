<template>
  <div>
    <div class="cabecalho">
      <h1>Clientes</h1>
      <button v-if="podeAcao('clientes_criar')" class="btn btn-primary" @click="abrirNovo">+ Novo cliente</button>
    </div>

    <div class="field" style="max-width:280px; margin-bottom: 16px;">
      <input v-model="busca" class="input" placeholder="Buscar por nome ou telefone" />
    </div>

    <div class="card" style="padding: 4px;">
      <table>
        <thead>
          <tr><th>Nome</th><th>Telefone</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="c in filtrados" :key="c.id">
            <td>{{ c.nome }}</td>
            <td>{{ c.telefone || '—' }}</td>
            <td><span :class="['badge', c.ativo ? 'badge-success' : 'badge-danger']">{{ c.ativo ? 'Ativo' : 'Inativo' }}</span></td>
            <td style="text-align:right;">
              <button v-if="podeAcao('clientes_editar')" class="btn btn-ghost" @click="abrirEdicao(c)">Editar</button>
              <button v-if="podeAcao('clientes_excluir')" class="btn btn-danger" @click="confirmarExclusao(c)">Excluir</button>
            </td>
          </tr>
          <tr v-if="!filtrados.length"><td colspan="4" style="color:var(--ink-muted);">Nenhum cliente encontrado.</td></tr>
        </tbody>
      </table>
    </div>

    <div v-if="modalAberto" class="modal-backdrop" @click.self="modalAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">{{ editando?.id ? 'Editar cliente' : 'Novo cliente' }}</h2>
        <div class="field">
          <label>Nome</label>
          <input v-model="editando.nome" class="input" />
        </div>
        <div class="field">
          <label>Telefone</label>
          <input v-model="editando.telefone" class="input" placeholder="(00) 00000-0000" />
        </div>
        <div class="field">
          <label>Observações</label>
          <textarea v-model="editando.observacoes" class="input" rows="3"></textarea>
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

    <div v-if="excluindo" class="modal-backdrop" @click.self="excluindo = null">
      <div class="modal" style="max-width:380px;">
        <h2 style="margin-bottom:10px;">Excluir cliente?</h2>
        <p style="color:var(--ink-muted); font-size:14px;">Essa ação não poderá ser desfeita. Se o cliente tiver histórico, prefira desativá-lo em vez de excluir.</p>
        <div style="display:flex; gap:10px; margin-top: 16px;">
          <button class="btn btn-danger" @click="excluir">Excluir definitivamente</button>
          <button class="btn btn-ghost" @click="excluindo = null">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { podeAcao } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const clientes = ref<any[]>([]);
const busca = ref("");
const modalAberto = ref(false);
const editando = ref<any>({ nome: "", telefone: "", observacoes: "", ativo: true });
const erro = ref("");
const excluindo = ref<any>(null);

const carregar = async () => {
  const { data } = await supabase.from("clientes").select("*").order("nome");
  clientes.value = data || [];
};

const filtrados = computed(() => {
  const termo = busca.value.toLowerCase().trim();
  if (!termo) return clientes.value;
  return clientes.value.filter(
    (c) => c.nome.toLowerCase().includes(termo) || (c.telefone || "").includes(termo)
  );
});

const abrirNovo = () => {
  editando.value = { nome: "", telefone: "", observacoes: "", ativo: true };
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
  const payload = {
    nome: editando.value.nome,
    telefone: editando.value.telefone,
    observacoes: editando.value.observacoes,
    ativo: editando.value.ativo,
  };
  const ehEdicao = !!editando.value.id;
  const query = ehEdicao
    ? supabase.from("clientes").update(payload).eq("id", editando.value.id)
    : supabase.from("clientes").insert(payload);
  const { error } = await query;
  if (error) { erro.value = error.message; toastErro("Não foi possível salvar o cliente."); return; }
  modalAberto.value = false;
  await carregar();
  sucesso(ehEdicao ? "Cliente atualizado com sucesso." : "Cliente criado com sucesso.");
};

const confirmarExclusao = (c: any) => { excluindo.value = c; };
const excluir = async () => {
  const { error } = await supabase.from("clientes").delete().eq("id", excluindo.value.id);
  excluindo.value = null;
  if (error) { toastErro("Não foi possível excluir o cliente."); return; }
  await carregar();
  sucesso("Cliente excluído com sucesso.");
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
</style>
