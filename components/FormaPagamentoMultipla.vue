<template>
  <div class="formas-pagamento">
    <div v-for="(linha, i) in linhas" :key="i" class="linha-pagamento">
      <select v-model="linha.forma_pagamento" class="input">
        <option value="" disabled>Forma</option>
        <option value="debito">Débito</option>
        <option value="credito">Crédito</option>
        <option value="dinheiro">Dinheiro</option>
        <option value="pix">Pix</option>
      </select>
      <input v-model.number="linha.valor" type="number" min="0" step="0.01" class="input" placeholder="Valor" style="width:110px;" />
      <input
        v-if="linha.forma_pagamento === 'credito'"
        v-model.number="linha.parcelas"
        type="number" min="1" max="24" class="input" style="width:70px;" placeholder="Parc."
      />
      <button v-if="linhas.length > 1" type="button" class="btn btn-ghost btn-remover" @click="remover(i)">✕</button>
    </div>

    <button type="button" class="btn btn-ghost btn-add" @click="adicionar">+ Adicionar forma de pagamento</button>

    <p class="resumo-total" :class="{ 'resumo-ok': restante === 0, 'resumo-erro': restante !== 0 }">
      Informado: {{ formatarValor(totalInformado) }} · {{ restante === 0 ? 'Total confere' : (restante > 0 ? `Falta ${formatarValor(restante)}` : `Excede ${formatarValor(-restante)}`) }}
    </p>
  </div>
</template>

<script setup lang="ts">
type LinhaPagamento = { forma_pagamento: string; valor: number | null; parcelas: number | null };

const props = defineProps<{ modelValue: LinhaPagamento[]; total: number }>();
const emit = defineEmits<{ (e: "update:modelValue", valor: LinhaPagamento[]): void }>();

const linhas = computed<LinhaPagamento[]>({
  get: () => (props.modelValue?.length ? props.modelValue : [{ forma_pagamento: "", valor: props.total || null, parcelas: 1 }]),
  set: (v) => emit("update:modelValue", v),
});

const adicionar = () => {
  linhas.value = [...linhas.value, { forma_pagamento: "", valor: null, parcelas: 1 }];
};
const remover = (i: number) => {
  linhas.value = linhas.value.filter((_, idx) => idx !== i);
};

const totalInformado = computed(() => linhas.value.reduce((soma, l) => soma + (Number(l.valor) || 0), 0));
const restante = computed(() => Math.round(((props.total || 0) - totalInformado.value) * 100) / 100);

const formatarValor = (v: number) => (v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

defineExpose({ restante, totalInformado });
</script>

<style scoped>
.formas-pagamento { display: flex; flex-direction: column; gap: 8px; margin: 4px 0 14px; }
.linha-pagamento { display: flex; gap: 8px; align-items: center; }
.btn-remover { padding: 6px 10px; color: var(--danger); }
.btn-add { align-self: flex-start; font-size: 13px; padding: 6px 10px; }
.resumo-total { font-size: 13px; margin: 2px 0 0; }
.resumo-ok { color: var(--success); }
.resumo-erro { color: var(--danger); }
</style>
