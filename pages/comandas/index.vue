<template>
  <div>
    <div class="cabecalho">
      <h1>Comandas</h1>
    </div>

    <div class="barra">
      <div class="visao-switch">
        <button :class="{ ativa: filtro === 'todas' }" @click="filtro = 'todas'">Todas</button>
        <button :class="{ ativa: filtro === 'abertas' }" @click="filtro = 'abertas'">Abertas</button>
        <button :class="{ ativa: filtro === 'pagas' }" @click="filtro = 'pagas'">Pagas</button>
      </div>
      <input v-model="busca" class="input" style="max-width:240px;" placeholder="Buscar por cliente" />
    </div>

    <div class="card tabela-wrap">
      <table>
        <thead>
          <tr>
            <th>Cliente</th>
            <th>Procedimento</th>
            <th>Colaborador</th>
            <th>Data</th>
            <th>Valor</th>
            <th>Status</th>
            <th>Pagamento</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in filtradas" :key="c.id">
            <td data-label="Cliente">{{ c.clientes?.nome || '—' }}</td>
            <td data-label="Procedimento">{{ c.procedimentos?.nome || '—' }}</td>
            <td data-label="Colaborador">{{ c.colaboradores?.nome || '—' }}</td>
            <td data-label="Data">{{ formatarData(c.data_hora) }}</td>
            <td data-label="Valor">{{ formatarValor(valorFinal(c)) }}</td>
            <td data-label="Status">
              <span :class="['badge', c.pago ? 'badge-success' : 'badge-warning']">
                {{ c.pago ? 'Paga' : 'Aberta' }}
              </span>
            </td>
            <td data-label="Pagamento">{{ c.pago ? labelPagamento(c) : '—' }}</td>
            <td style="text-align:right; white-space:nowrap;">
              <button v-if="podeAcao('comanda_registrar_pagamento') && c.forma_pagamento !== 'pacote'" class="btn btn-ghost" @click="abrirPagamento(c)">
                {{ c.pago ? 'Editar pagamento' : 'Registrar pagamento' }}
              </button>
              <button v-if="ehAdmin" class="btn btn-danger" @click="confirmarExclusaoComanda(c)">Excluir</button>
            </td>
          </tr>
          <tr v-if="!filtradas.length" class="linha-vazia"><td colspan="8" style="color:var(--ink-muted);">Nenhuma comanda encontrada.</td></tr>
        </tbody>
      </table>
    </div>

    <!-- MODAL: excluir comanda -->
    <ConfirmarExclusao
      v-if="excluindo"
      titulo="Excluir comanda?"
      :mensagem="excluindo.pago
        ? 'Esta comanda já está paga. Excluir vai apagar o agendamento, o pagamento registrado e a comissão gerada. Essa ação não pode ser desfeita.'
        : 'Essa ação não pode ser desfeita.'"
      :dupla="!!excluindo.pago"
      @confirmar="excluirComanda"
      @cancelar="excluindo = null"
    />

    <!-- MODAL: registrar pagamento -->
    <div v-if="pagando" class="modal-backdrop" @click.self="pagando = null">
      <div class="modal">
        <h2 style="margin-bottom:4px;">Registrar pagamento</h2>
        <p style="color:var(--ink-muted); font-size:13px; margin:0 0 16px;">
          {{ pagando.clientes?.nome }} · {{ pagando.procedimentos?.nome }}
        </p>

        <p style="font-size:14px; margin:0 0 10px;">
          Valor do procedimento: <strong>{{ formatarValor(pagando.procedimentos?.valor || 0) }}</strong>
        </p>

        <div v-if="saldoPacoteDisponivel.length" class="caixa-pacote">
          <p style="margin:0 0 6px;">
            Este cliente tem crédito de pacote para este procedimento
            (<strong>{{ saldoPacoteDisponivel[0].pacote_nome }}</strong>, válido até {{ formatarDataCurta(saldoPacoteDisponivel[0].data_validade) }}).
          </p>
          <button class="btn btn-primary" :disabled="salvandoPacote" @click="pagarComPacote">
            {{ salvandoPacote ? "Registrando..." : "Pagar com crédito do pacote" }}
          </button>
        </div>

        <template v-if="!saldoPacoteDisponivel.length || mostrarPagamentoNormal">
          <div class="field" v-if="podeAcao('comanda_aplicar_desconto')">
            <label>Desconto (R$)</label>
            <input v-model.number="pagamentoForm.valor_desconto" type="number" min="0" step="0.01" class="input" />
          </div>

          <label class="ajuda" style="display:block; margin-bottom:4px;">Forma(s) de pagamento</label>
          <FormaPagamentoMultipla v-model="pagamentoForm.pagamentos" :total="totalAPagar" />

          <p v-if="erro" class="erro-msg">{{ erro }}</p>
          <div style="display:flex; gap:10px;">
            <button class="btn btn-primary" :disabled="salvando" @click="salvarPagamento">{{ salvando ? 'Salvando...' : 'Confirmar pagamento' }}</button>
            <button class="btn btn-ghost" @click="pagando = null">Cancelar</button>
          </div>
        </template>
        <div v-else style="display:flex; gap:10px;">
          <button class="btn btn-ghost" @click="mostrarPagamentoNormal = true">Pagar de outra forma</button>
          <button class="btn btn-ghost" @click="pagando = null">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { podeAcao, ehAdmin } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const comandas = ref<any[]>([]);
