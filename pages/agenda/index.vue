<template>
  <div>
    <div class="cabecalho">
      <h1>Agenda</h1>
      <button v-if="podeAcao('agenda_criar')" class="btn btn-primary" @click="abrirNovo">+ Novo agendamento</button>
    </div>

    <div class="filtros">
      <div class="field" style="max-width:180px;">
        <label>Data</label>
        <input v-model="dataFiltro" type="date" class="input" />
      </div>
      <div class="field" style="max-width:220px;">
        <label>Colaborador</label>
        <select v-model="colaboradorFiltro" class="input">
          <option value="">Todos</option>
          <option v-for="c in colaboradores" :key="c.id" :value="c.id">{{ c.nome }}</option>
        </select>
      </div>
    </div>

    <div class="card" style="padding: 4px;">
      <table>
        <thead>
          <tr><th>Horário</th><th>Cliente</th><th>Procedimento</th><th>Colaborador</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="a in filtrados" :key="a.id">
            <td>{{ formatarHora(a.data_hora) }}</td>
            <td>{{ a.clientes?.nome || '—' }}</td>
            <td>{{ a.procedimentos?.nome || '—' }}</td>
            <td>{{ a.colaboradores?.nome || '—' }}</td>
            <td><span :class="['badge', badgeClasse(a.status)]">{{ statusLabel(a.status) }}</span></td>
            <td style="text-align:right; white-space:nowrap;">
              <button v-if="podeAcao('agenda_editar') && a.status !== 'cancelado'" class="btn btn-ghost" @click="abrirEdicao(a)">Editar</button>
              <button v-if="podeAcao('agenda_cancelar') && a.status !== 'cancelado'" class="btn btn-danger" @click="confirmarCancelamento(a)">Cancelar</button>
            </td>
          </tr>
          <tr v-if="!filtrados.length"><td colspan="6" style="color:var(--ink-muted);">Nenhum agendamento encontrado.</td></tr>
        </tbody>
      </table>
    </div>

    <div v-if="modalAberto" class="modal-backdrop" @click.self="modalAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">{{ editando?.id ? 'Editar agendamento' : 'Novo agendamento' }}</h2>
        <div class="field">
          <label>Cliente</label>
          <select v-model="editando.cliente_id" class="input">
            <option value="" disabled>Selecione</option>
            <option v-for="c in clientes" :key="c.id" :value="c.id">{{ c.nome }}</option>
          </select>
        </div>
        <div class="field">
          <label>Procedimento</label>
          <select v-model="editando.procedimento_id" class="input">
            <option value="" disabled>Selecione</option>
            <option v-for="p in procedimentos" :key="p.id" :value="p.id">{{ p.nome }} ({{ p.duracao_minutos }} min)</option>
          </select>
        </div>
        <div class="field">
          <label>Colaborador</label>
          <select v-model="editando.colaborador_id" class="input">
            <option value="" disabled>Selecione</option>
            <option v-for="c in colaboradores" :key="c.id" :value="c.id">{{ c.nome }}</option>
          </select>
        </div>
        <div style="display:flex; gap:12px;">
          <div class="field" style="flex:1;">
            <label>Data</label>
            <input v-model="editandoData" type="date" class="input" />
          </div>
          <div class="field" style="flex:1;">
            <label>Hora</label>
            <input v-model="editandoHora" type="time" class="input" />
          </div>
        </div>
        <div class="field" v-if="editando?.id">
          <label>Status</label>
          <select v-model="editando.status" class="input">
            <option value="agendado">Agendado</option>
            <option value="confirmado">Confirmado</option>
            <option value="concluido">Concluído</option>
          </select>
        </div>
        <div class="field">
          <label>Observações</label>
          <textarea v-model="editando.observacoes" class="input" rows="2"></textarea>
        </div>
        <p v-if="erro" class="erro-msg">{{ erro }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" @click="salvar">Salvar</button>
          <button class="btn btn-ghost" @click="modalAberto = false">Cancelar</button>
        </div>
      </div>
    </div>

    <div v-if="cancelando" class="modal-backdrop" @click.self="cancelando = null">
      <div class="modal" style="max-width:380px;">
        <h2 style="margin-bottom:10px;">Cancelar agendamento?</h2>
        <p style="color:var(--ink-muted); font-size:14px;">O agendamento será marcado como cancelado e removido da agenda ativa.</p>
        <div style="display:flex; gap:10px; margin-top: 16px;">
          <button class="btn btn-danger" @click="cancelar">Cancelar agendamento</button>
          <button class="btn btn-ghost" @click="cancelando = null">Voltar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { podeAcao } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const agendamentos = ref<any[]>([]);
const clientes = ref<any[]>([]);
const procedimentos = ref<any[]>([]);
const colaboradores = ref<any[]>([]);

const hoje = new Date().toISOString().slice(0, 10);
const dataFiltro = ref(hoje);
const colaboradorFiltro = ref("");

const modalAberto = ref(false);
const editando = ref<any>({ cliente_id: "", procedimento_id: "", colaborador_id: "", observacoes: "", status: "agendado" });
const editandoData = ref(hoje);
const editandoHora = ref("09:00");
const erro = ref("");
const cancelando = ref<any>(null);

const carregar = async () => {
  const [{ data: ag }, { data: cli }, { data: proc }, { data: col }] = await Promise.all([
    supabase
      .from("agendamentos")
      .select("*, clientes(nome), procedimentos(nome, duracao_minutos), colaboradores(nome)")
      .order("data_hora"),
    supabase.from("clientes").select("id, nome").eq("ativo", true).order("nome"),
    supabase.from("procedimentos").select("id, nome, duracao_minutos").eq("ativo", true).order("nome"),
    supabase.from("colaboradores").select("id, nome").eq("ativo", true).order("nome"),
  ]);
  agendamentos.value = ag || [];
  clientes.value = cli || [];
  procedimentos.value = proc || [];
  colaboradores.value = col || [];
};

const filtrados = computed(() => {
  return agendamentos.value.filter((a) => {
    const dataOk = !dataFiltro.value || a.data_hora.slice(0, 10) === dataFiltro.value;
    const colabOk = !colaboradorFiltro.value || a.colaborador_id === colaboradorFiltro.value;
    return dataOk && colabOk;
  });
});

const formatarHora = (v: string) => new Date(v).toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
const statusLabel = (s: string) => ({ agendado: "Agendado", confirmado: "Confirmado", concluido: "Concluído", cancelado: "Cancelado" }[s] || s);
const badgeClasse = (s: string) => ({ agendado: "badge-warning", confirmado: "badge-success", concluido: "badge-success", cancelado: "badge-danger" }[s] || "badge-warning");

const abrirNovo = () => {
  editando.value = { cliente_id: "", procedimento_id: "", colaborador_id: "", observacoes: "", status: "agendado" };
  editandoData.value = dataFiltro.value || hoje;
  editandoHora.value = "09:00";
  erro.value = "";
  modalAberto.value = true;
};

const abrirEdicao = (a: any) => {
  editando.value = { ...a };
  const dt = new Date(a.data_hora);
  editandoData.value = dt.toISOString().slice(0, 10);
  editandoHora.value = dt.toTimeString().slice(0, 5);
  erro.value = "";
  modalAberto.value = true;
};

const salvar = async () => {
  if (!editando.value.cliente_id || !editando.value.procedimento_id || !editando.value.colaborador_id) {
    erro.value = "Selecione cliente, procedimento e colaborador.";
    return;
  }
  if (!editandoData.value || !editandoHora.value) {
    erro.value = "Informe a data e a hora.";
    return;
  }
  const dataHora = new Date(`${editandoData.value}T${editandoHora.value}:00`).toISOString();
  const payload = {
    cliente_id: editando.value.cliente_id,
    procedimento_id: editando.value.procedimento_id,
    colaborador_id: editando.value.colaborador_id,
    data_hora: dataHora,
    observacoes: editando.value.observacoes,
    status: editando.value.status || "agendado",
  };
  const ehEdicao = !!editando.value.id;
  const query = ehEdicao
    ? supabase.from("agendamentos").update(payload).eq("id", editando.value.id)
    : supabase.from("agendamentos").insert(payload);
  const { error } = await query;
  if (error) { erro.value = error.message; toastErro("Não foi possível salvar o agendamento."); return; }
  modalAberto.value = false;
  await carregar();
  sucesso(ehEdicao ? "Agendamento atualizado com sucesso." : "Agendamento criado com sucesso.");
};

const confirmarCancelamento = (a: any) => { cancelando.value = a; };
const cancelar = async () => {
  const { error } = await supabase.from("agendamentos").update({ status: "cancelado" }).eq("id", cancelando.value.id);
  cancelando.value = null;
  if (error) { toastErro("Não foi possível cancelar o agendamento."); return; }
  await carregar();
  sucesso("Agendamento cancelado com sucesso.");
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.filtros { display: flex; gap: 14px; margin-bottom: 16px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
</style>
