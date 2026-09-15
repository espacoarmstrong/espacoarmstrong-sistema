<template>
  <div>
    <div class="cabecalho">
      <h1>Atendimentos</h1>
      <div style="display:flex; gap:8px;">
        <button v-if="podeAcao('agenda_editar')" class="btn" :class="modoBloqueio ? 'btn-danger' : 'btn-ghost'" @click="modoBloqueio = !modoBloqueio">
          {{ modoBloqueio ? 'Cancelar bloqueio' : 'Bloquear horários' }}
        </button>
        <button v-if="podeAcao('agenda_criar')" class="btn btn-primary" @click="abrirNovo()">+ Novo agendamento</button>
      </div>
    </div>

    <div class="barra">
      <div class="visao-switch">
        <button :class="{ ativa: visao === 'dia' }" @click="visao = 'dia'">Dia</button>
        <button :class="{ ativa: visao === 'semana' }" @click="visao = 'semana'">Semana</button>
        <button :class="{ ativa: visao === 'mes' }" @click="visao = 'mes'">Mês</button>
      </div>
      <div class="navegacao">
        <button class="btn btn-ghost" @click="navegar(-1)">‹</button>
        <strong class="data-label">{{ labelData }}</strong>
        <button class="btn btn-ghost" @click="navegar(1)">›</button>
        <input type="date" class="input" style="width:150px;" :value="dataAtual" @change="irParaData(($event.target as HTMLInputElement).value)" />
      </div>
    </div>

    <p v-if="modoBloqueio" class="ajuda-bloqueio">Clique em um horário livre para bloqueá-lo. Clique em um bloqueio existente para liberá-lo.</p>

    <!-- VISÃO DIA -->
    <div v-if="visao === 'dia'" class="card dia-wrap">
      <div class="dia-grid">
        <div class="coluna-horas">
          <div class="colab-header"></div>
          <div class="area-horas" :style="{ height: alturaTotal + 'px' }">
            <div v-for="h in horasGrid" :key="h" class="marca-hora" :style="{ top: (h - horaInicio) * pxPorMinuto * 60 + 'px' }">
              {{ String(h).padStart(2, '0') }}:00
            </div>
          </div>
        </div>
        <div v-for="c in colaboradores" :key="c.id" class="coluna-colab">
          <div class="colab-header">
            <img v-if="c.foto_url" :src="c.foto_url" class="avatar" />
            <div v-else class="avatar">{{ iniciais(c.nome) }}</div>
            <span class="colab-nome">{{ primeiroNome(c.nome) }}</span>
          </div>
          <div class="area-colab" :style="{ height: alturaTotal + 'px' }" @click="cliqueGrade($event, c)">
            <div v-for="h in horasGrid" :key="h" class="linha-hora" :style="{ top: (h - horaInicio) * pxPorMinuto * 60 + 'px' }"></div>

            <div
              v-for="b in bloqueiosDoColaborador(c.id)"
              :key="'b-' + b.id"
              class="bloco-bloqueio"
              :style="posicao(b.data_inicio, minutosEntre(b.data_inicio, b.data_fim))"
              @click.stop="podeAcao('agenda_editar') && liberarBloqueio(b)"
            >
              <span>Bloqueado</span>
              <small v-if="b.motivo">{{ b.motivo }}</small>
            </div>

            <div
              v-for="a in agendamentosDoColaborador(c.id)"
              :key="a.id"
              class="bloco-agendamento"
              :class="'status-' + a.status"
              :style="posicao(a.data_hora, a.procedimentos?.duracao_minutos || 30)"
              @click.stop="abrirEdicao(a)"
            >
              <strong>{{ formatarHora(a.data_hora) }} · {{ a.clientes?.nome || '—' }}</strong>
              <span>{{ a.procedimentos?.nome || '—' }}</span>
            </div>
          </div>
        </div>
        <div v-if="!colaboradores.length" class="sem-colab">Nenhum colaborador ativo cadastrado.</div>
      </div>
    </div>

    <!-- VISÃO SEMANA -->
    <div v-if="visao === 'semana'" class="semana-grid">
      <div v-for="d in diasDaSemana" :key="d.iso" class="dia-card card" @click="irParaData(d.iso)">
        <span class="dia-card-dow">{{ d.diaSemana }}</span>
        <span class="dia-card-num">{{ d.dia }}</span>
        <span class="dia-card-contagem" v-if="contagemPorDia[d.iso]">{{ contagemPorDia[d.iso] }} atend.</span>
        <span class="dia-card-contagem vazio" v-else>Livre</span>
      </div>
    </div>

    <!-- VISÃO MÊS -->
    <div v-if="visao === 'mes'" class="card mes-wrap">
      <div class="mes-cabecalho">
        <span v-for="dow in ['D','S','T','Q','Q','S','S']" :key="dow">{{ dow }}</span>
      </div>
      <div class="mes-grid">
        <div v-for="(d, i) in diasDoMes" :key="i" class="mes-dia" :class="{ 'fora-mes': !d.noMes }" @click="d.noMes && irParaData(d.iso)">
          <span class="mes-dia-num">{{ d.dia }}</span>
          <span v-if="contagemPorDia[d.iso]" class="mes-dia-badge">{{ contagemPorDia[d.iso] }}</span>
        </div>
      </div>
    </div>

    <!-- MODAL: novo/editar agendamento -->
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
          <button v-if="editando?.id && podeAcao('agenda_cancelar')" class="btn btn-danger" @click="confirmarCancelamento(editando)">Cancelar agendamento</button>
          <button class="btn btn-ghost" @click="modalAberto = false">Fechar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: bloquear horário -->
    <div v-if="bloqueando" class="modal-backdrop" @click.self="bloqueando = null">
      <div class="modal" style="max-width:380px;">
        <h2 style="margin-bottom:16px;">Bloquear horário</h2>
        <p class="ajuda">{{ bloqueando.colaboradorNome }} — {{ dataAtualFormatada }}</p>
        <div style="display:flex; gap:12px;">
          <div class="field" style="flex:1;">
            <label>Início</label>
            <input v-model="bloqueando.inicio" type="time" class="input" />
          </div>
          <div class="field" style="flex:1;">
            <label>Fim</label>
            <input v-model="bloqueando.fim" type="time" class="input" />
          </div>
        </div>
        <div class="field">
          <label>Motivo (opcional)</label>
          <input v-model="bloqueando.motivo" class="input" placeholder="Ex.: Almoço, Compromisso pessoal" />
        </div>
        <p v-if="erro" class="erro-msg">{{ erro }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" @click="salvarBloqueio">Bloquear</button>
          <button class="btn btn-ghost" @click="bloqueando = null">Cancelar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: cancelar agendamento -->
    <div v-if="cancelando" class="modal-backdrop" @click.self="cancelando = null">
      <div class="modal" style="max-width:380px;">
        <h2 style="margin-bottom:10px;">Cancelar agendamento?</h2>
        <p style="color:var(--ink-muted); font-size:14px;">O horário voltará a ficar disponível.</p>
        <div style="display:flex; gap:10px; margin-top: 16px;">
          <button class="btn btn-danger" @click="cancelar">Cancelar agendamento</button>
          <button class="btn btn-ghost" @click="cancelando = null">Voltar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: liberar bloqueio -->
    <div v-if="liberando" class="modal-backdrop" @click.self="liberando = null">
      <div class="modal" style="max-width:380px;">
        <h2 style="margin-bottom:10px;">Liberar este horário?</h2>
        <p style="color:var(--ink-muted); font-size:14px;">O bloqueio será removido e o horário ficará disponível para agendamento.</p>
        <div style="display:flex; gap:10px; margin-top: 16px;">
          <button class="btn btn-primary" @click="confirmarLiberacao">Liberar horário</button>
          <button class="btn btn-ghost" @click="liberando = null">Voltar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { podeAcao } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

// ---------- constantes de grade ----------
const horaInicio = 7;
const horaFim = 21;
const pxPorMinuto = 1.2;
const alturaTotal = (horaFim - horaInicio) * 60 * pxPorMinuto;
const horasGrid = Array.from({ length: horaFim - horaInicio + 1 }, (_, i) => horaInicio + i);

// ---------- estado geral ----------
const visao = ref<"dia" | "semana" | "mes">("dia");
const hojeLocal = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};
const dataAtual = ref(hojeLocal());

