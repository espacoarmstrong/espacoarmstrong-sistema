export type Toast = { id: number; texto: string; tipo: "sucesso" | "erro" };

export const useToast = () => {
  const toasts = useState<Toast[]>("salao_toasts", () => []);
  let proximoId = 0;

  const remover = (id: number) => {
    toasts.value = toasts.value.filter((t) => t.id !== id);
  };

  const mostrar = (texto: string, tipo: "sucesso" | "erro" = "sucesso") => {
    const id = ++proximoId;
    toasts.value = [...toasts.value, { id, texto, tipo }];
    setTimeout(() => remover(id), 3000);
  };

  const sucesso = (texto: string) => mostrar(texto, "sucesso");
  const erro = (texto: string) => mostrar(texto, "erro");

  return { toasts, sucesso, erro, remover };
};
