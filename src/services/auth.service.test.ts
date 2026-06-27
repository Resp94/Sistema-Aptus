import { describe, it, expect, beforeAll } from 'vitest';
import { authService } from './auth.service';
import { supabase } from './supabase';

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
