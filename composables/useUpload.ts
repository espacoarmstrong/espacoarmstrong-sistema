// Upload de fotos (clientes/colaboradores) no bucket "fotos" do Supabase Storage
export const useUpload = () => {
  const supabase = useSupabaseClient();

  const enviarFoto = async (arquivo: File, pasta: string): Promise<string> => {
    const extensao = arquivo.name.split(".").pop() || "jpg";
    const caminho = `${pasta}/${crypto.randomUUID()}.${extensao}`;

    const { error } = await supabase.storage.from("fotos").upload(caminho, arquivo, {
      cacheControl: "3600",
      upsert: false,
    });
    if (error) throw new Error(error.message);

    const { data } = supabase.storage.from("fotos").getPublicUrl(caminho);
    return data.publicUrl;
  };

  return { enviarFoto };
};
