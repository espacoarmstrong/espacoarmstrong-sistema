// Chamadas para a Edge Function "api" (operações administrativas)
export const useApi = () => {
  const config = useRuntimeConfig();
  const supabase = useSupabaseClient();

  const chamar = async (path: string, options: { method?: string; body?: any } = {}) => {
    const { data: sessionData } = await supabase.auth.getSession();
    const token = sessionData.session?.access_token;

    const resposta: any = await $fetch(`${config.public.apiBase}${path}`, {
      method: (options.method as any) || "GET",
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: options.body,
    }).catch((erro: any) => {
      throw new Error(erro?.data?.error || "Erro ao comunicar com o servidor");
    });

    return resposta;
  };

  return { chamar };
};