const colaboradores = ref<any[]>([]);
const clientes = ref<any[]>([]);
const procedimentos = ref<any[]>([]);
const agendamentos = ref<any[]>([]);
const bloqueios = ref<any[]>([]);
const contagemPorDia = ref<Record<string, number>>({});

const modalAberto = ref(false);
const editando = ref<any>({ cliente_id: "", procedimento_id: "", colaborador_id: "", observacoes: "", status: "agendado" });
const editandoData = ref(dataAtual.value);
const editandoHora = ref("09:00");
const erro = ref("");
const cancelando = ref<any>(null);

const modoBloqueio = ref(false);
const bloqueando = ref<any>(null);
const liberando = ref<any>(null);

// ---------- utilidades de data ----------
const chaveLocal = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
const paraDate = (iso: string) => new Date(`${iso}T00:00:00`);
const somarDias = (iso: string, n: number) => { const d = paraDate(iso); d.setDate(d.getDate() + n); return chaveLocal(d); };
const somarMeses = (iso: string, n: number) => { const d = paraDate(iso); d.setMonth(d.getMonth() + n); return chaveLocal(d); };

const dataAtualFormatada = computed(() => paraDate(dataAtual.value).toLocaleDateString("pt-BR", { weekday: "short", day: "2-digit", month: "short" }));
const labelData = computed(() => {
  if (visao.value === "dia") return dataAtualFormatada.value;
  if (visao.value === "semana") {
    const ini = inicioSemana.value, fim = somarDias(ini, 6);
    return `${paraDate(ini).toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit" })} – ${paraDate(fim).toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit" })}`;
  }
  return paraDate(dataAtual.value).toLocaleDateString("pt-BR", { month: "long", year: "numeric" });
});

