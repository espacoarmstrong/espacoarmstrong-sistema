<template>
  <div class="modal-backdrop" @click.self="$emit('cancelar')">
    <div class="modal" style="max-width:420px;">
      <h2 style="margin-bottom:10px;">{{ titulo }}</h2>
      <p style="color:var(--ink-muted); font-size:14px;">{{ mensagem }}</p>

      <label v-if="dupla" class="linha-check-confirm">
        <input type="checkbox" v-model="confirmado" />
        {{ textoConfirmacao || "Sim, tenho certeza e quero excluir mesmo assim." }}
      </label>

      <div style="display:flex; gap:10px; margin-top: 16px;">
        <button class="btn btn-danger" :disabled="dupla && !confirmado" @click="$emit('confirmar')">
          Excluir definitivamente
        </button>
        <button class="btn btn-ghost" @click="$emit('cancelar')">Cancelar</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ titulo: string; mensagem: string; dupla?: boolean; textoConfirmacao?: string }>();
defineEmits(["confirmar", "cancelar"]);
const confirmado = ref(false);
</script>

<style scoped>
.linha-check-confirm {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 14px;
  padding: 10px 12px;
  background: var(--danger-soft);
  border-radius: 8px;
  font-size: 13px;
  color: var(--danger);
}
</style>
