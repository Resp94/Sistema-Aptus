import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import { authService } from './auth.service';
import { supabase } from './supabase';
import { mockSupabaseRpc, restaurarMocksRpc } from './rpc-test-utils';

describe('Auth Service Integration Tests (Personas & Edge Cases)', () => {
  // A senha configurada no seed é 'SenhaDeTesteSegura123!' como fallback
  const testPassword = 'SenhaDeTesteSegura123!';

  beforeAll(async () => {
    // Garante que qualquer sessão anterior seja encerrada antes dos testes
    await authService.signOut();
  });

  const testPersonaLogin = async (email: string, expectedAccess: string) => {
    const perfil = await authService.signIn(email, testPassword);
    expect(perfil).toBeDefined();
    expect(perfil?.perfil_acesso).toBe(expectedAccess);
    expect(perfil?.status).toBe('Ativo');
    
    // Verifica se a sessão do Supabase foi de fato estabelecida
    const { data: { session } } = await supabase.auth.getSession();
    expect(session).not.toBeNull();
    expect(session?.user?.email).toBe(email);

    // Faz logout para limpar o estado para o próximo teste
    await authService.signOut();
  };

  it('deve conseguir autenticar a persona Administrador', async () => {
    await testPersonaLogin('admin@aptusflow.local', 'Administrador');
  });

  it('deve conseguir autenticar a persona Analista Financeiro', async () => {
    await testPersonaLogin('financeiro@aptusflow.local', 'Financeiro');
  });

  it('deve conseguir autenticar a persona Gerente de Projetos', async () => {
    await testPersonaLogin('projetos@aptusflow.local', 'Projetos');
  });

  it('deve conseguir autenticar a persona Consultor Comercial', async () => {
    await testPersonaLogin('comercial@aptusflow.local', 'Comercial');
  });

  it('deve conseguir autenticar a persona Profissional Técnico', async () => {
    await testPersonaLogin('tecnico@aptusflow.local', 'Técnico');
  });

  // Edge Cases (T025)
  it('deve lançar erro genérico ao tentar logar com senha incorreta (SC-003)', async () => {
    await expect(
      authService.signIn('admin@aptusflow.local', 'senha_incorreta_qualquer')
    ).rejects.toThrowError('E-mail ou senha inválidos.');
  });

  it('deve lançar erro genérico ao tentar logar com e-mail inexistente (SC-005)', async () => {
    await expect(
      authService.signIn('inexistente@aptusflow.local', testPassword)
    ).rejects.toThrowError('E-mail ou senha inválidos.');
  });
});

describe('getCapacidadesUsuario (mocked)', () => {
  afterEach(() => {
    restaurarMocksRpc();
  });

  it('deve chamar somente a RPC obter_capacidades_usuario e retornar a lista', async () => {
    const mockCapacidades = ['clientes.criar', 'clientes.editar'];
    const mockRpc = mockSupabaseRpc('obter_capacidades_usuario', mockCapacidades);

    const res = await authService.getCapacidadesUsuario();

    expect(mockRpc).toHaveBeenCalledWith('obter_capacidades_usuario');
    expect(res).toEqual(mockCapacidades);
  });

  it('deve retornar lista vazia quando a RPC retorna null (sessão vazia)', async () => {
    mockSupabaseRpc('obter_capacidades_usuario', null);

    const res = await authService.getCapacidadesUsuario();

    expect(res).toEqual([]);
  });

  it('deve propagar o erro quando a RPC falha', async () => {
    mockSupabaseRpc('obter_capacidades_usuario', null, { message: 'Erro simulado' });

    await expect(authService.getCapacidadesUsuario()).rejects.toBeTruthy();
  });
});
