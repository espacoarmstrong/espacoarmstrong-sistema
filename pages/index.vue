<template>
  <div>
    <h1>Olá, {{ usuario?.nome?.split(' ')[0] || '' }}</h1>
    <p class="intro">Este é o painel do sistema. O Dashboard completo (faturamento, indicadores) chega numa fase futura — por enquanto, use o menu ao lado para gerenciar a base do sistema.</p>

    <div class="grade">
      <NuxtLink v-if="podeAcao('clientes_visualizar')" to="/clientes" class="atalho card">
        <h3>Clientes</h3>
        <p>Cadastro e histórico de clientes</p>
      </NuxtLink>
      <NuxtLink v-if="podeAcao('procedimentos_visualizar')" to="/procedimentos" class="atalho card">
        <h3>Procedimentos</h3>
        <p>Serviços oferecidos pelo salão</p>
      </NuxtLink>
      <NuxtLink v-if="ehAdmin" to="/categorias" class="atalho card">
        <h3>Categorias</h3>
        <p>Organize os procedimentos</p>
      </NuxtLink>
      <NuxtLink v-if="podeAcao('colaboradores_visualizar')" to="/colaboradores" class="atalho card">
        <h3>Colaboradores</h3>
        <p>Equipe, permissões e comissões</p>
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
const { usuario, podeAcao, ehAdmin } = useUsuario();
</script>

<style scoped>
.intro { color: var(--ink-muted); max-width: 520px; margin: 8px 0 28px; }
.grade {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 14px;
}
.atalho {
  padding: 18px;
  text-decoration: none;
  color: var(--ink);
  display: block;
}
.atalho h3 { font-size: 16px; margin-bottom: 4px; }
.atalho p { color: var(--ink-muted); font-size: 13px; margin: 0; }
.atalho:hover { border-color: var(--primary); }
</style>
