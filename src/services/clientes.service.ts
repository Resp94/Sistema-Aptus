import { supabase } from './supabase';
import type { Cliente, EstatisticasClientes, ClienteDetalhe } from '../types/clientes';

export const clientesService = {
  async listarClientes(
    tipo: 'cliente' | 'fornecedor' | null = null,
    busca: string | null = null,
    status: 'Ativo' | 'Inativo' | null = null
  ): Promise<Cliente[]> {
    const { data, error } = await supabase.rpc('listar_clientes', {
      p_tipo: tipo,
      p_busca: busca,
      p_status: status,
    });
    if (error) throw error;
    return data ?? [];
  },

  async obterEstatisticasClientes(): Promise<EstatisticasClientes> {
    const { data, error } = await supabase.rpc('obter_estatisticas_clientes');
    if (error) throw error;
    return data && data.length > 0
      ? data[0]
      : {
          total_contatos: 0,
          receita_acumulada: 0,
          ativos: 0,
          fornecedores: 0,
        };
  },

  async obterClienteDetalhe(clienteId: string): Promise<ClienteDetalhe> {
    const { data, error } = await supabase.rpc('obter_cliente_detalhe', {
      p_cliente_id: clienteId,
    });
    if (error) throw error;
    return data as ClienteDetalhe;
  },

  async criarCliente(cliente: {
    nome_contato: string;
    empresa: string;
    email: string | null;
    telefone: string | null;
    tipo: 'cliente' | 'fornecedor';
  }): Promise<string> {
    const { data, error } = await supabase.rpc('criar_cliente', {
      p_nome_contato: cliente.nome_contato,
      p_empresa: cliente.empresa,
      p_email: cliente.email,
      p_telefone: cliente.telefone,
      p_tipo: cliente.tipo,
    });
    if (error) throw error;
    return data;
  },

  async atualizarCliente(cliente: {
    id: string;
    nome_contato: string;
    empresa: string;
    email: string | null;
    telefone: string | null;
    tipo: 'cliente' | 'fornecedor';
    status: 'Ativo' | 'Inativo';
  }): Promise<void> {
    const { error } = await supabase.rpc('atualizar_cliente', {
      p_cliente_id: cliente.id,
      p_nome_contato: cliente.nome_contato,
      p_empresa: cliente.empresa,
      p_email: cliente.email,
      p_telefone: cliente.telefone,
      p_tipo: cliente.tipo,
      p_status: cliente.status,
    });
    if (error) throw error;
  },

  async inativarCliente(id: string): Promise<void> {
    const { error } = await supabase.rpc('inativar_cliente', {
      p_cliente_id: id,
    });
    if (error) throw error;
  },

  async registrarAtendimento(
    clienteId: string,
    descricao: string,
    data: string | null = null
  ): Promise<string> {
    const { data: id, error } = await supabase.rpc('registrar_atendimento', {
      p_cliente_id: clienteId,
      p_descricao: descricao,
      p_data: data || undefined,
    });
    if (error) throw error;
    return id;
  },
};
export type ClientesService = typeof clientesService;
