<template>
  <div>
    <div class="cabecalho">
      <h1>Colaboradores</h1>
      <button v-if="ehAdmin" class="btn btn-primary" @click="abrirNovo">+ Novo colaborador</button>
    </div>

    <div class="card" style="padding: 4px;">
      <table>
        <thead>
          <tr><th>Nome</th><th>Cargo</th><th>Telefone</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="c in colaboradores" :key="c.id">
            <td>{{ c.nome }}</td>
            <td>{{ c.cargo || '—' }}</td>
            <td>{{ c.telefone || '—' }}</td>
            <td><span :class="['badge', c.ativo ? 'badge-success' : 'badge-danger']">{{ c.ativo ? 'Ativo' : 'Inativo' }}</span></td>
            <td style="text-align:right;">
              <NuxtLink :to="`/colaboradores/${c.id}`" class="btn btn-ghost">Gerenciar</NuxtLink>
            </td>
          </tr>
          <tr v-if="!colaboradores.length"><td colspan="5" style="color:var(--ink-muted);">Nenhum colaborador cadastrado.</td></tr>
        </tbody>
      </table>
    </div>

    <div v-if="modalAberto" class="modal-backdrop" @click.self="modalAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">Novo colaborador</h2>
        <div class="field">
          <label>Nome</label>
          <input v-model="novo.nome" class="input" />
        </div>
        <div class="field">
          <label>Telefone</label>
          <input v-model="novo.telefone" class="input" />
        </div>
        <div class="field">
          <label>Cargo / Função</label>
          <input v-model="novo.cargo" class="input" />
        </div>
        <div class="field">
          <label>E-mail de acesso</label>
          <input v-model="novo.email" type="email" class="input" />
        </div>
        <div class="field">
          <label>Senha provisória</label>
          <input v-model="novo.senha" type="password" class="input" />
        </div>
        <p v-if="erro" class="erro-msg">{{ erro }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" :disabled="salvando" @click="salvar">{{ salvando ? 'Salvando...' : 'Criar colaborador' }}</button>
          <button class="btn btn-ghost" @click="modalAberto = false">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { ehAdmin } = useUsuario();
const { chamar } = useApi();
const { sucesso, erro: toastErro } = useToast();

const colaboradores = ref<any[]>([]);
const modalAberto = ref(false);
const novo = ref({ nome: "", telefone: "", cargo: "", email: "", senha: "" });
const erro = ref("");
const salvando = ref(false);

const carregar = async () => {
  const { data } = await supabase.from("colaboradores").select("*").order("nome");
  colaboradores.value = data || [];
};

const abrirNovo = () => {
  novo.value = { nome: "", telefone: "", cargo: "", email: "", senha: "" };
  erro.value = "";
  modalAberto.value = true;
};

const salvar = async () => {
  if (!novo.value.nome?.trim() || !novo.value.email?.trim() || !novo.value.senha?.trim()) {
    erro.value = "Nome, e-mail e senha são obrigatórios.";
    return;
  }
  salvando.value = true;
  try {
    await chamar("/colaboradores", { method: "POST", body: novo.value });
    modalAberto.value = false;
    await carregar();
    sucesso("Colaborador criado com sucesso.");
  } catch (e: any) {
    erro.value = e.message;
    toastErro("Não foi possível criar o colaborador.");
  } finally {
    salvando.value = false;
  }
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
</style>
