<template>
  <div v-if="colaborador">
    <div class="cabecalho">
      <div>
        <NuxtLink to="/colaboradores" class="voltar">← Colaboradores</NuxtLink>
        <h1>{{ colaborador.nome }}</h1>
      </div>
      <button class="btn" :class="colaborador.ativo ? 'btn-danger' : 'btn-primary'" @click="alternarStatus">
        {{ colaborador.ativo ? 'Desativar' : 'Ativar' }}
      </button>
    </div>

    <div class="abas">
      <button v-for="a in abas" :key="a.chave" :class="['aba', { ativa: abaAtual === a.chave }]" @click="abaAtual = a.chave">
        {{ a.label }}
      </button>
    </div>

    <!-- DADOS -->
    <div v-if="abaAtual === 'dados'" class="card conteudo">
      <div class="field"><label>Nome</label><input v-model="colaborador.nome" class="input" /></div>
      <div class="field"><label>Telefone</label><input v-model="colaborador.telefone" class="input" /></div>
      <div class="field"><label>Cargo / Função</label><input v-model="colaborador.cargo" class="input" /></div>
      <button class="btn btn-primary" @click="salvarDados">Salvar dados</button>
    </div>

    <!-- PROCEDIMENTOS -->
    <div v-if="abaAtual === 'procedimentos'" class="card conteudo">
      <p class="ajuda">Marque os procedimentos que este colaborador pode realizar.</p>
      <label v-for="p in procedimentos" :key="p.id" class="linha-check">
        <input type="checkbox" v-model="procedimentosSelecionados" :value="p.id" />
        {{ p.nome }}
      </label>
      <button class="btn btn-primary" @click="salvarProcedimentos">Salvar procedimentos</button>
    </div>

    <!-- HORÁRIOS -->
    <div v-if="abaAtual === 'horarios'" class="card conteudo">
      <div v-for="dia in horarios" :key="dia.dia_semana" class="linha-horario">
        <span class="dia-nome">{{ nomeDia(dia.dia_semana) }}</span>
        <label class="folga-check">
          <input type="checkbox" v-model="dia.folga" /> Folga
        </label>
        <template v-if="!dia.folga">
          <input v-model="dia.horario_inicio" type="time" class="input" style="width:120px;" />
          <span>às</span>
          <input v-model="dia.horario_fim" type="time" class="input" style="width:120px;" />
        </template>
      </div>
      <button class="btn btn-primary" @click="salvarHorarios">Salvar horários</button>
    </div>

    <!-- COMISSÕES -->
    <div v-if="abaAtual === 'comissoes'" class="card conteudo">
      <p class="ajuda">Defina o percentual de comissão para cada procedimento que este colaborador realiza.</p>
      <div v-for="p in procedimentosHabilitadosObjs" :key="p.id" class="linha-comissao">
        <span style="flex:1;">{{ p.nome }}</span>
        <input v-model.number="comissoes[p.id]" type="number" min="0" max="100" step="0.5" class="input" style="width:100px;" />
        <span>%</span>
      </div>
      <p v-if="!procedimentosHabilitadosObjs.length" class="ajuda">Habilite procedimentos na aba "Procedimentos" primeiro.</p>
      <button class="btn btn-primary" @click="salvarComissoes">Salvar comissões</button>
    </div>

    <!-- PERMISSÕES -->
    <div v-if="abaAtual === 'permissoes'" class="card conteudo">
      <div v-for="grupo in gruposPermissoes" :key="grupo" class="grupo-permissao">
        <h3 class="grupo-titulo">{{ grupo }}</h3>
        <label v-for="p in permissoesPorGrupo(grupo)" :key="p.chave" class="linha-check">
          <input type="checkbox" v-model="permissoes[p.chave]" />
          {{ p.label }}
        </label>
      </div>
      <button class="btn btn-primary" @click="salvarPermissoes">Salvar permissões</button>
    </div>

  </div>
</template>

<script setup lang="ts">
import { PERMISSOES, DIAS_SEMANA } from "~/types/permissoes";

const route = useRoute();
const supabase = useSupabaseClient();
const { chamar } = useApi();
const { sucesso, erro: toastErro } = useToast();

const colaboradorId = route.params.id as string;

const colaborador = ref<any>(null);
const procedimentos = ref<any[]>([]);
const procedimentosSelecionados = ref<string[]>([]);
const horarios = ref<any[]>([]);
const comissoes = ref<Record<string, number>>({});
const permissoes = ref<Record<string, boolean>>({});

const abaAtual = ref("dados");
const abas = [
  { chave: "dados", label: "Dados" },
  { chave: "procedimentos", label: "Procedimentos" },
  { chave: "horarios", label: "Horários" },
  { chave: "comissoes", label: "Comissões" },
  { chave: "permissoes", label: "Permissões" },
];

const nomeDia = (v: number) => DIAS_SEMANA.find((d) => d.valor === v)?.label || v;
const gruposPermissoes = [...new Set(PERMISSOES.map((p) => p.grupo))];
const permissoesPorGrupo = (grupo: string) => PERMISSOES.filter((p) => p.grupo === grupo);

const procedimentosHabilitadosObjs = computed(() =>
  procedimentos.value.filter((p) => procedimentosSelecionados.value.includes(p.id))
);

