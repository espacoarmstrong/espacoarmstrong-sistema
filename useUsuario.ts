export const useUsuario = () => {
  const supabase = useSupabaseClient();
  const user = useSupabaseUser();

  const usuario = useState<any>("salao_usuario", () => null);
  const permissoes = useState<Record<string, boolean>>("salao_permissoes", () => ({}));
  const carregando = useState<boolean>("salao_usuario_carregando", () => false);

  const carregar = async () => {
    if (!user.value) {
      usuario.value = null;
      permissoes.value = {};
      return;
    }
    carregando.value = true;
    const { data } = await supabase
      .from("usuarios")
      .select("*")
      .eq("id", user.value.id)
      .single();

    usuario.value = data;

    if (data?.role === "colaborador" && data.colaborador_id) {
      const { data: perms } = await supabase
        .from("colaborador_permissoes")
        .select("permissao, concedida")
        .eq("colaborador_id", data.colaborador_id);
      permissoes.value = Object.fromEntries((perms || []).map((p: any) => [p.permissao, p.concedida]));
    } else {
      permissoes.value = {};
    }
    carregando.value = false;
  };

  const podeAcao = (chave: string) => {
    if (usuario.value?.role === "admin") return true;
    return !!permissoes.value[chave];
  };

  const ehAdmin = computed(() => usuario.value?.role === "admin");

  return { usuario, permissoes, carregando, carregar, podeAcao, ehAdmin };
};
