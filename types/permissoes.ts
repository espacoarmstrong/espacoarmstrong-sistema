export const PERMISSOES = [
  { chave: "agenda_visualizar", label: "Visualizar agenda", grupo: "Agenda" },
  { chave: "agenda_criar", label: "Criar agendamento", grupo: "Agenda" },
  { chave: "agenda_editar", label: "Editar agendamento", grupo: "Agenda" },
  { chave: "agenda_cancelar", label: "Cancelar agendamento", grupo: "Agenda" },
  { chave: "clientes_visualizar", label: "Visualizar clientes", grupo: "Clientes" },
  { chave: "clientes_criar", label: "Criar cliente", grupo: "Clientes" },
  { chave: "clientes_editar", label: "Editar cliente", grupo: "Clientes" },
  { chave: "clientes_excluir", label: "Excluir cliente", grupo: "Clientes" },
  { chave: "comanda_visualizar", label: "Visualizar comanda", grupo: "Comanda / Pagamento" },
  { chave: "comanda_finalizar", label: "Finalizar comanda", grupo: "Comanda / Pagamento" },
  { chave: "comanda_registrar_pagamento", label: "Registrar pagamento", grupo: "Comanda / Pagamento" },
  { chave: "comanda_aplicar_desconto", label: "Aplicar desconto", grupo: "Comanda / Pagamento" },
  { chave: "remuneracao_visualizar", label: "Visualizar remuneração", grupo: "Remuneração" },
  { chave: "remuneracao_pagar", label: "Registrar pagamento de remuneração", grupo: "Remuneração" },
  { chave: "procedimentos_visualizar", label: "Visualizar procedimentos", grupo: "Outros" },
  { chave: "colaboradores_visualizar", label: "Visualizar colaboradores", grupo: "Outros" },
  { chave: "dashboard_visualizar", label: "Visualizar dashboard", grupo: "Outros" },
] as const;

export const DIAS_SEMANA = [
  { valor: 1, label: "Segunda" },
  { valor: 2, label: "Terça" },
  { valor: 3, label: "Quarta" },
  { valor: 4, label: "Quinta" },
  { valor: 5, label: "Sexta" },
  { valor: 6, label: "Sábado" },
  { valor: 0, label: "Domingo" },
];
