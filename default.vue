<template>
  <div class="shell">
    <!-- barra superior (mobile) -->
    <header class="topbar-mobile">
      <button class="botao-menu" @click="menuAberto = true" aria-label="Abrir menu">
        <span></span><span></span><span></span>
      </button>
      <img src="/logo.png" alt="Espaço Armstrong" class="logo-mobile" />
      <span style="width:34px;"></span>
    </header>

    <!-- fundo escurecido ao abrir menu no mobile -->
    <div v-if="menuAberto" class="overlay-menu" @click="menuAberto = false"></div>

    <aside class="sidebar" :class="{ aberta: menuAberto }">
      <div class="brand">
        <img src="/logo.png" alt="Espaço Armstrong" class="brand-logo" />
      </div>
      <nav class="nav" @click="menuAberto = false">
        <NuxtLink to="/" class="nav-item">Dashboard</NuxtLink>
        <NuxtLink v-if="podeAcao('agenda_visualizar')" to="/agenda" class="nav-item">Agenda</NuxtLink>
        <NuxtLink v-if="podeAcao('comanda_visualizar')" to="/comandas" class="nav-item">Comandas</NuxtLink>
        <NuxtLink v-if="podeAcao('clientes_visualizar')" to="/clientes" class="nav-item">Clientes</NuxtLink>
        <NuxtLink v-if="podeAcao('procedimentos_visualizar')" to="/procedimentos" class="nav-item">Procedimentos</NuxtLink>
        <NuxtLink v-if="podeAcao('colaboradores_visualizar')" to="/colaboradores" class="nav-item">Colaboradores</NuxtLink>
        <NuxtLink v-if="podeAcao('remuneracao_visualizar')" to="/remuneracao" class="nav-item">Remuneração</NuxtLink>
        <NuxtLink v-if="podeAcao('pacotes_visualizar') || podeAcao('pacotes_vender')" to="/pacotes" class="nav-item">Pacotes</NuxtLink>
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
const menuAberto = ref(false);

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

.topbar-mobile { display: none; }
.overlay-menu { display: none; }

.sidebar {
  width: 220px;
  flex-shrink: 0;
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
  justify-content: center;
  padding: 4px 6px 8px;
}
.brand-logo {
  width: 100%;
  max-width: 160px;
  border-radius: 8px;
}
.nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
}
.nav-item {
  padding: 10px 12px;
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
  min-width: 0;
  padding: 32px 40px;
  max-width: 1100px;
}

/* ---------- MOBILE ---------- */
@media (max-width: 860px) {
  .shell { flex-direction: column; }

  .topbar-mobile {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 12px 16px;
    position: sticky;
    top: 0;
    z-index: 30;
  }
  .logo-mobile { height: 32px; border-radius: 6px; }
  .botao-menu {
    width: 34px; height: 34px;
    border: none; background: transparent;
    display: flex; flex-direction: column; justify-content: center; align-items: center; gap: 4px;
  }
  .botao-menu span { width: 20px; height: 2px; background: var(--ink); border-radius: 2px; }

  .overlay-menu {
    display: block;
    position: fixed; inset: 0;
    background: rgba(43,34,48,0.4);
    z-index: 40;
  }

  .sidebar {
    position: fixed;
    top: 0; bottom: 0; left: 0;
    width: 240px;
    z-index: 50;
    transform: translateX(-100%);
    transition: transform 0.2s ease;
    box-shadow: 0 0 30px rgba(0,0,0,0.15);
  }
  .sidebar.aberta { transform: translateX(0); }

  .content {
    padding: 18px 14px 32px;
    max-width: 100%;
  }
}
</style>
