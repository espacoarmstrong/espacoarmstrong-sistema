<template>
  <div>
    <div class="cabecalho">
      <h1>Pacotes</h1>
      <div style="display:flex; gap:8px;">
        <button v-if="podeAcao('pacotes_vender') && aba === 'vendas'" class="btn btn-primary" @click="abrirVenda">+ Vender pacote</button>
        <button v-if="ehAdmin && aba === 'catalogo'" class="btn btn-primary" @click="abrirNovoPacote">+ Novo pacote</button>
      </div>
    </div>

    <div class="abas">
      <button :class="['aba', { ativa: aba === 'catalogo' }]" @click="aba = 'catalogo'">Catálogo</button>
      <button :class="['aba', { ativa: aba === 'vendas' }]" @click="aba = 'vendas'">Vendas</button>
    </div>

    <!-- ABA CATÁLOGO -->
    <div v-if="aba === 'catalogo'" class="card tabela-wrap">
      <table>
        <thead>
          <tr><th>Nome</th><th>Validade</th><th>Itens</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="p in pacotes" :key="p.id">
            <td data-label="Nome">{{ p.nome }}</td>
            <td data-label="Validade">{{ p.validade_dias }} dias</td>
            <td data-label="Itens">{{ (p.pacote_itens || []).map(i => `${i.quantidade}x ${i.procedimentos?.nome || '—'}`).join(', ') || '—' }}</td>
            <td data-label="Status"><span :class="['badge', p.ativo ? 'badge-success' : 'badge-danger']">{{ p.ativo ? 'Ativo' : 'Inativo' }}</span></td>
            <td style="text-align:right; white-space:nowrap;">
              <button v-if="ehAdmin" class="btn btn-ghost" @click="abrirEdicaoPacote(p)">Editar</button>
              <button v-if="ehAdmin" class="btn" :class="p.ativo ? 'btn-danger' : 'btn-ghost'" @click="alternarAtivoPacote(p)">
                {{ p.ativo ? 'Desativar' : 'Ativar' }}
              </button>
              <button v-if="ehAdmin" class="btn btn-danger" @click="confirmarExclusaoPacote(p)">Excluir</button>
            </td>
          </tr>
          <tr v-if="!pacotes.length" class="linha-vazia"><td colspan="5" style="color:var(--ink-muted);">Nenhum pacote cadastrado.</td></tr>
        </tbody>
      </table>
    </div>

    <!-- ABA VENDAS -->
    <div v-if="aba === 'vendas'">
      <div class="field" style="max-width:280px; margin-bottom: 16px;">
        <input v-model="buscaVenda" class="input" placeholder="Buscar por cliente ou pacote" />
      </div>

      <div class="card tabela-wrap">
        <table>
          <thead>
            <tr><th>Cliente</th><th>Pacote</th><th>Compra</th><th>Validade</th><th>Saldo</th><th>Status</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-for="v in vendasFiltradas" :key="v.id">
              <td data-label="Cliente">{{ v.clientes?.nome || '—' }}</td>
              <td data-label="Pacote">{{ v.pacote_nome }}</td>
              <td data-label="Compra">{{ formatarData(v.data_compra) }}</td>
              <td data-label="Validade">{{ formatarDataCurta(v.data_validade) }}</td>
              <td data-label="Saldo">
                <div v-for="item in v.pacote_venda_itens" :key="item.id" class="saldo-linha">
                  {{ item.procedimento_nome }}: {{ item.quantidade_total - item.quantidade_usada }}/{{ item.quantidade_total }}
                </div>
              </td>
              <td data-label="Status"><span :class="['badge', badgeVenda(v).classe]">{{ badgeVenda(v).texto }}</span></td>
              <td style="text-align:right; white-space:nowrap;">
                <button v-if="ehAdmin && v.status === 'ativo' && estaVencido(v)" class="btn btn-ghost" @click="abrirReativacao(v)">Reativar / estender</button>
                <button v-if="ehAdmin && v.status === 'ativo'" class="btn btn-danger" @click="confirmarCancelamento(v)">Cancelar</button>
              </td>
            </tr>
            <tr v-if="!vendasFiltradas.length" class="linha-vazia"><td colspan="7" style="color:var(--ink-muted);">Nenhuma venda de pacote encontrada.</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- MODAL: novo/editar pacote (catálogo) -->
    <div v-if="modalPacoteAberto" class="modal-backdrop" @click.self="modalPacoteAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">{{ editandoPacote?.id ? 'Editar pacote' : 'Novo pacote' }}</h2>
        <div class="field">
          <label>Nome do pacote</label>
          <input v-model="editandoPacote.nome" class="input" placeholder="Ex.: Pacote 10 sessões de massagem" />
        </div>
        <div class="field">
          <label>Validade (dias a partir da compra)</label>
          <input v-model.number="editandoPacote.validade_dias" type="number" min="1" class="input" style="max-width:140px;" />
        </div>

        <label class="ajuda" style="display:block; margin-bottom:6px;">Itens do pacote</label>
        <div class="linha-item" v-for="(item, i) in editandoPacote.itens" :key="i">
          <select v-model="item.procedimento_id" class="input">
            <option value="" disabled>Procedimento</option>
            <option v-for="p in procedimentos" :key="p.id" :value="p.id">{{ p.nome }}</option>
          </select>
          <input v-model.number="item.quantidade" type="number" min="1" class="input" style="width:80px;" placeholder="Qtd." />
          <input v-model.number="item.valor_procedimento" type="number" min="0" step="0.01" class="input" style="width:120px;" placeholder="Valor (R$)" />
          <button v-if="editandoPacote.itens.length > 1" type="button" class="btn btn-ghost btn-remover" @click="removerItemPacote(i)">✕</button>
        </div>
        <button type="button" class="btn btn-ghost btn-add" @click="adicionarItemPacote">+ Adicionar item</button>

        <p v-if="erroPacote" class="erro-msg" style="margin-top:14px;">{{ erroPacote }}</p>
        <div style="display:flex; gap:10px; margin-top: 16px;">
          <button class="btn btn-primary" :disabled="salvandoPacote" @click="salvarPacote">{{ salvandoPacote ? 'Salvando...' : 'Salvar' }}</button>
          <button class="btn btn-ghost" @click="modalPacoteAberto = false">Cancelar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: vender pacote -->
    <div v-if="modalVendaAberto" class="modal-backdrop" @click.self="modalVendaAberto = false">
      <div class="modal">
        <h2 style="margin-bottom:16px;">Vender pacote</h2>
        <div class="field">
          <label>Cliente</label>
          <SeletorCliente v-model="vendaForm.cliente_id" :clientes="clientes" />
        </div>
        <div class="field">
          <label>Pacote</label>
          <select v-model="vendaForm.pacote_id" class="input">
            <option value="" disabled>Selecione</option>
            <option v-for="p in pacotesAtivos" :key="p.id" :value="p.id">{{ p.nome }}</option>
          </select>
        </div>

        <template v-if="pacoteEscolhido">
          <div class="resumo-venda">
            <p><strong>Itens:</strong></p>
            <p v-for="item in pacoteEscolhido.pacote_itens" :key="item.id">
              {{ item.quantidade }}x {{ item.procedimentos?.nome }} — {{ formatarValor(item.valor_procedimento) }} cada
            </p>
            <p style="margin-top:8px;">Validade: <strong>{{ pacoteEscolhido.validade_dias }} dias</strong> (até {{ formatarDataCurta(dataValidadeVenda) }})</p>
            <p>Valor total da venda: <strong>{{ formatarValor(valorTotalVenda) }}</strong></p>
          </div>
        </template>

        <p v-if="erroVenda" class="erro-msg">{{ erroVenda }}</p>
        <div style="display:flex; gap:10px; margin-top: 8px;">
          <button class="btn btn-primary" :disabled="salvandoVenda || !pacoteEscolhido" @click="salvarVenda">
            {{ salvandoVenda ? 'Registrando...' : 'Registrar venda' }}
          </button>
          <button class="btn btn-ghost" @click="modalVendaAberto = false">Cancelar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: excluir pacote do catálogo -->
    <ConfirmarExclusao
      v-if="excluindoPacote"
      titulo="Excluir pacote?"
      mensagem="Só é possível excluir pacotes que nunca foram vendidos. Se já houve vendas, prefira desativá-lo em vez de excluir."
      @confirmar="excluirPacote"
      @cancelar="excluindoPacote = null"
    />

    <!-- MODAL: cancelar venda -->
    <div v-if="cancelando" class="modal-backdrop" @click.self="cancelando = null">
      <div class="modal" style="max-width:420px;">
        <h2 style="margin-bottom:10px;">Cancelar este pacote?</h2>
        <p style="color:var(--ink-muted); font-size:14px;">
          O pacote será marcado como cancelado e o saldo restante ficará travado — não há estorno e os valores já pagos não são alterados.
        </p>
        <div style="display:flex; gap:10px; margin-top: 16px;">
          <button class="btn btn-danger" @click="cancelarVenda">Cancelar pacote</button>
          <button class="btn btn-ghost" @click="cancelando = null">Voltar</button>
        </div>
      </div>
    </div>

    <!-- MODAL: reativar / estender validade -->
    <div v-if="reativando" class="modal-backdrop" @click.self="reativando = null">
      <div class="modal" style="max-width:420px;">
        <h2 style="margin-bottom:4px;">Reativar / estender validade</h2>
        <p style="color:var(--ink-muted); font-size:13px; margin:0 0 16px;">
          {{ reativando.clientes?.nome }} · {{ reativando.pacote_nome }} · venceu em {{ formatarDataCurta(reativando.data_validade) }}
        </p>
        <div class="field">
          <label>Nova data de validade</label>
          <input v-model="reativarForm.nova_validade" type="date" class="input" />
        </div>
        <div class="field">
          <label>Observação (opcional)</label>
          <textarea v-model="reativarForm.observacao" class="input" rows="2" placeholder="Ex.: Cortesia por atraso no atendimento"></textarea>
        </div>
        <p style="font-size:12px; color:var(--ink-muted); margin:-4px 0 12px;">Isso é uma decisão manual sua — o sistema não estende validades sozinho.</p>
        <p v-if="erroReativar" class="erro-msg">{{ erroReativar }}</p>
        <div style="display:flex; gap:10px;">
          <button class="btn btn-primary" :disabled="salvandoReativar" @click="salvarReativacao">{{ salvandoReativar ? 'Salvando...' : 'Confirmar' }}</button>
          <button class="btn btn-ghost" @click="reativando = null">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient();