const inicioSemana = computed(() => {
  const d = paraDate(dataAtual.value);
  const diff = d.getDay();
  d.setDate(d.getDate() - diff);
  return chaveLocal(d);
});

const diasDaSemana = computed(() => {
  const nomes = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
  return Array.from({ length: 7 }, (_, i) => {
    const iso = somarDias(inicioSemana.value, i);
    const d = paraDate(iso);
    return { iso, dia: d.getDate(), diaSemana: nomes[d.getDay()] };
  });
});

const diasDoMes = computed(() => {
  const d = paraDate(dataAtual.value);
  const primeiro = new Date(d.getFullYear(), d.getMonth(), 1);
  const inicioGrade = new Date(primeiro);
  inicioGrade.setDate(inicioGrade.getDate() - primeiro.getDay());
  return Array.from({ length: 42 }, (_, i) => {
    const dia = new Date(inicioGrade);
    dia.setDate(dia.getDate() + i);
    return { iso: chaveLocal(dia), dia: dia.getDate(), noMes: dia.getMonth() === d.getMonth() };
  });
});

// ---------- navegação ----------
const navegar = (n: number) => {
  if (visao.value === "dia") dataAtual.value = somarDias(dataAtual.value, n);
  else if (visao.value === "semana") dataAtual.value = somarDias(dataAtual.value, n * 7);
  else dataAtual.value = somarMeses(dataAtual.value, n);
};
const irParaData = (iso: string) => { dataAtual.value = iso; visao.value = "dia"; };

