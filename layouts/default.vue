<template>
  <div class="shell">
    <aside class="sidebar">
      <div class="brand">
        <span class="brand-mark">S</span>
        <span class="brand-name">Salão</span>
      </div>
      <nav class="nav">
        <NuxtLink to="/" class="nav-item">Dashboard</NuxtLink>
        <NuxtLink v-if="podeAcao('agenda_visualizar')" to="/agenda" class="nav-item">Agenda</NuxtLink>
        <NuxtLink v-if="podeAcao('clientes_visualizar')" to="/clientes" class="nav-item">Clientes</NuxtLink>
        <NuxtLink v-if="podeAcao('procedimentos_visualizar')" to="/procedimentos" class="nav-item">Procedimentos</NuxtLink>
        <NuxtLink v-if="ehAdmin" to="/categorias" class="nav-item">Categorias</NuxtLink>
        <NuxtLink v-if="podeAcao('colaboradores_visualizar')" to="/colaboradores" class="nav-item">Colaboradores</NuxtLink>
      </nav>
      <button class="btn btn-ghost sair" @click="sair">Sair</button>
    </aside>
    <main class="content">
      <slot />
    </main>
    <ToastContainer />
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const router = useRouter();
const { usuario, carregar, podeAcao, ehAdmin } = useUsuario();

await carregar();

const sair = async () => {
  await supabase.auth.signOut();
  router.push("/login");
};
</script>

<style scoped>
.shell {
  display: flex;
  min-height: 100vh;
}
.sidebar {
  width: 220px;
  background: var(--surface);
  border-right: 1px solid var(--border);
  padding: 20px 14px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 6px;
}
.brand-mark {
  width: 32px; height: 32px;
  border-radius: 9px;
  background: var(--primary);
  color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-family: 'Fraunces', serif;
  font-weight: 600;
}
.brand-name {
  font-family: 'Fraunces', serif;
  font-size: 18px;
  font-weight: 600;
}
.nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
}
.nav-item {
  padding: 9px 12px;
  border-radius: 8px;
  color: var(--ink-muted);
  text-decoration: none;
  font-size: 14px;
  font-weight: 500;
}
.nav-item:hover { background: var(--bg); color: var(--ink); }
.nav-item.router-link-exact-active {
  background: var(--primary-soft);
  color: var(--primary-dark);
}
.sair { justify-content: center; }
.content {
  flex: 1;
  padding: 32px 40px;
  max-width: 1100px;
}
</style>
