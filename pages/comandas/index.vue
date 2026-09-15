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

    <div class="card" style="padding: 4px;">
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
            <td>{{ c.clientes?.nome || '—' }}</td>
            <td>{{ c.procedimentos?.nome || '—' }}</td>
            <td>{{ c.colaboradores?.nome || '—' }}</td>
            <td>{{ formatarData(c.data_hora) }}</td>
            <td>{{ formatarValor(valorFinal(c)) }}</td>
            <td>
              <span :class="['badge', c.pago ? 'badge-success' : 'badge-warning']">
                {{ c.pago ? 'Paga' : 'Aberta' }}
              </span>
            </td>
            <td>{{ c.pago ? labelPagamento(c) : '—' }}</td>
            <td style="text-align:right;">
              <button v-if="podeAcao('comanda_registrar_pagamento')" class="btn btn-ghost" @click="abrirPagamento(c)">
                {{ c.pago ? 'Editar pagamento' : 'Registrar pagamento' }}
              </button>
            </td>
          </tr>
          <tr v-if="!filtradas.length"><td colspan="8" style="color:var(--ink-muted);">Nenhuma comanda encontrada.</td></tr>
        </tbody>
      </table>
    </div>

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
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { podeAcao } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const comandas = ref<any[]>([]);
const filtro = ref<"todas" | "abertas" | "pagas">("todas");
const busca = ref("");

const pagando = ref<any>(null);
const pagamentoForm = ref<any>({ valor_desconto: 0, pagamentos: [] as any[] });
const erro = ref("");
const salvando = ref(false);

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

const labelPagamento = (c: any) => {
  const labels: Record<string, string> = { debito: "Débito", credito: "Crédito", dinheiro: "Dinheiro", pix: "Pix" };
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

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.barra { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; flex-wrap: wrap; gap: 10px; }
.visao-switch { display: flex; border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; }
.visao-switch button { border: none; background: #fff; padding: 8px 16px; font-size: 13px; font-weight: 500; color: var(--ink-muted); }
.visao-switch button.ativa { background: var(--primary); color: #fff; }
.erro-msg { color: var(--danger); font-size: 13px; margin: -6px 0 10px; }
</style>