// ---------- carregamento ----------
const carregarBase = async () => {
  const [{ data: col }, { data: cli }, { data: proc }] = await Promise.all([
    supabase.from("colaboradores").select("id, nome, foto_url").eq("ativo", true).order("nome"),
    supabase.from("clientes").select("id, nome").eq("ativo", true).order("nome"),
    supabase.from("procedimentos").select("id, nome, duracao_minutos").eq("ativo", true).order("nome"),
  ]);
  colaboradores.value = col || [];
  clientes.value = cli || [];
  procedimentos.value = proc || [];
};

const carregarPeriodo = async () => {
  let inicio: string, fim: string;
  if (visao.value === "dia") { inicio = dataAtual.value; fim = somarDias(dataAtual.value, 1); }
  else if (visao.value === "semana") { inicio = inicioSemana.value; fim = somarDias(inicioSemana.value, 7); }
  else { const d = diasDoMes.value; inicio = d[0].iso; fim = somarDias(d[d.length - 1].iso, 1); }

  const [{ data: ag }, { data: bl }] = await Promise.all([
    supabase
      .from("agendamentos")
      .select("*, clientes(nome), procedimentos(nome, duracao_minutos), colaboradores(nome)")
      .gte("data_hora", `${inicio}T00:00:00`)
      .lt("data_hora", `${fim}T00:00:00`)
      .order("data_hora"),
    supabase
      .from("bloqueios_horario")
      .select("*")
      .gte("data_inicio", `${inicio}T00:00:00`)
      .lt("data_inicio", `${fim}T00:00:00`),
  ]);
  agendamentos.value = ag || [];
  bloqueios.value = bl || [];

  const contagem: Record<string, number> = {};
  for (const a of agendamentos.value) {
    if (a.status === "cancelado") continue;
    const k = chaveLocal(new Date(a.data_hora));
    contagem[k] = (contagem[k] || 0) + 1;
  }
  contagemPorDia.value = contagem;
};

watch([visao, dataAtual], carregarPeriodo);

// ---------- helpers de exibição ----------
const iniciais = (nome: string) => (nome || "").trim().split(/\s+/).slice(0, 2).map((p) => p[0]?.toUpperCase()).join("") || "?";
const primeiroNome = (nome: string) => (nome || "").split(" ")[0];
const formatarHora = (v: string) => new Date(v).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });

const agendamentosDoColaborador = (colaboradorId: string) =>
  agendamentos.value.filter((a) => a.colaborador_id === colaboradorId && chaveLocal(new Date(a.data_hora)) === dataAtual.value && a.status !== "cancelado");

const bloqueiosDoColaborador = (colaboradorId: string) =>
  bloqueios.value.filter((b) => b.colaborador_id === colaboradorId && chaveLocal(new Date(b.data_inicio)) === dataAtual.value);

const minutosEntre = (a: string, b: string) => Math.max(15, (new Date(b).getTime() - new Date(a).getTime()) / 60000);

const posicao = (dataHora: string, duracaoMin: number) => {
  const d = new Date(dataHora);
  const minutosDoDia = d.getHours() * 60 + d.getMinutes();
  const top = (minutosDoDia - horaInicio * 60) * pxPorMinuto;
  const altura = Math.max(20, duracaoMin * pxPorMinuto - 2);
  return { top: top + "px", height: altura + "px" };
};

// ---------- clique na grade ----------
const minutoDoClique = (evt: MouseEvent) => {
  const alvo = evt.currentTarget as HTMLElement;
  const y = evt.clientY - alvo.getBoundingClientRect().top;
  const minutos = Math.round(y / pxPorMinuto / 15) * 15;
  return horaInicio * 60 + Math.max(0, minutos);
};

