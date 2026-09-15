<template>
  <div class="seletor-cliente" ref="raiz">
    <input
      class="input"
      v-model="termo"
      @focus="aberto = true"
      @input="aberto = true"
      placeholder="Buscar por nome ou celular"
      autocomplete="off"
    />
    <div v-if="aberto" class="lista-dropdown">
      <div v-for="c in filtrados" :key="c.id" class="item-dropdown" @mousedown.prevent="selecionar(c)">
        <strong>{{ c.nome }}</strong>
        <span v-if="c.telefone" class="item-telefone">{{ c.telefone }}</span>
      </div>
      <div v-if="!filtrados.length" class="item-dropdown vazio">Nenhum cliente encontrado.</div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ modelValue: string; clientes: any[] }>();
const emit = defineEmits(["update:modelValue"]);

const termo = ref("");
const aberto = ref(false);
const raiz = ref<HTMLElement | null>(null);

const aplicarNomeSelecionado = () => {
  const c = props.clientes.find((x) => x.id === props.modelValue);
  termo.value = c ? c.nome : "";
};
watch(() => props.modelValue, aplicarNomeSelecionado);
watch(() => props.clientes, aplicarNomeSelecionado);
aplicarNomeSelecionado();

const filtrados = computed(() => {
  const t = termo.value.toLowerCase().trim();
  const base = !t
    ? props.clientes
    : props.clientes.filter(
        (c) => c.nome.toLowerCase().includes(t) || (c.telefone || "").replace(/\D/g, "").includes(t.replace(/\D/g, ""))
      );
  return base.slice(0, 8);
});

const selecionar = (c: any) => {
  emit("update:modelValue", c.id);
  termo.value = c.nome;
  aberto.value = false;
};

const aoClicarFora = (e: MouseEvent) => {
  if (raiz.value && !raiz.value.contains(e.target as Node)) {
    aberto.value = false;
    aplicarNomeSelecionado();
  }
};
onMounted(() => document.addEventListener("click", aoClicarFora));
onUnmounted(() => document.removeEventListener("click", aoClicarFora));
</script>

<style scoped>
.seletor-cliente { position: relative; }
.lista-dropdown {
  position: absolute; top: 100%; left: 0; right: 0; z-index: 30;
  background: #fff; border: 1px solid var(--border); border-radius: 8px;
  margin-top: 4px; max-height: 220px; overflow-y: auto;
  box-shadow: 0 6px 20px rgba(0,0,0,0.1);
}
.item-dropdown { padding: 8px 12px; font-size: 13px; cursor: pointer; display: flex; justify-content: space-between; gap: 10px; }
.item-dropdown:hover { background: var(--bg); }
.item-dropdown.vazio { color: var(--ink-muted); cursor: default; }
.item-telefone { color: var(--ink-muted); font-size: 12px; white-space: nowrap; }
</style>
