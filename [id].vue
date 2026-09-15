<template>
  <div v-if="cliente">
    <div class="cabecalho">
      <div>
        <NuxtLink to="/clientes" class="voltar">← Clientes</NuxtLink>
        <h1>{{ cliente.nome }}</h1>
      </div>
    </div>

    <div class="card resumo">
      <div>
        <span class="resumo-label">Telefone</span>
        <p>{{ cliente.telefone || '—' }}</p>
      </div>
      <div v-if="podeAcao('comanda_visualizar')">
        <span class="resumo-label">Total pago</span>
        <p class="resumo-valor">{{ formatarValor(totalPago) }}</p>
      </div>
      <div>
        <span class="resumo-label">Atendimentos concluídos</span>
        <p>{{ historico.filter(h => h.status === 'concluido').length }}</p>
      </div>
    </div>

    <template v-if="podeAcaoPacotes && pacotesCliente.length">
      <h3 class="subtitulo">Pacotes</h3>
      <div class="card tabela-wrap" style="margin-bottom:24px;">
        <table>
          <thead>
            <tr><th>Pacote</th><th>Compra</th><th>Validade</th><th>Saldo</th><th>Status</th></tr>
          </thead>
          <tbody>
            <tr v-for="v in pacotesCliente" :key="v.id">
              <td>{{ v.pacote_nome }}</td>
              <td>{{ formatarData(v.data_compra) }}</td>
              <td>{{ formatarDataCurta(v.data_validade) }}</td>
              <td>
                <div v-for="item in v.pacote_venda_itens" :key="item.id" class="saldo-linha">
                  {{ item.procedimento_nome }}: {{ item.quantidade_total - item.quantidade_usada }}/{{ item.quantidade_total }}
                </div>
              </td>
              <td><span :class="['badge', badgeVenda(v).classe]">{{ badgeVenda(v).texto }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <h3 class="subtitulo">Histórico de procedimentos</h3>
    <div class="card tabela-wrap">
      <table>
        <thead>
          <tr>
            <th>Data</th>
            <th>Procedimento</th>
            <th>Colaborador</th>
            <th>Status</th>
            <th v-if="podeAcao('comanda_visualizar')">Pagamento</th>
            <th v-if="podeAcao('comanda_visualizar')">Valor</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="h in historico" :key="h.id">
            <td>{{ formatarData(h.data_hora) }}</td>
            <td>{{ h.procedimentos?.nome || '—' }}</td>
            <td>{{ h.colaboradores?.nome || '—' }}</td>
            <td><span :class="['badge', badgeClasse(h.status)]">{{ labelStatus(h.status) }}</span></td>
            <td v-if="podeAcao('comanda_visualizar')">{{ h.pago ? labelPagamento(h) : (h.status === 'cancelado' ? '—' : 'Em aberto') }}</td>
            <td v-if="podeAcao('comanda_visualizar')">{{ h.pago ? formatarValor(valorFinal(h)) : '—' }}</td>
          </tr>
          <tr v-if="!historico.length"><td colspan="6" style="color:var(--ink-muted);">Nenhum atendimento registrado.</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
const route = useRoute();
const supabase = useSupabaseClient();
const { podeAcao } = useUsuario();

const cliente = ref<any>(null);
const historico = ref<any[]>([]);
const pacotesCliente = ref<any[]>([]);
const podeAcaoPacotes = computed(() => podeAcao("pacotes_visualizar") || podeAcao("pacotes_vender"));

const carregar = async () => {
  const { data: c } = await supabase.from("clientes").select("*").eq("id", route.params.id).single();
  cliente.value = c;

  const { data: h } = await supabase
    .from("agendamentos")
    .select("*, colaboradores(nome), procedimentos(nome, valor)")
    .eq("cliente_id", route.params.id)
    .order("data_hora", { ascending: false });
  historico.value = h || [];

  if (podeAcaoPacotes.value) {
    const { data: p } = await supabase
      .from("pacote_vendas")
      .select("*, pacote_venda_itens(*)")
      .eq("cliente_id", route.params.id)
      .order("data_compra", { ascending: false });
    pacotesCliente.value = p || [];
  }
};

const estaVencido = (v: any) => v.data_validade < new Date().toISOString().slice(0, 10);
const badgeVenda = (v: any) => {
  if (v.status === "cancelado") return { texto: "Cancelado", classe: "badge-danger" };
  if (estaVencido(v)) return { texto: "Vencido", classe: "badge-warning" };
  return { texto: "Ativo", classe: "badge-success" };
};

const valorFinal = (h: any) => (h.procedimentos?.valor || 0) - (h.valor_desconto || 0);

const totalPago = computed(() =>
  historico.value.filter((h) => h.pago && h.forma_pagamento !== "pacote").reduce((soma, h) => soma + valorFinal(h), 0)
);

const formatarValor = (v: number) => (v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

const formatarData = (dataHora: string) => {
  const d = new Date(dataHora);
  return d.toLocaleDateString("pt-BR") + " " + d.toTimeString().slice(0, 5);
};

const labelStatus = (s: string) =>
  ({ agendado: "Agendado", confirmado: "Confirmado", concluido: "Concluído", cancelado: "Cancelado" }[s] || s);

const badgeClasse = (s: string) =>
  ({ agendado: "badge-warning", confirmado: "badge-warning", concluido: "badge-success", cancelado: "badge-danger" }[s] || "");

const labelPagamento = (h: any) => {
  const labels: Record<string, string> = { debito: "Débito", credito: "Crédito", dinheiro: "Dinheiro", pix: "Pix", pacote: "Crédito de pacote" };
  if (!h.forma_pagamento) return "Múltiplas formas";
  let texto = labels[h.forma_pagamento] || h.forma_pagamento;
  if (h.forma_pagamento === "credito" && h.parcelas) texto += ` (${h.parcelas}x)`;
  return texto;
};

const formatarDataCurta = (data: string) => {
  if (!data) return "—";
  const [ano, mes, dia] = data.split("-");
  return `${dia}/${mes}/${ano}`;
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.voltar { color: var(--ink-muted); font-size: 13px; text-decoration: none; }
.resumo { display: flex; gap: 40px; padding: 18px 22px; margin-bottom: 24px; }
.resumo-label { color: var(--ink-muted); font-size: 12px; }
.resumo-valor { font-weight: 600; color: var(--primary-dark); }
.subtitulo { font-size: 15px; margin: 0 0 10px; }
.saldo-linha { font-size: 12px; color: var(--ink-muted); }
</style>
