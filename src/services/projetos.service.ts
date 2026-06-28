import { supabase } from './supabase';
import type { Projeto, ResumoProjetos, DistribuicaoCliente, TarefaKanban } from '../types/projetos';

export const projectsService = {
  async listarProjetos(): Promise<Projeto[]> {
    const { data, error } = await supabase.rpc('listar_projetos');
    if (error) throw error;
    return data ?? [];
  },

  async obterResumoProjetos(): Promise<ResumoProjetos> {
    const { data, error } = await supabase.rpc('obter_resumo_projetos');
    if (error) throw error;
    return data && data.length > 0
      ? data[0]
      : {
          projetos_ativos: 0,
          tarefas_abertas: 0,
          orcamento_total: 0,
          orcamento_utilizado_pct: 0,
          em_risco: 0,
        };
  },

  async obterDistribuicaoClientes(): Promise<DistribuicaoCliente[]> {
    const { data, error } = await supabase.rpc('obter_distribuicao_clientes');
    if (error) throw error;
    return data ?? [];
  },

  async listarTarefasKanban(): Promise<TarefaKanban[]> {
    const { data, error } = await supabase.rpc('listar_tarefas_kanban');
    if (error) throw error;
    return data ?? [];
  },

  async criarProjeto(projeto: {
    nome: string;
    cliente_id: string | null;
    orcamento: number;
    prazo: string | null;
    status?: string;
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_projeto', {
      p_nome: projeto.nome,
      p_cliente_id: projeto.cliente_id,
      p_orcamento: projeto.orcamento,
      p_prazo: projeto.prazo,
      p_status: projeto.status || 'Planejamento',
    });
    if (error) throw error;
    return data;
  },

  async atualizarProjeto(projeto: {
    id: string;
    nome: string;
    cliente_id: string | null;
    status: string;
    progresso: number;
    orcamento: number;
    orcamento_utilizado: number;
    em_risco: boolean;
    prazo: string | null;
  }): Promise<void> {
    const { error } = await supabase.rpc('atualizar_projeto', {
      p_projeto_id: projeto.id,
      p_nome: projeto.nome,
      p_cliente_id: projeto.cliente_id,
      p_status: projeto.status,
      p_progresso: projeto.progresso,
      p_orcamento: projeto.orcamento,
      p_orcamento_utilizado: projeto.orcamento_utilizado,
      p_em_risco: projeto.em_risco,
      p_prazo: projeto.prazo,
    });
    if (error) throw error;
  },

  async excluirProjeto(id: string): Promise<void> {
    const { error } = await supabase.rpc('excluir_projeto', { p_projeto_id: id });
    if (error) throw error;
  },

  async criarTarefa(tarefa: {
    projeto_id: string;
    titulo: string;
    prioridade?: string;
    responsavel_id?: string | null;
    prazo?: string | null;
    instrucoes?: string | null;
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_tarefa', {
      p_projeto_id: tarefa.projeto_id,
      p_titulo: tarefa.titulo,
      p_prioridade: tarefa.prioridade || 'Média',
      p_responsavel_id: tarefa.responsavel_id || null,
      p_prazo: tarefa.prazo || null,
      p_instrucoes: tarefa.instrucoes || null,
    });
    if (error) throw error;
    return data;
  },

  async atualizarTarefa(tarefa: {
    id: string;
    titulo: string;
    prioridade: string;
    responsavel_id: string | null;
    prazo: string | null;
    instrucoes: string | null;
  }): Promise<void> {
    const { error } = await supabase.rpc('atualizar_tarefa', {
      p_tarefa_id: tarefa.id,
      p_titulo: tarefa.titulo,
      p_prioridade: tarefa.prioridade,
      p_responsavel_id: tarefa.responsavel_id,
      p_prazo: tarefa.prazo,
      p_instrucoes: tarefa.instrucoes,
    });
    if (error) throw error;
  },

  async moverTarefa(id: string, situacao: string): Promise<void> {
    const { error } = await supabase.rpc('mover_tarefa', {
      p_tarefa_id: id,
      p_situacao: situacao,
    });
    if (error) throw error;
  },

  async excluirTarefa(id: string): Promise<void> {
    const { error } = await supabase.rpc('excluir_tarefa', { p_tarefa_id: id });
    if (error) throw error;
  },
};
