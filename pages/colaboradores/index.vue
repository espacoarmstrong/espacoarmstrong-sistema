<template>
  <div>
    <div class="cabecalho">
      <h1>Colaboradores</h1>
      <button v-if="ehAdmin" class="btn btn-primary" @click="abrirNovo">+ Novo colaborador</button>
    </div>

    <div class="card tabela-wrap">
      <table>
        <thead>
          <tr><th></th><th>Nome</th><th>Cargo</th><th>Telefone</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="c in colaboradores" :key="c.id">
            <td>
              <img v-if="c.foto_url" :src="c.foto_url" class="avatar" />
              <div v-else class="avatar">{{ (c.nome||'').trim().split(/\s+/).slice(0,2).map((p:string)=>p[0]?.toUpperCase()).join('') || '?' }}</div>
            </td>
            <td>{{ c.nome }}</td>
            <td>{{ c.cargo || '—' }}</td>
            <td>{{ c.telefone || '—' }}</td>
            <td><span :class="['badge', c.ativo ? 'badge-success' : 'badge-danger']">{{ c.ativo ? 'Ativo' : 'Inativo' }}</span></td>
            <td style="text-align:right; white-space:nowrap;">
              <NuxtLink :to="`/colaboradores/${c.id}`" class="btn btn-ghost">Gerenciar</NuxtLink>
              <button v-if="ehAdmin" class="btn btn-danger" @click="confirmarExclusao(c)">Excluir</button>
            </td>
          </tr>
          <tr v-if="!colaboradores.length"><td colspan="6" style="color:var(--ink-muted);">Nenhum colaborador cadastrado.</td></tr>
        </tbody>
      </table>
    </div>

    <ConfirmarExclusao
      v-if="excluindo"
      titulo="Excluir colaborador?"
      mensagem="O login de acesso também será removido. Se o colaborador tiver agendamentos ou remunerações, prefira desativá-lo em vez de excluir."
      @confirmar="excluir"
      @cancelar="excluindo = null"
    />

    <div v-if="modalAberto" class="modal-backdrop" @click.self="modalAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">Novo colaborador</h2>
        <form autocomplete="off" @submit.prevent="salvar">
        <!-- campos-isca: fazem o navegador salvar autopreenchimento aqui em vez dos campos reais -->
        <input type="text" name="fakeusernameremembered" style="display:none" tabindex="-1" />
        <input type="password" name="fakepasswordremembered" style="display:none" tabindex="-1" />
        <div class="field">
          <label>Nome</label>
          <input v-model="novo.nome" class="input" autocomplete="off" />
        </div>
        <div class="field">
          <label>Telefone</label>
          <input v-model="novo.telefone" class="input" autocomplete="off" />
        </div>
        <div class="field">
          <label>Cargo / Função</label>
          <input v-model="novo.cargo" class="input" autocomplete="off" />
        </div>
        <div class="field">
          <label>E-mail de acesso</label>
          <input v-model="novo.email" type="email" class="input" name="colab_email_novo" autocomplete="off" />
        </div>
        <div class="field">
          <label>Senha provisória</label>
          <input v-model="novo.senha" type="password" class="input" name="colab_senha_novo" autocomplete="new-password" />
        </div>
        </form>
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
const excluindo = ref<any>(null);

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

const confirmarExclusao = (c: any) => { excluindo.value = c; };
const excluir = async () => {
  try {
    await chamar(`/colaboradores/${excluindo.value.id}`, { method: "DELETE" });
    excluindo.value = null;
    await carregar();
    sucesso("Colaborador excluído com sucesso.");
  } catch (e: any) {
    excluindo.value = null;
    toastErro(e.message || "Não foi possível excluir o colaborador.");
  }
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
</style>
