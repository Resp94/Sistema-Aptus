export interface Cliente {
  id: string;
  nome_contato: string;
  empresa: string;
  email: string | null;
  telefone: string | null;
  tipo: 'cliente' | 'fornecedor';
  status: 'Ativo' | 'Inativo';
  receita: number;
}

export interface Atendimento {
  id: string;
  data: string;
  descricao: string;
  responsavel: string;
}

export interface EstatisticasClientes {
  total_contatos: number;
  receita_acumulada: number;
  ativos: number;
  fornecedores: number;
}

export interface ClienteDetalhe {
  id: string;
  nome_contato: string;
  empresa: string;
  email: string | null;
  telefone: string | null;
  tipo: 'cliente' | 'fornecedor';
  status: 'Ativo' | 'Inativo';
  receita: number;
  historico: Atendimento[];
}