const { podeAcao, ehAdmin } = useUsuario();
const { sucesso, erro: toastErro } = useToast();

const aba = ref<"catalogo" | "vendas">("catalogo");

const pacotes = ref<any[]>([]);
const procedimentos = ref<any[]>([]);
const clientes = ref<any[]>([]);
const vendas = ref<any[]>([]);
const buscaVenda = ref("");

const pacotesAtivos = computed(() => pacotes.value.filter((p) => p.ativo));

// ---------- catálogo ----------
const modalPacoteAberto = ref(false);
const editandoPacote = ref<any>({ nome: "", validade_dias: 30, itens: [{ procedimento_id: "", quantidade: 1, valor_procedimento: 0 }] });
const erroPacote = ref("");
const salvandoPacote = ref(false);
const excluindoPacote = ref<any>(null);

const carregarPacotes = async () => {
  const { data } = await supabase
    .from("pacotes")
    .select("*, pacote_itens(*, procedimentos(nome))")
    .order("nome");
  pacotes.value = data || [];
};

const abrirNovoPacote = () => {
  editandoPacote.value = { nome: "", validade_dias: 30, itens: [{ procedimento_id: "", quantidade: 1, valor_procedimento: 0 }] };
  erroPacote.value = "";
  modalPacoteAberto.value = true;
};