const cliqueGrade = (evt: MouseEvent, colaborador: any) => {
  const totalMin = minutoDoClique(evt);
  const hh = String(Math.floor(totalMin / 60)).padStart(2, "0");
  const mm = String(totalMin % 60).padStart(2, "0");
  const horaClicada = `${hh}:${mm}`;

  if (modoBloqueio.value) {
    if (!podeAcao("agenda_editar")) return;
    const fimMin = totalMin + 30;
    const fh = String(Math.floor(fimMin / 60)).padStart(2, "0");
    const fm = String(fimMin % 60).padStart(2, "0");
    bloqueando.value = { colaborador_id: colaborador.id, colaboradorNome: colaborador.nome, inicio: horaClicada, fim: `${fh}:${fm}`, motivo: "" };
    erro.value = "";
    return;
  }

  if (!podeAcao("agenda_criar")) return;
  abrirNovo(colaborador.id, horaClicada);
};

// ---------- CRUD agendamento ----------
const abrirNovo = (colaboradorId = "", hora = "09:00") => {
  editando.value = { cliente_id: "", procedimento_id: "", colaborador_id: colaboradorId, observacoes: "", status: "agendado" };
  editandoData.value = dataAtual.value;
  editandoHora.value = hora;
  erro.value = "";
  modalAberto.value = true;
};

const abrirEdicao = (a: any) => {
  editando.value = { ...a };
  const dt = new Date(a.data_hora);
  editandoData.value = chaveLocal(dt);
  editandoHora.value = dt.toTimeString().slice(0, 5);
  erro.value = "";
  modalAberto.value = true;
};

const salvar = async () => {
  if (!editando.value.cliente_id || !editando.value.procedimento_id || !editando.value.colaborador_id) {
    erro.value = "Selecione cliente, procedimento e colaborador.";
    return;
  }
  if (!editandoData.value || !editandoHora.value) { erro.value = "Informe a data e a hora."; return; }

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
  await carregarPeriodo();
  sucesso(ehEdicao ? "Agendamento atualizado com sucesso." : "Agendamento criado com sucesso.");
};

const confirmarCancelamento = (a: any) => { modalAberto.value = false; cancelando.value = a; };
const cancelar = async () => {
  const { error } = await supabase.from("agendamentos").update({ status: "cancelado" }).eq("id", cancelando.value.id);
  cancelando.value = null;
  if (error) { toastErro("Não foi possível cancelar o agendamento."); return; }
  await carregarPeriodo();
  sucesso("Agendamento cancelado com sucesso.");
};

// ---------- bloqueio de horários ----------
const salvarBloqueio = async () => {
  if (!bloqueando.value.inicio || !bloqueando.value.fim) { erro.value = "Informe início e fim."; return; }
  if (bloqueando.value.fim <= bloqueando.value.inicio) { erro.value = "O fim deve ser depois do início."; return; }
  const payload = {
    colaborador_id: bloqueando.value.colaborador_id,
    data_inicio: new Date(`${dataAtual.value}T${bloqueando.value.inicio}:00`).toISOString(),
    data_fim: new Date(`${dataAtual.value}T${bloqueando.value.fim}:00`).toISOString(),
    motivo: bloqueando.value.motivo || null,
  };
  const { error } = await supabase.from("bloqueios_horario").insert(payload);
  if (error) { erro.value = error.message; toastErro("Não foi possível bloquear o horário."); return; }
  bloqueando.value = null;
  await carregarPeriodo();
  sucesso("Horário bloqueado com sucesso.");
};

const liberarBloqueio = (b: any) => { liberando.value = b; };
const confirmarLiberacao = async () => {
  const { error } = await supabase.from("bloqueios_horario").delete().eq("id", liberando.value.id);
  liberando.value = null;
  if (error) { toastErro("Não foi possível liberar o horário."); return; }
  await carregarPeriodo();
  sucesso("Horário liberado com sucesso.");
};

