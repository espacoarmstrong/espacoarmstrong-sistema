<template>
  <div class="upload-foto">
    <img v-if="preview" :src="preview" class="avatar avatar-lg" />
    <div v-else class="avatar avatar-lg">{{ iniciais }}</div>
    <div>
      <input ref="inputEl" type="file" accept="image/*" style="display:none;" @change="onSelecionar" />
      <button type="button" class="btn btn-ghost" @click="inputEl?.click()">
        {{ preview ? "Trocar foto" : "Adicionar foto" }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ fotoUrl?: string | null; nome?: string }>();
const emit = defineEmits<{ (e: "arquivo-selecionado", arquivo: File | null): void }>();

const inputEl = ref<HTMLInputElement | null>(null);
const previewLocal = ref<string | null>(null);

const preview = computed(() => previewLocal.value || props.fotoUrl || null);

const iniciais = computed(() =>
  (props.nome || "").trim().split(/\s+/).slice(0, 2).map((p) => p[0]?.toUpperCase()).join("") || "?"
);

const onSelecionar = (e: Event) => {
  const arquivo = (e.target as HTMLInputElement).files?.[0] || null;
  if (arquivo) {
    previewLocal.value = URL.createObjectURL(arquivo);
  }
  emit("arquivo-selecionado", arquivo);
};

// permite ao componente-pai resetar o preview local quando o formulário é reaberto
defineExpose({
  resetar: () => { previewLocal.value = null; if (inputEl.value) inputEl.value.value = ""; },
});
</script>