const abrirEdicaoPacote = (p: any) => {
  editandoPacote.value = {
    id: p.id,
    nome: p.nome,
    validade_dias: p.validade_dias,
    itens: (p.pacote_itens || []).map((i: any) => ({ procedimento_id: i.procedimento_id, quantidade: i.quantidade, valor_procedimento: i.valor_procedimento })),
  };
  if (!editandoPacote.value.itens.length) editandoPacote.value.itens = [{ procedimento_id: "", quantidade: 1, valor_procedimento: 0 }];
  erroPacote.value = "";
  modalPacoteAberto.value = true;
};

const adicionarItemPacote = () => { editandoPacote.value.itens.push({ procedimento_id: "", quantidade: 1, valor_procedimento: 0 }); };
const removerItemPacote = (i: number) => { editandoPacote.value.itens.splice(i, 1); };

const salvarPacote = async () => {
  if (!editandoPacote.value.nome?.trim()) { erroPacote.value = "Informe o nome do pacote."; return; }
  if (!editandoPacote.value.validade_dias || editandoPacote.value.validade_dias < 1) { erroPacote.value = "Informe a validade em dias."; return; }
  const itensValidos = editandoPacote.value.itens.filter((i: any) => i.procedimento_id && i.quantidade > 0);
  if (!itensValidos.length) { erroPacote.value = "Adicione ao menos um item válido."; return; }

  salvandoPacote.value = true;
  try {
    const ehEdicao = !!editandoPacote.value.id;
    let pacoteId = editandoPacote.value.id;

    if (ehEdicao) {
      const { error } = await supabase.from("pacotes")
        .update({ nome: editandoPacote.value.nome, validade_dias: editandoPacote.value.validade_dias })
        .eq("id", pacoteId);
      if (error) throw error;
      await supabase.from("pacote_itens").delete().eq("pacote_id", pacoteId);
    } else {
      const { data, error } = await supabase.from("pacotes")
        .insert({ nome: editandoPacote.value.nome, validade_dias: editandoPacote.value.validade_dias })
        .select().single();
      if (error) throw error;
      pacoteId = data.id;
    }

    const { error: itensError } = await supabase.from("pacote_itens").insert(
      itensValidos.map((i: any) => ({ pacote_id: pacoteId, procedimento_id: i.procedimento_id, quantidade: i.quantidade, valor_procedimento: i.valor_procedimento || 0 }))
    );
    if (itensError) throw itensError;

    modalPacoteAberto.value = false;
    await carregarPacotes();
    sucesso(ehEdicao ? "Pacote atualizado com sucesso." : "Pacote criado com sucesso.");
  } catch (e: any) {
    erroPacote.value = e.message || "Não foi possível salvar o pacote.";
    toastErro("Não foi possível salvar o pacote.");
  } finally {
    salvandoPacote.value = false;
  }
};

