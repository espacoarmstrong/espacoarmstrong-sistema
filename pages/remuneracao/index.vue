<template>
  <div>
    <div class="cabecalho">
      <h1>Remuneração</h1>
    </div>

    <div class="abas">
      <button :class="['aba', { ativa: aba === 'pendentes' }]" @click="aba = 'pendentes'">Pendentes</button>
      <button :class="['aba', { ativa: aba === 'historico' }]" @click="aba = 'historico'">Histórico de pagamentos</button>
    </div>

    <!-- PENDENTES -->
    <div v-if="aba === 'pendentes'" class="card tabela-wrap">
      <table>
        <thead>
          <tr><th>Colaborador</th><th>Atendimentos pendentes</th><th>Comissão pendente</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="r in resumoPorColaborador" :key="r.colaborador_id">
            <td data-label="Colaborador">{{ r.nome }}</td>
            <td data-label="Atendimentos pendentes">{{ r.itens.length }}</td>
            <td data-label="Comissão pendente">{{ formatarValor(r.total) }}</td>
            <td style="text-align:right;">
              <button class="btn btn-ghost" :disabled="!r.itens.length" @click="abrirDescricao(r)">Descrição</button>
              <button v-if="podeAcao('remuneracao_pagar')" class="btn btn-ghost" :disabled="!r.itens.length" @click="abrirPagamento(r)">
                Registrar pagamento
              </button>
            </td>
          </tr>
          <tr v-if="!resumoPorColaborador.length" class="linha-vazia"><td colspan="4" style="color:var(--ink-muted);">Nenhuma comissão pendente.</td></tr>
        </tbody>
      </table>
    </div>

    <!-- HISTÓRICO -->
    <div v-if="aba === 'historico'" class="card tabela-wrap">
      <table>
        <thead>
          <tr><th>Colaborador</th><th>Data</th><th>Valor</th><th>Observações</th></tr>
        </thead>
        <tbody>
          <tr v-for="p in pagamentos" :key="p.id">
            <td data-label="Colaborador">{{ p.colaboradores?.nome || '—' }}</td>
            <td data-label="Data">{{ formatarData(p.pago_em) }}</td>
            <td data-label="Valor">{{ formatarValor(p.valor_total) }}</td>
            <td data-label="Observações">{{ p.observacoes || '—' }}</td>
          </tr>
          <tr v-if="!pagamentos.length" class="linha-vazia"><td colspan="4" style="color:var(--ink-muted);">Nenhum pagamento registrado ainda.</td></tr>
        </tbody>
      </table>
    </div>

    <!-- MODAL: descrição -->
    <div v-if="detalhando" class="modal-backdrop" @click.self="detalhando = null">
      <div class="modal">
        <h2 style="margin-bottom:4px;">Descrição dos atendimentos</h2>
        <p style="color:var(--ink-muted); font-size:13px; margin:0 0 16px;">{{ detalhando.nome }}</p>

        <div class="card tabela-wrap">
          <table>
            <thead>
              <tr><th>Data</th><th>Procedimento</th><th>Valor do procedimento</th><th>% remuneração</th><th>Comissão</th></tr>
            </thead>
            <tbody>
              <tr v-for="item in detalhando.itens" :key="item.id">
                <td data-label="Data">{{ formatarData(item.data_hora) }}</td>
                <td data-label="Procedimento">{{ item.procedimentos?.nome || '—' }}</td>
                <td data-label="Valor do procedimento">{{ formatarValor(item.procedimentos?.valor || 0) }}</td>
                <td data-label="% remuneração">{{ item.percentual_comissao ?? 0 }}%</td>
                <td data-label="Comissão">{{ formatarValor(item.valor_comissao) }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div style="display:flex; gap:10px; margin-top: 16px;">
          <button class="btn btn-ghost" @click="detalhando = null">Fechar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: registrar pagamento -->
    <div v-if="pagando" class="modal-backdrop" @click.self="pagando = null">
      <div class="modal">
        <h2 style="margin-bottom:4px;">Registrar pagamento</h2>
        <p style="color:var(--ink-muted); font-size:13px; margin:0 0 16px;">{{ pagando.nome }}</p>

        <div class="lista-itens">
          <label v-for="item in pagando.itens" :key="item.id" class="linha-check">
            <input type="checkbox" v-model="selecionados" :value="item.id" />
            <span style="flex:1;">{{ formatarData(item.data_hora) }} · {{ item.procedimentos?.nome || '—' }} · {{ item.clientes?.nome || '—' }}</span>
            <span>{{ formatarValor(item.valor_comissao) }}</span>
          </label>
        </div>

        <p style="font-size:14px; margin:14px 0;">
          Total selecionado: <strong>{{ formatarValor(totalSelecionado) }}</strong>
        </p>

        <div class="field">
          <label>Observações (opcional)</label>
          <textarea v-model="observacoes" class="input" rows="2"></textarea>
        </div>

        <p v-if="erro" class="erro-msg">{{ erro }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" :disabled="salvando || !selecionados.length" @click="salvarPagamento">
            {{ salvando ? "Salvando..." : "Confirmar pagamento" }}
          </button>
          <button class="btn btn-ghost" @click="pagando = null">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { podeAcao } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const aba = ref<"pendentes" | "historico">("pendentes");
const itensPendentes = ref<any[]>([]);
const pagamentos = ref<any[]>([]);

const pagando = ref<any>(null);
const detalhando = ref<any>(null);
const selecionados = ref<string[]>([]);
const observacoes = ref("");
const erro = ref("");
const salvando = ref(false);

const carregarPendentes = async () => {
  const { data } = await supabase
    .from("agendamentos")
    .select("*, colaboradores(nome), procedimentos(nome, valor), clientes(nome)")
    .eq("pago", true)
    .not("valor_comissao", "is", null)
    .is("remuneracao_pagamento_id", null)
    .order("data_hora", { ascending: true });
  itensPendentes.value = data || [];
};

const carregarHistorico = async () => {
  const { data } = await supabase
    .from("remuneracoes_pagamentos")
    .select("*, colaboradores(nome)")
    .order("pago_em", { ascending: false });
  pagamentos.value = data || [];
};

const resumoPorColaborador = computed(() => {
  const mapa: Record<string, any> = {};
  for (const item of itensPendentes.value) {
    const id = item.colaborador_id;
    if (!mapa[id]) mapa[id] = { colaborador_id: id, nome: item.colaboradores?.nome || "—", itens: [], total: 0 };
    mapa[id].itens.push(item);
    mapa[id].total += Number(item.valor_comissao || 0);
  }
  return Object.values(mapa).sort((a: any, b: any) => a.nome.localeCompare(b.nome));
});

const totalSelecionado = computed(() =>
  (pagando.value?.itens || [])
    .filter((i: any) => selecionados.value.includes(i.id))
    .reduce((soma: number, i: any) => soma + Number(i.valor_comissao || 0), 0)
);

const abrirDescricao = (r: any) => {
  detalhando.value = r;
};

const abrirPagamento = (r: any) => {
  pagando.value = r;
  selecionados.value = r.itens.map((i: any) => i.id);
  observacoes.value = "";
  erro.value = "";
};

const salvarPagamento = async () => {
  salvando.value = true;
  erro.value = "";
  const { error } = await supabase.rpc("registrar_remuneracao", {
    p_colaborador_id: pagando.value.colaborador_id,
    p_agendamento_ids: selecionados.value,
    p_observacoes: observacoes.value || null,
  });
  salvando.value = false;
  if (error) {
    erro.value = error.message;
    toastErro("Não foi possível registrar o pagamento.");
    return;
  }
  pagando.value = null;
  await Promise.all([carregarPendentes(), carregarHistorico()]);
  sucesso("Pagamento de remuneração registrado com sucesso.");
};

const formatarValor = (v: number) => (v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
const formatarData = (dataHora: string) => {
  const d = new Date(dataHora);
  return d.toLocaleDateString("pt-BR") + " " + d.toTimeString().slice(0, 5);
};

await Promise.all([carregarPendentes(), carregarHistorico()]);
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.abas { display: flex; gap: 4px; border-bottom: 1px solid var(--border); margin-bottom: 16px; }
.aba { padding: 10px 16px; border: none; background: none; font-size: 14px; font-weight: 500; color: var(--ink-muted); border-bottom: 2px solid transparent; }
.aba.ativa { color: var(--primary-dark); border-bottom-color: var(--primary); }
.lista-itens { max-height: 260px; overflow-y: auto; display: flex; flex-direction: column; gap: 4px; }
.linha-check { display: flex; align-items: center; gap: 10px; font-size: 13px; padding: 6px 2px; border-bottom: 1px solid var(--border); }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }

@media (max-width: 640px) {
  .aba { padding: 10px 12px; font-size: 13px; }
  /* itens do pagamento: descrição quebra em várias linhas, valor não encolhe */
  .linha-check { align-items: flex-start; padding: 10px 2px; line-height: 1.4; }
  .linha-check > span:last-of-type { flex-shrink: 0; font-weight: 600; }
  .lista-itens { max-height: 50vh; }
}
</style>