const filtro = ref<"todas" | "abertas" | "pagas">("todas");
const busca = ref("");

const pagando = ref<any>(null);
const pagamentoForm = ref<any>({ valor_desconto: 0, pagamentos: [] as any[] });
const erro = ref("");
const salvando = ref(false);
const excluindo = ref<any>(null);
const saldoPacoteDisponivel = ref<any[]>([]);
const mostrarPagamentoNormal = ref(false);
const salvandoPacote = ref(false);

const carregar = async () => {
  const { data } = await supabase
    .from("agendamentos")
    .select("*, clientes(nome), colaboradores(nome), procedimentos(nome, valor)")
    .eq("status", "concluido")
    .order("data_hora", { ascending: false });
  comandas.value = data || [];
};

const valorFinal = (c: any) => (c.procedimentos?.valor || 0) - (c.valor_desconto || 0);
const totalAPagar = computed(() => (pagando.value?.procedimentos?.valor || 0) - (pagamentoForm.value.valor_desconto || 0));

const formatarValor = (v: number) =>
  (v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

const formatarData = (dataHora: string) => {
  const d = new Date(dataHora);
  return d.toLocaleDateString("pt-BR") + " " + d.toTimeString().slice(0, 5);
};

const formatarDataCurta = (data: string) => {
  if (!data) return "—";
  const [ano, mes, dia] = data.split("-");
  return `${dia}/${mes}/${ano}`;
};

const labelPagamento = (c: any) => {
  const labels: Record<string, string> = { debito: "Débito", credito: "Crédito", dinheiro: "Dinheiro", pix: "Pix", pacote: "Crédito de pacote" };
  if (!c.forma_pagamento) return "Múltiplas formas";
  let texto = labels[c.forma_pagamento] || c.forma_pagamento;
  if (c.forma_pagamento === "credito" && c.parcelas) texto += ` (${c.parcelas}x)`;
  return texto;
};

const filtradas = computed(() => {
  let lista = comandas.value;
  if (filtro.value === "abertas") lista = lista.filter((c) => !c.pago);
  if (filtro.value === "pagas") lista = lista.filter((c) => !!c.pago);
  const termo = busca.value.toLowerCase().trim();
  if (termo) lista = lista.filter((c) => (c.clientes?.nome || "").toLowerCase().includes(termo));
  return lista;
});

const abrirPagamento = async (c: any) => {
  pagando.value = c;
  erro.value = "";
  mostrarPagamentoNormal.value = false;
  saldoPacoteDisponivel.value = [];
  const valorDesconto = c.valor_desconto || 0;
  let pagamentosExistentes: any[] = [];
  if (c.pago) {
    const { data } = await supabase.from("pagamentos_comanda").select("*").eq("agendamento_id", c.id);
    pagamentosExistentes = (data || []).map((p: any) => ({ forma_pagamento: p.forma_pagamento, valor: p.valor, parcelas: p.parcelas || 1 }));
  }
  pagamentoForm.value = {
    valor_desconto: valorDesconto,
    pagamentos: pagamentosExistentes.length ? pagamentosExistentes : [{ forma_pagamento: "", valor: (c.procedimentos?.valor || 0) - valorDesconto, parcelas: 1 }],
  };

  if (!c.pago) {
    const { data } = await supabase
      .from("pacote_venda_itens")
      .select("id, quantidade_total, quantidade_usada, pacote_vendas!inner(id, pacote_nome, data_validade, status, cliente_id)")
      .eq("procedimento_id", c.procedimento_id)
      .eq("pacote_vendas.cliente_id", c.cliente_id)
      .eq("pacote_vendas.status", "ativo")
      .gte("pacote_vendas.data_validade", new Date().toISOString().slice(0, 10));
    saldoPacoteDisponivel.value = (data || [])
      .filter((i: any) => i.quantidade_usada < i.quantidade_total)
      .map((i: any) => ({ pacote_nome: i.pacote_vendas.pacote_nome, data_validade: i.pacote_vendas.data_validade }))
      .sort((a: any, b: any) => a.data_validade.localeCompare(b.data_validade));
  }
};

const pagarComPacote = async () => {
  salvandoPacote.value = true;
  const { error } = await supabase.rpc("registrar_pagamento_pacote", { p_agendamento_id: pagando.value.id });
  salvandoPacote.value = false;
  if (error) { toastErro(error.message || "Não foi possível usar o crédito do pacote."); return; }
  pagando.value = null;
  await carregar();
  sucesso("Pago com crédito do pacote.");
};

const salvarPagamento = async () => {
  const linhasValidas = (pagamentoForm.value.pagamentos || []).filter((p: any) => p.forma_pagamento && p.valor > 0);
  if (!linhasValidas.length) { erro.value = "Informe ao menos uma forma de pagamento com valor."; return; }
  const somado = linhasValidas.reduce((s: number, p: any) => s + Number(p.valor || 0), 0);
  if (Math.round((somado - totalAPagar.value) * 100) !== 0) {
    erro.value = "A soma das formas de pagamento precisa ser igual ao total a pagar.";
    return;
  }
  salvando.value = true;
  const { error } = await supabase.rpc("registrar_pagamento_comanda", {
    p_agendamento_id: pagando.value.id,
    p_pagamentos: linhasValidas.map((p: any) => ({
      forma_pagamento: p.forma_pagamento,
      valor: p.valor,
      parcelas: p.forma_pagamento === "credito" ? (p.parcelas || 1) : null,
    })),
    p_valor_desconto: podeAcao("comanda_aplicar_desconto") ? (pagamentoForm.value.valor_desconto || 0) : 0,
  });
  salvando.value = false;
  if (error) { erro.value = error.message; toastErro("Não foi possível registrar o pagamento."); return; }
  pagando.value = null;
  await carregar();
  sucesso("Pagamento registrado com sucesso.");
};

const confirmarExclusaoComanda = (c: any) => { excluindo.value = c; };
const excluirComanda = async () => {
  const { error } = await supabase.from("agendamentos").delete().eq("id", excluindo.value.id);
  excluindo.value = null;
  if (error) {
    toastErro(
      error.code === "23503"
        ? "Esta comanda está vinculada a outro registro e não pôde ser excluída."
        : `Não foi possível excluir a comanda: ${error.message}`
    );
    return;
  }
  await carregar();
  sucesso("Comanda excluída com sucesso.");
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.barra { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px; }
.visao-switch { display: flex; border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; }
.visao-switch button { border: none; background: #fff; padding: 8px 16px; font-size: 13px; font-weight: 500; color: var(--ink-muted); }
.visao-switch button.ativa { background: var(--primary); color: #fff; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
.caixa-pacote { background: var(--primary-soft); color: var(--primary-dark); border-radius: 8px; padding: 12px 14px; font-size: 13px; margin: 0 0 14px; }

@media (max-width: 640px) {
  .barra { flex-direction: column; align-items: stretch; }
  .visao-switch { width: 100%; }
  .visao-switch button { flex: 1; padding: 10px 0; }
  .barra .input { max-width: 100% !important; }
}
</style>