const confirmarExclusaoPacote = (p: any) => { excluindoPacote.value = p; };
const excluirPacote = async () => {
  const { error } = await supabase.from("pacotes").delete().eq("id", excluindoPacote.value.id);
  excluindoPacote.value = null;
  if (error) {
    toastErro(error.code === "23503"
      ? "Este pacote já teve vendas registradas. Desative-o em vez de excluir."
      : "Não foi possível excluir o pacote.");
    return;
  }
  await carregarPacotes();
  sucesso("Pacote excluído com sucesso.");
};

const alternarAtivoPacote = async (p: any) => {
  const { error } = await supabase.from("pacotes").update({ ativo: !p.ativo }).eq("id", p.id);
  if (error) { toastErro("Não foi possível alterar o status do pacote."); return; }
  await carregarPacotes();
  sucesso(p.ativo ? "Pacote desativado." : "Pacote ativado.");
};

// ---------- vendas ----------
const modalVendaAberto = ref(false);
const vendaForm = ref<any>({ cliente_id: "", pacote_id: "" });
const erroVenda = ref("");
const salvandoVenda = ref(false);
const cancelando = ref<any>(null);
const reativando = ref<any>(null);
const reativarForm = ref<any>({ nova_validade: "", observacao: "" });
const erroReativar = ref("");
const salvandoReativar = ref(false);

const carregarVendas = async () => {
  const { data } = await supabase
    .from("pacote_vendas")
    .select("*, clientes(nome), pacote_venda_itens(*)")
    .order("data_compra", { ascending: false });
  vendas.value = data || [];
};

const pacoteEscolhido = computed(() => pacotes.value.find((p) => p.id === vendaForm.value.pacote_id));
const valorTotalVenda = computed(() =>
  (pacoteEscolhido.value?.pacote_itens || []).reduce((soma: number, i: any) => soma + Number(i.valor_procedimento || 0) * Number(i.quantidade || 0), 0)
);
const dataValidadeVenda = computed(() => {
  if (!pacoteEscolhido.value) return "";
  const d = new Date();
  d.setDate(d.getDate() + Number(pacoteEscolhido.value.validade_dias || 0));
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
});

const abrirVenda = () => {
  vendaForm.value = { cliente_id: "", pacote_id: "" };
  erroVenda.value = "";
  modalVendaAberto.value = true;
};

const salvarVenda = async () => {
  if (!vendaForm.value.cliente_id || !pacoteEscolhido.value) { erroVenda.value = "Selecione o cliente e o pacote."; return; }
  salvandoVenda.value = true;
  try {
    const { data: venda, error } = await supabase.from("pacote_vendas").insert({
      pacote_id: pacoteEscolhido.value.id,
      pacote_nome: pacoteEscolhido.value.nome,
      cliente_id: vendaForm.value.cliente_id,
      valor_total: valorTotalVenda.value,
      data_validade: dataValidadeVenda.value,
    }).select().single();
    if (error) throw error;

    const { error: itensError } = await supabase.from("pacote_venda_itens").insert(
      (pacoteEscolhido.value.pacote_itens || []).map((i: any) => ({
        pacote_venda_id: venda.id,
        procedimento_id: i.procedimento_id,
        procedimento_nome: i.procedimentos?.nome || "",
        quantidade_total: i.quantidade,
        valor_procedimento: i.valor_procedimento,
      }))
    );
    if (itensError) throw itensError;

    modalVendaAberto.value = false;
    await carregarVendas();
    sucesso("Venda de pacote registrada com sucesso.");
  } catch (e: any) {
    erroVenda.value = e.message || "Não foi possível registrar a venda.";
    toastErro("Não foi possível registrar a venda.");
  } finally {
    salvandoVenda.value = false;
  }
};

