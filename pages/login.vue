<template>
  <div class="tela-login">
    <div class="card painel">
      <div class="marca">
        <span class="marca-icone">S</span>
        <h1>Salão</h1>
      </div>
      <p class="subtitulo">Entre com seu e-mail e senha</p>

      <form @submit.prevent="entrar">
        <div class="field">
          <label>E-mail</label>
          <input v-model="email" type="email" class="input" required />
        </div>
        <div class="field">
          <label>Senha</label>
          <input v-model="senha" type="password" class="input" required />
        </div>
        <p v-if="erro" class="erro">{{ erro }}</p>
        <button class="btn btn-primary" style="width: 100%; justify-content: center;" :disabled="carregando">
          {{ carregando ? "Entrando..." : "Entrar" }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false });

const supabase = useSupabaseClient();
const router = useRouter();

const email = ref("");
const senha = ref("");
const erro = ref("");
const carregando = ref(false);

const entrar = async () => {
  erro.value = "";
  carregando.value = true;
  const { error } = await supabase.auth.signInWithPassword({
    email: email.value,
    password: senha.value,
  });
  carregando.value = false;
  if (error) {
    erro.value = "E-mail ou senha inválidos.";
    return;
  }
  router.push("/");
};
</script>

<style scoped>
.tela-login {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg);
}
.painel {
  width: 100%;
  max-width: 380px;
  padding: 32px;
}
.marca {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 4px;
}
.marca-icone {
  width: 34px; height: 34px;
  border-radius: 9px;
  background: var(--primary);
  color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-family: 'Fraunces', serif;
  font-weight: 600;
}
.subtitulo {
  color: var(--ink-muted);
  font-size: 14px;
  margin: 0 0 24px;
}
.erro {
  color: var(--danger);
  font-size: 13px;
  margin: -6px 0 14px;
}
</style>
