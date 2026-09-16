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
      <div v-for="d in diasDaSemana" :key="d.iso" class="dia-card card">
        <div class="dia-card-cabeca" @click="irParaData(d.iso)">
          <span class="dia-card-dow">{{ d.diaSemana }}</span>
          <span class="dia-card-num">{{ d.dia }}</span>
        </div>
        <div class="dia-card-lista">
          <div
            v-for="a in agendamentosPorDia(d.iso)"
            :key="a.id"
            class="dia-card-item"
            :class="'status-' + a.status"
            @click="abrirEdicao(a)"
          >
            <strong>{{ formatarHora(a.data_hora) }}</strong> {{ a.clientes?.nome || '—' }}
            <small>{{ primeiroNome(a.colaboradores?.nome || '') }} · {{ a.procedimentos?.nome || '—' }}</small>
          </div>
          <span v-if="!agendamentosPorDia(d.iso).length" class="dia-card-vazio">Livre</span>
        </div>
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
          <SeletorCliente v-model="editando.cliente_id" :clientes="clientes" />
        </div>
        <div class="field">
          <label>Categoria</label>
          <select v-model="editandoCategoriaId" class="input" @change="editando.procedimento_id = ''">
            <option value="" disabled>Selecione</option>
            <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nome }}</option>
          </select>
        </div>
        <div class="field">
          <label>Procedimento</label>
          <select v-model="editando.procedimento_id" class="input" :disabled="!editandoCategoriaId">
            <option value="" disabled>{{ editandoCategoriaId ? 'Selecione' : 'Escolha a categoria primeiro' }}</option>
            <option v-for="p in procedimentosDaCategoria" :key="p.id" :value="p.id">{{ p.nome }} ({{ p.duracao_minutos }} min)</option>
          </select>
          <p v-if="procedimentoSelecionado" class="valor-procedimento">Valor do procedimento: <strong>{{ formatarValor(procedimentoSelecionado.valor) }}</strong></p>
        </div>
        <div class="field">
          <label>Colaborador</label>
          <select v-model="editando.colaborador_id" class="input">
            <option value="" disabled>Selecione</option>
            <option v-for="c in colaboradores" :key="c.id" :value="c.id">{{ c.nome }}</option>
          </select>
        </div>
        <div class="linha-dupla">
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
            <option value="cancelado">Cancelado</option>
          </select>
        </div>

        <div class="field" v-if="editando?.status === 'cancelado'">
          <label>Motivo do cancelamento</label>
          <textarea v-model="editando.motivo_cancelamento" class="input" rows="2" placeholder="Ex.: Cliente desmarcou, imprevisto do colaborador..."></textarea>
        </div>

        <div v-if="editando.forma_pagamento === 'pacote'" class="aviso-pacote">
          Pago com crédito de pacote. Para alterar, exclua e recrie o pagamento em Comandas.
        </div>
        <template v-else>
          <div v-if="saldoPacoteDisponivel.length" class="caixa-pacote">
            <p style="margin:0 0 6px;">
              Este cliente tem crédito de pacote para este procedimento
              (<strong>{{ saldoPacoteDisponivel[0].pacote_nome }}</strong>, válido até {{ formatarDataCurta(saldoPacoteDisponivel[0].data_validade) }}).
            </p>
            <label class="linha-check" style="padding:0;">
              <input type="checkbox" v-model="usarPacote" />
              Pagar com crédito do pacote{{ editando?.status === 'concluido' ? ' (sem cobrar valor agora)' : ' (já reservar o crédito para este agendamento)' }}
            </label>
          </div>

          <template v-if="!usarPacote && editando?.status === 'concluido'">
            <div class="field" v-if="podeAcao('comanda_aplicar_desconto')">
              <label>Desconto (R$)</label>
              <input v-model.number="editandoDesconto" type="number" min="0" step="0.01" class="input" />
              <p class="valor-procedimento">Total a pagar: <strong>{{ formatarValor(totalAPagarEdicao) }}</strong></p>
            </div>
            <div class="field">
              <label>Pagamento (opcional — pode registrar depois em Comandas)</label>
              <FormaPagamentoMultipla v-if="mostrarPagamento" v-model="editandoPagamentos" :total="totalAPagarEdicao" />
              <button v-else type="button" class="btn btn-ghost" style="padding:6px 10px; font-size:13px;" @click="mostrarPagamento = true">+ Registrar pagamento agora</button>
            </div>
          </template>
        </template>

        <div class="field">
          <label>Observações</label>
          <textarea v-model="editando.observacoes" class="input" rows="2"></textarea>
        </div>
        <p v-if="erro" class="erro-msg">{{ erro }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px; flex-wrap: wrap;">
          <button class="btn btn-primary" @click="salvar">Salvar</button>
          <button v-if="editando?.id && podeAcao('agenda_cancelar') && editando.status !== 'cancelado'" class="btn btn-danger" @click="editando.status = 'cancelado'">Cancelar agendamento</button>
          <button v-if="editando?.id && ehAdmin" class="btn btn-danger" @click="confirmarExclusaoAgendamento(editando)">Excluir agendamento</button>
          <button class="btn btn-ghost" @click="modalAberto = false">Fechar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: excluir agendamento -->
    <ConfirmarExclusao
      v-if="excluindo"
      titulo="Excluir agendamento?"
      :mensagem="excluindo.pago
        ? 'Este atendimento já foi concluído e pago. Excluir vai apagar também o registro de pagamento e a comissão gerada. Essa ação não pode ser desfeita.'
        : 'Essa ação não pode ser desfeita.'"
      :dupla="!!excluindo.pago"
      @confirmar="excluirAgendamento"
      @cancelar="excluindo = null"
    />

    <!-- MODAL: bloquear horário -->
    <div v-if="bloqueando" class="modal-backdrop" @click.self="bloqueando = null">
      <div class="modal" style="max-width:380px;">
        <h2 style="margin-bottom:16px;">Bloquear horário</h2>
        <p class="ajuda">{{ bloqueando.colaboradorNome }} — {{ dataAtualFormatada }}</p>
        <div class="linha-dupla">
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
const { podeAcao, ehAdmin } = useUsuario();
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
const categorias = ref<any[]>([]);
const editandoCategoriaId = ref("");
const agendamentos = ref<any[]>([]);
const bloqueios = ref<any[]>([]);
const contagemPorDia = ref<Record<string, number>>({});

const modalAberto = ref(false);
const editando = ref<any>({ cliente_id: "", procedimento_id: "", colaborador_id: "", observacoes: "", status: "agendado", motivo_cancelamento: "" });
const editandoData = ref(dataAtual.value);
const editandoHora = ref("09:00");
const editandoPagamentos = ref<any[]>([]);
const editandoDesconto = ref(0);
const mostrarPagamento = ref(false);
const erro = ref("");
const excluindo = ref<any>(null);
const usarPacote = ref(false);
const saldoPacoteDisponivel = ref<any[]>([]);

const procedimentoSelecionado = computed(() => procedimentos.value.find((p) => p.id === editando.value.procedimento_id));
const procedimentosDaCategoria = computed(() => procedimentos.value.filter((p) => p.categoria_id === editandoCategoriaId.value));
const totalAPagarEdicao = computed(() => (procedimentoSelecionado.value?.valor || 0) - (editandoDesconto.value || 0));
const formatarValor = (v: number) => (v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
const formatarDataCurta = (data: string) => {
  if (!data) return "—";
  const [ano, mes, dia] = data.split("-");
  return `${dia}/${mes}/${ano}`;
};

const verificarSaldoPacote = async () => {
  usarPacote.value = false;
  saldoPacoteDisponivel.value = [];
  if (editando.value.forma_pagamento === "pacote") return;
  if (!editando.value.cliente_id || !editando.value.procedimento_id) return;
  const { data } = await supabase
    .from("pacote_venda_itens")
    .select("id, quantidade_total, quantidade_usada, pacote_vendas!inner(id, pacote_nome, data_validade, status, cliente_id)")
    .eq("procedimento_id", editando.value.procedimento_id)
    .eq("pacote_vendas.cliente_id", editando.value.cliente_id)
    .eq("pacote_vendas.status", "ativo")
    .gte("pacote_vendas.data_validade", new Date().toISOString().slice(0, 10));
  saldoPacoteDisponivel.value = (data || [])
    .filter((i: any) => i.quantidade_usada < i.quantidade_total)
    .map((i: any) => ({ pacote_nome: i.pacote_vendas.pacote_nome, data_validade: i.pacote_vendas.data_validade }))
    .sort((a: any, b: any) => a.data_validade.localeCompare(b.data_validade));
};

watch(() => [editando.value?.status, editando.value?.cliente_id, editando.value?.procedimento_id], verificarSaldoPacote);

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
  const [{ data: col }, { data: cli }, { data: proc }, { data: cat }] = await Promise.all([
    supabase.from("colaboradores").select("id, nome, foto_url").eq("ativo", true).order("nome"),
    supabase.from("clientes").select("id, nome, telefone").eq("ativo", true).order("nome"),
    supabase.from("procedimentos").select("id, nome, categoria_id, duracao_minutos, valor").eq("ativo", true).order("nome"),
    supabase.from("categorias").select("id, nome").eq("ativo", true).order("nome"),
  ]);
  colaboradores.value = col || [];
  clientes.value = cli || [];
  procedimentos.value = proc || [];
  categorias.value = cat || [];
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

const agendamentosPorDia = (iso: string) =>
  agendamentos.value
    .filter((a) => chaveLocal(new Date(a.data_hora)) === iso)
    .sort((a, b) => a.data_hora.localeCompare(b.data_hora));

const agendamentosDoColaborador = (colaboradorId: string) =>
  agendamentos.value.filter((a) => a.colaborador_id === colaboradorId && chaveLocal(new Date(a.data_hora)) === dataAtual.value);

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
  editando.value = { cliente_id: "", procedimento_id: "", colaborador_id: colaboradorId, observacoes: "", status: "agendado", motivo_cancelamento: "" };
  editandoCategoriaId.value = "";
  editandoData.value = dataAtual.value;
  editandoHora.value = hora;
  editandoPagamentos.value = [];
  editandoDesconto.value = 0;
  mostrarPagamento.value = false;
  usarPacote.value = false;
  saldoPacoteDisponivel.value = [];
  erro.value = "";
  modalAberto.value = true;
};

const abrirEdicao = async (a: any) => {
  editando.value = { ...a, motivo_cancelamento: a.motivo_cancelamento || "" };
  editandoCategoriaId.value = procedimentos.value.find((p) => p.id === a.procedimento_id)?.categoria_id || "";
  const dt = new Date(a.data_hora);
  editandoData.value = chaveLocal(dt);
  editandoHora.value = dt.toTimeString().slice(0, 5);
  erro.value = "";
  editandoPagamentos.value = [];
  editandoDesconto.value = a.valor_desconto || 0;
  mostrarPagamento.value = false;
  usarPacote.value = false;
  saldoPacoteDisponivel.value = [];
  if (a.status === "concluido" && a.pago) {
    const { data } = await supabase.from("pagamentos_comanda").select("*").eq("agendamento_id", a.id);
    editandoPagamentos.value = (data || []).map((p: any) => ({ forma_pagamento: p.forma_pagamento, valor: p.valor, parcelas: p.parcelas || 1 }));
    mostrarPagamento.value = true;
  }
  modalAberto.value = true;
};

const salvar = async () => {
  if (!editando.value.cliente_id || !editando.value.procedimento_id || !editando.value.colaborador_id) {
    erro.value = "Selecione cliente, procedimento e colaborador.";
    return;
  }
  if (!editandoData.value || !editandoHora.value) { erro.value = "Informe a data e a hora."; return; }
  if (editando.value.status === "cancelado" && !editando.value.motivo_cancelamento?.trim()) {
    erro.value = "Informe o motivo do cancelamento.";
    return;
  }

  const linhasValidas = usarPacote.value ? [] : (editandoPagamentos.value || []).filter((p: any) => p.forma_pagamento && p.valor > 0);
  if (!usarPacote.value && mostrarPagamento.value && linhasValidas.length) {
    const somado = linhasValidas.reduce((s: number, p: any) => s + Number(p.valor || 0), 0);
    const total = totalAPagarEdicao.value;
    if (Math.round((somado - total) * 100) !== 0) {
      erro.value = "A soma das formas de pagamento precisa ser igual ao valor do procedimento.";
      return;
    }
  }

  const dataHora = new Date(`${editandoData.value}T${editandoHora.value}:00`).toISOString();
  const ehEdicao = !!editando.value.id;
  const idAlvo = ehEdicao ? editando.value.id : crypto.randomUUID();
  const payload: any = {
    id: idAlvo,
    cliente_id: editando.value.cliente_id,
    procedimento_id: editando.value.procedimento_id,
    colaborador_id: editando.value.colaborador_id,
    data_hora: dataHora,
    observacoes: editando.value.observacoes,
    status: editando.value.status || "agendado",
    motivo_cancelamento: editando.value.status === "cancelado" ? editando.value.motivo_cancelamento : null,
  };
  const query = ehEdicao
    ? supabase.from("agendamentos").update(payload).eq("id", idAlvo)
    : supabase.from("agendamentos").insert(payload);
  const { error } = await query;
  if (error) { erro.value = error.message; toastErro("Não foi possível salvar o agendamento."); return; }

  if (usarPacote.value) {
    const { error: erroPacote } = await supabase.rpc("registrar_pagamento_pacote", { p_agendamento_id: idAlvo });
    if (erroPacote) { erro.value = erroPacote.message; toastErro("Agendamento salvo, mas o crédito do pacote não pôde ser usado."); return; }
  } else if (editando.value.status === "concluido" && linhasValidas.length) {
    const { error: erroPagamento } = await supabase.rpc("registrar_pagamento_comanda", {
      p_agendamento_id: idAlvo,
      p_pagamentos: linhasValidas.map((p: any) => ({
        forma_pagamento: p.forma_pagamento,
        valor: p.valor,
        parcelas: p.forma_pagamento === "credito" ? (p.parcelas || 1) : null,
      })),
      p_valor_desconto: podeAcao("comanda_aplicar_desconto") ? (editandoDesconto.value || 0) : 0,
    });
    if (erroPagamento) { erro.value = erroPagamento.message; toastErro("Agendamento salvo, mas o pagamento não pôde ser registrado."); return; }
  }

  modalAberto.value = false;
  await carregarPeriodo();
  sucesso(ehEdicao ? "Agendamento atualizado com sucesso." : "Agendamento criado com sucesso.");
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

// ---------- excluir agendamento ----------
const confirmarExclusaoAgendamento = (a: any) => {
  modalAberto.value = false;
  excluindo.value = a;
};
const excluirAgendamento = async () => {
  const { error } = await supabase.from("agendamentos").delete().eq("id", excluindo.value.id);
  excluindo.value = null;
  if (error) { toastErro("Não foi possível excluir o agendamento."); return; }
  await carregarPeriodo();
  sucesso("Agendamento excluído com sucesso.");
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
.valor-procedimento { font-size: 13px; color: var(--primary-dark); margin: 6px 0 0; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
.caixa-pacote { background: var(--primary-soft); color: var(--primary-dark); border-radius: 8px; padding: 12px 14px; font-size: 13px; margin: 0 0 14px; }
.aviso-pacote { background: var(--primary-soft); color: var(--primary-dark); border-radius: 8px; padding: 10px 14px; font-size: 13px; margin: 0 0 14px; }

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
.status-confirmado { background: var(--info-soft); color: var(--info); border-left-color: var(--info); }
.status-concluido { background: var(--success-soft); color: var(--success); border-left-color: var(--success); }
.status-agendado { background: var(--warning-soft); color: var(--warning); border-left-color: var(--warning); }
.status-cancelado { background: var(--danger-soft); color: var(--danger); border-left-color: var(--danger); text-decoration: line-through; opacity: 0.75; }
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

.semana-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 10px; align-items: start; }
.dia-card { padding: 0; display: flex; flex-direction: column; gap: 0; overflow: hidden; }
.dia-card-cabeca { padding: 10px 8px; text-align: center; cursor: pointer; border-bottom: 1px solid var(--border); }
.dia-card-cabeca:hover { background: var(--bg); }
.dia-card-dow { display: block; font-size: 11px; color: var(--ink-muted); text-transform: uppercase; }
.dia-card-num { display: block; font-family: 'Fraunces', serif; font-size: 20px; font-weight: 600; }
.dia-card-lista { padding: 6px; display: flex; flex-direction: column; gap: 4px; min-height: 60px; max-height: 420px; overflow-y: auto; }
.dia-card-item { padding: 5px 6px; border-radius: 6px; font-size: 11px; line-height: 1.3; cursor: pointer; border-left: 3px solid var(--primary-dark); background: var(--primary-soft); color: var(--primary-dark); }
.dia-card-item small { display: block; opacity: 0.85; }
.dia-card-item.status-confirmado { background: var(--info-soft); color: var(--info); border-left-color: var(--info); }
.dia-card-item.status-concluido { background: var(--success-soft); color: var(--success); border-left-color: var(--success); }
.dia-card-item.status-agendado { background: var(--warning-soft); color: var(--warning); border-left-color: var(--warning); }
.dia-card-item.status-cancelado { background: var(--danger-soft); color: var(--danger); border-left-color: var(--danger); text-decoration: line-through; opacity: 0.75; }
.dia-card-vazio { display: block; text-align: center; font-size: 12px; color: var(--ink-muted); padding: 10px 0; }

.mes-wrap { padding: 16px; }
.mes-cabecalho { display: grid; grid-template-columns: repeat(7, 1fr); text-align: center; font-size: 12px; color: var(--ink-muted); margin-bottom: 8px; }
.mes-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px; }
.mes-dia { aspect-ratio: 1; border-radius: 8px; border: 1px solid var(--border); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; cursor: pointer; font-size: 13px; }
.mes-dia:hover { border-color: var(--primary); }
.mes-dia.fora-mes { opacity: 0.35; cursor: default; }
.mes-dia-badge { background: var(--primary); color: #fff; border-radius: 999px; font-size: 10px; padding: 1px 7px; }

/* ---------- MOBILE ---------- */
@media (max-width: 640px) {
  .cabecalho > div { width: 100%; }
  .cabecalho > div .btn { flex: 1 1 auto; justify-content: center; }

  .barra { flex-direction: column; align-items: stretch; }
  .visao-switch { width: 100%; }
  .visao-switch button { flex: 1; padding: 10px 0; }
  .navegacao { display: grid; grid-template-columns: auto 1fr auto; gap: 8px; align-items: center; }
  .navegacao .input[type="date"] { grid-column: 1 / -1; width: 100% !important; }
  .data-label { min-width: 0; }

  /* Semana: rolagem horizontal com largura mínima legível por dia,
     em vez de 7 colunas espremidas. */
  .semana-grid {
    grid-template-columns: none;
    grid-auto-flow: column;
    grid-auto-columns: minmax(180px, 1fr);
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    scroll-snap-type: x mandatory;
    padding-bottom: 6px;
  }
  .semana-grid .dia-card { scroll-snap-align: start; }
  .dia-card-item { font-size: 12px; padding: 7px 8px; }
  .dia-card-lista { max-height: none; }

  /* Dia: colunas um pouco mais estreitas, mas ainda legíveis */
  .dia-grid { min-width: 0; }
  .coluna-colab { min-width: 150px; }
  .bloco-agendamento, .bloco-bloqueio { font-size: 11px; }

  .mes-wrap { padding: 10px; }
  .mes-grid { gap: 4px; }
  .mes-dia { font-size: 12px; }
}
</style>