const carregar = async () => {
  const [{ data: colab }, { data: procs }, { data: relProc }, { data: hor }, { data: com }, { data: perms }] = await Promise.all([
    supabase.from("colaboradores").select("*").eq("id", colaboradorId).single(),
    supabase.from("procedimentos").select("*").eq("ativo", true).order("nome"),
    supabase.from("colaborador_procedimentos").select("procedimento_id").eq("colaborador_id", colaboradorId),
    supabase.from("colaborador_horarios").select("*").eq("colaborador_id", colaboradorId),
    supabase.from("colaborador_comissoes").select("*").eq("colaborador_id", colaboradorId),
    supabase.from("colaborador_permissoes").select("*").eq("colaborador_id", colaboradorId),
  ]);

  colaborador.value = colab;
  procedimentos.value = procs || [];
  procedimentosSelecionados.value = (relProc || []).map((r: any) => r.procedimento_id);

  horarios.value = DIAS_SEMANA.map((d) => {
    const existente = (hor || []).find((h: any) => h.dia_semana === d.valor);
    return existente || { dia_semana: d.valor, folga: true, horario_inicio: "09:00", horario_fim: "18:00" };
  });

  comissoes.value = Object.fromEntries((com || []).map((c: any) => [c.procedimento_id, c.percentual]));
  permissoes.value = Object.fromEntries((perms || []).map((p: any) => [p.permissao, p.concedida]));
};

const salvarDados = async () => {
  const { error } = await supabase.from("colaboradores").update({
    nome: colaborador.value.nome, telefone: colaborador.value.telefone, cargo: colaborador.value.cargo,
  }).eq("id", colaboradorId);
  if (error) { toastErro("Não foi possível salvar os dados."); return; }
  sucesso("Dados salvos com sucesso.");
};

const salvarProcedimentos = async () => {
  await supabase.from("colaborador_procedimentos").delete().eq("colaborador_id", colaboradorId);
  if (procedimentosSelecionados.value.length) {
    const { error } = await supabase.from("colaborador_procedimentos").insert(
      procedimentosSelecionados.value.map((procedimento_id) => ({ colaborador_id: colaboradorId, procedimento_id }))
    );
    if (error) { toastErro("Não foi possível salvar os procedimentos."); return; }
  }
  sucesso("Procedimentos salvos com sucesso.");
};

const salvarHorarios = async () => {
  try {
    await chamar(`/colaboradores/${colaboradorId}/horarios`, { method: "PUT", body: { horarios: horarios.value } });
    sucesso("Horários salvos com sucesso.");
  } catch (e: any) {
    toastErro("Não foi possível salvar os horários.");
  }
};

const salvarComissoes = async () => {
  const lista = procedimentosHabilitadosObjs.value.map((p) => ({
    procedimento_id: p.id, percentual: comissoes.value[p.id] || 0,
  }));
  try {
    await chamar(`/colaboradores/${colaboradorId}/comissoes`, { method: "PUT", body: { comissoes: lista } });
    sucesso("Comissões salvas com sucesso.");
  } catch (e: any) {
    toastErro("Não foi possível salvar as comissões.");
  }
};

const salvarPermissoes = async () => {
  const lista = PERMISSOES.map((p) => ({ permissao: p.chave, concedida: !!permissoes.value[p.chave] }));
  try {
    await chamar(`/colaboradores/${colaboradorId}/permissoes`, { method: "PUT", body: { permissoes: lista } });
    sucesso("Permissões salvas com sucesso.");
  } catch (e: any) {
    toastErro("Não foi possível salvar as permissões.");
  }
};

const alternarStatus = async () => {
  const novoStatus = !colaborador.value.ativo;
  try {
    await chamar(`/colaboradores/${colaboradorId}/status`, { method: "PUT", body: { ativo: novoStatus } });
    colaborador.value.ativo = novoStatus;
    sucesso(novoStatus ? "Colaborador ativado." : "Colaborador desativado.");
  } catch (e: any) {
    toastErro("Não foi possível alterar o status.");
  }
};

await carregar();
</script>

<style scoped>
.cabecalho { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 18px; }
.voltar { color: var(--ink-muted); font-size: 13px; text-decoration: none; }
.abas { display: flex; gap: 4px; border-bottom: 1px solid var(--border); margin-bottom: 18px; }
.aba { background: none; border: none; padding: 10px 14px; font-size: 14px; color: var(--ink-muted); border-bottom: 2px solid transparent; }
.aba.ativa { color: var(--primary-dark); border-bottom-color: var(--primary); font-weight: 500; }
.conteudo { padding: 22px; max-width: 520px; }
.ajuda { color: var(--ink-muted); font-size: 13px; margin: 0 0 14px; }
.linha-check { display: flex; align-items: center; gap: 8px; padding: 7px 0; font-size: 14px; }
.linha-horario { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-bottom: 1px solid var(--border); }
.linha-horario:last-of-type { border-bottom: none; margin-bottom: 16px; }
.dia-nome { width: 80px; font-weight: 500; font-size: 14px; }
.folga-check { display: flex; align-items: center; gap: 6px; font-size: 13px; color: var(--ink-muted); width: 90px; }
.linha-comissao { display: flex; align-items: center; gap: 10px; padding: 7px 0; }
.grupo-permissao { margin-bottom: 16px; }
.grupo-titulo { font-size: 13px; color: var(--ink-muted); margin-bottom: 4px; }
</style>