const estaVencido = (v: any) => v.data_validade < new Date().toISOString().slice(0, 10);
const badgeVenda = (v: any) => {
  if (v.status === "cancelado") return { texto: "Cancelado", classe: "badge-danger" };
  if (estaVencido(v)) return { texto: "Vencido", classe: "badge-warning" };
  return { texto: "Ativo", classe: "badge-success" };
};

const vendasFiltradas = computed(() => {
  const termo = buscaVenda.value.toLowerCase().trim();
  if (!termo) return vendas.value;
  return vendas.value.filter(
    (v) => (v.clientes?.nome || "").toLowerCase().includes(termo) || (v.pacote_nome || "").toLowerCase().includes(termo)
  );
});

const confirmarCancelamento = (v: any) => { cancelando.value = v; };
const cancelarVenda = async () => {
  const { error } = await supabase.from("pacote_vendas").update({ status: "cancelado" }).eq("id", cancelando.value.id);
  cancelando.value = null;
  if (error) { toastErro("Não foi possível cancelar o pacote."); return; }
  await carregarVendas();
  sucesso("Pacote cancelado.");
};

const abrirReativacao = (v: any) => {
  reativando.value = v;
  const d = new Date();
  d.setDate(d.getDate() + 30);
  reativarForm.value = { nova_validade: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`, observacao: "" };
  erroReativar.value = "";
};

const salvarReativacao = async () => {
  if (!reativarForm.value.nova_validade) { erroReativar.value = "Informe a nova data de validade."; return; }
  salvandoReativar.value = true;
  const { error } = await supabase.rpc("estender_validade_pacote", {
    p_pacote_venda_id: reativando.value.id,
    p_nova_validade: reativarForm.value.nova_validade,
    p_observacao: reativarForm.value.observacao || null,
  });
  salvandoReativar.value = false;
  if (error) { erroReativar.value = error.message; toastErro("Não foi possível reativar o pacote."); return; }
  reativando.value = null;
  await carregarVendas();
  sucesso("Validade estendida com sucesso.");
};

// ---------- utilidades ----------
const formatarValor = (v: number) => (v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
const formatarData = (dataHora: string) => {
  const d = new Date(dataHora);
  return d.toLocaleDateString("pt-BR") + " " + d.toTimeString().slice(0, 5);
};
const formatarDataCurta = (data: string) => {
  if (!data) return "—";
  const [ano, mes, dia] = data.split("-");
  return `${dia}/${mes}/${ano}`;
};

const carregarBase = async () => {
  const [{ data: proc }, { data: cli }] = await Promise.all([
    supabase.from("procedimentos").select("id, nome").eq("ativo", true).order("nome"),
    supabase.from("clientes").select("id, nome, telefone").eq("ativo", true).order("nome"),
  ]);
  procedimentos.value = proc || [];
  clientes.value = cli || [];
};

await Promise.all([carregarBase(), carregarPacotes(), carregarVendas()]);
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; gap: 12px; flex-wrap: wrap; }
.abas { display: flex; gap: 4px; border-bottom: 1px solid var(--border); margin-bottom: 16px; }
.aba { padding: 10px 16px; border: none; background: none; font-size: 14px; font-weight: 500; color: var(--ink-muted); border-bottom: 2px solid transparent; }
.aba.ativa { color: var(--primary-dark); border-bottom-color: var(--primary); }
.ajuda { color: var(--ink-muted); font-size: 13px; margin: 0 0 14px; }
.erro-msg { color: var(--danger); font-size: 13px; margin: 10px 0 0; }
.linha-item { display: flex; gap: 8px; align-items: center; margin-bottom: 8px; }
.btn-remover { padding: 6px 10px; color: var(--danger); }
.btn-add { align-self: flex-start; font-size: 13px; padding: 6px 10px; margin-bottom: 6px; }
.saldo-linha { font-size: 12px; color: var(--ink-muted); }
.resumo-venda { background: var(--bg); border-radius: 8px; padding: 12px 14px; font-size: 13px; margin: 10px 0 14px; }
.resumo-venda p { margin: 2px 0; }
</style>