await carregarBase();
await carregarPeriodo();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; gap: 12px; flex-wrap: wrap; }
.barra { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px; }
.visao-switch { display: flex; border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; }
.visao-switch button { border: none; background: #fff; padding: 8px 16px; font-size: 13px; font-weight: 500; color: var(--ink-muted); }
.visao-switch button.ativa { background: var(--primary); color: #fff; }
.navegacao { display: flex; align-items: center; gap: 10px; }
.data-label { min-width: 160px; text-align: center; font-size: 14px; text-transform: capitalize; }
.ajuda-bloqueio { color: var(--danger); font-size: 13px; margin: 0 0 10px; }
.ajuda { color: var(--ink-muted); font-size: 13px; margin: 0 0 14px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }

.dia-wrap { padding: 0; overflow-x: auto; }
.dia-grid { display: flex; min-width: 600px; }
.coluna-horas { width: 56px; flex-shrink: 0; position: sticky; left: 0; background: var(--surface); z-index: 2; border-right: 1px solid var(--border); }
.area-horas { position: relative; }
.marca-hora { position: absolute; right: 8px; transform: translateY(-50%); font-size: 11px; color: var(--ink-muted); }
.colab-header { height: 62px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; border-bottom: 1px solid var(--border); padding: 8px 4px; }
.colab-nome { font-size: 12px; font-weight: 600; white-space: nowrap; }
.coluna-colab { flex: 1; min-width: 170px; border-right: 1px solid var(--border); }
.area-colab { position: relative; cursor: pointer; }
.linha-hora { position: absolute; left: 0; right: 0; border-top: 1px dashed var(--border); }
.sem-colab { padding: 24px; color: var(--ink-muted); }

.bloco-agendamento {
  position: absolute; left: 3px; right: 3px;
  border-radius: 6px; padding: 4px 7px;
  font-size: 11px; line-height: 1.35;
  overflow: hidden; cursor: pointer;
  display: flex; flex-direction: column; gap: 1px;
  border-left: 3px solid var(--primary-dark);
  background: var(--primary-soft); color: var(--primary-dark);
}
.status-confirmado, .status-concluido { background: var(--success-soft); color: var(--success); border-left-color: var(--success); }
.status-agendado { background: var(--warning-soft); color: var(--warning); border-left-color: var(--warning); }
.bloco-agendamento strong { font-weight: 600; }

.bloco-bloqueio {
  position: absolute; left: 3px; right: 3px;
  border-radius: 6px; padding: 4px 7px;
  font-size: 11px; color: var(--ink-muted);
  cursor: pointer; overflow: hidden;
  display: flex; flex-direction: column;
  background: repeating-linear-gradient(45deg, #f0ece9, #f0ece9 6px, #f7f4f2 6px, #f7f4f2 12px);
  border: 1px dashed var(--border);
}

.semana-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 10px; }
.dia-card { padding: 16px 8px; text-align: center; cursor: pointer; display: flex; flex-direction: column; gap: 4px; }
.dia-card:hover { border-color: var(--primary); }
.dia-card-dow { font-size: 12px; color: var(--ink-muted); text-transform: uppercase; }
.dia-card-num { font-family: 'Fraunces', serif; font-size: 22px; font-weight: 600; }
.dia-card-contagem { font-size: 12px; color: var(--primary-dark); font-weight: 500; }
.dia-card-contagem.vazio { color: var(--ink-muted); font-weight: 400; }

.mes-wrap { padding: 16px; }
.mes-cabecalho { display: grid; grid-template-columns: repeat(7, 1fr); text-align: center; font-size: 12px; color: var(--ink-muted); margin-bottom: 8px; }
.mes-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px; }
.mes-dia { aspect-ratio: 1; border-radius: 8px; border: 1px solid var(--border); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; cursor: pointer; font-size: 13px; }
.mes-dia:hover { border-color: var(--primary); }
.mes-dia.fora-mes { opacity: 0.35; cursor: default; }
.mes-dia-badge { background: var(--primary); color: #fff; border-radius: 999px; font-size: 10px; padding: 1px 7px; }
</style>
