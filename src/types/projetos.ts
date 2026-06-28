export interface Projeto {
  id: string;
  nome: string;
  cliente: string;
  status: 'Planejamento' | 'Em andamento' | 'Concluído';
  progresso: number;
  orcamento: number;
  orcamento_utilizado: number;
  em_risco: boolean;
  prazo: string | null;
}

export interface Tarefa {
  id: string;
  projeto_id: string;
  projeto: string;
  titulo: string;
  situacao: 'A Fazer' | 'Em Andamento' | 'Concluído';
  prioridade: 'Alta' | 'Média' | 'Baixa';
  responsavel: string;
  prazo: string | null;
  instrucoes: string | null;
  ordem: number;
}

export interface ResumoProjetos {
  projetos_ativos: number;
  tarefas_abertas: number;
  orcamento_total: number;
  orcamento_utilizado_pct: number;
  em_risco: number;
}

export interface DistribuicaoCliente {
  cliente: string;
  percentual: number;
}

export type TarefaKanban = Tarefa;
