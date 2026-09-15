<template>
  <div class="toast-wrap">
    <transition-group name="toast">
      <div v-for="t in toasts" :key="t.id" :class="['toast', t.tipo === 'sucesso' ? 'toast-sucesso' : 'toast-erro']">
        <span class="toast-icone">{{ t.tipo === 'sucesso' ? '✓' : '!' }}</span>
        <span>{{ t.texto }}</span>
      </div>
    </transition-group>
  </div>
</template>

<script setup lang="ts">
const { toasts } = useToast();
</script>

<style scoped>
.toast-wrap {
  position: fixed;
  top: 20px;
  right: 20px;
  z-index: 999;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.toast {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  font-size: 14px;
  font-weight: 500;
  min-width: 220px;
}
.toast-sucesso { background: var(--success-soft); color: var(--success); border: 1px solid var(--success); }
.toast-erro { background: var(--danger-soft); color: var(--danger); border: 1px solid var(--danger); }
.toast-icone {
  width: 20px; height: 20px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 12px;
  flex-shrink: 0;
}
.toast-sucesso .toast-icone { background: var(--success); color: #fff; }
.toast-erro .toast-icone { background: var(--danger); color: #fff; }
.toast-enter-active, .toast-leave-active { transition: all 0.25s ease; }
.toast-enter-from { opacity: 0; transform: translateX(20px); }
.toast-leave-to { opacity: 0; transform: translateX(20px); }

@media (max-width: 480px) {
  .toast-wrap { top: auto; bottom: 16px; left: 16px; right: 16px; }
  .toast { min-width: 0; width: 100%; }
}
</style>
