export default defineNuxtConfig({
  compatibilityDate: "2026-01-01",
  devtools: { enabled: false },
  modules: ["@nuxtjs/supabase"],
  css: ["~/assets/css/main.css"],
  supabase: {
    redirect: true,
    redirectOptions: {
      login: "/login",
      callback: "/",
      exclude: ["/login"],
    },
  },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE,
    },
  },
});
