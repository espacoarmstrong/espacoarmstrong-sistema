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

    <h3 class="subtitulo">Histórico de procedimentos</h3>
    <div class="card" style="padding: 4px;">
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

const carregar = async () => {
  const { data: c } = await supabase.from("clientes").select("*").eq("id", route.params.id).single();
  cliente.value = c;

  const { data: h } = await supabase
    .from("agendamentos")
    .select("*, colaboradores(nome), procedimentos(nome, valor)")
    .eq("cliente_id", route.params.id)
    .order("data_hora", { ascending: false });
  historico.value = h || [];
};

const valorFinal = (h: any) => (h.procedimentos?.valor || 0) - (h.valor_desconto || 0);

const totalPago = computed(() =>
  historico.value.filter((h) => h.pago).reduce((soma, h) => soma + valorFinal(h), 0)
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
  const labels: Record<string, string> = { debito: "Débito", credito: "Crédito", dinheiro: "Dinheiro", pix: "Pix" };
  if (!h.forma_pagamento) return "Múltiplas formas";
  let texto = labels[h.forma_pagamento] || h.forma_pagamento;
  if (h.forma_pagamento === "credito" && h.parcelas) texto += ` (${h.parcelas}x)`;
  return texto;
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
</style>
