import { supabase } from './supabase';
import type { PerfilUsuario, PermissaoModulo } from '../types/auth';

export const authService = {
  async getPerfilUsuario(): Promise<PerfilUsuario | null> {
    const { data, error } = await supabase.rpc('obter_perfil_usuario');
    if (error) {
      console.error('Erro ao obter perfil do usuário:', error);
      throw error;
    }
    
    // Se data for nulo ou array vazio, trata como null profile
    if (!data || data.length === 0) {
      await this.signOut();
      throw new Error('Perfil não encontrado. Entre em contato com o administrador.');
    }
    
    const perfil = data[0] as PerfilUsuario;
    
    // Se o status for inativo, bloqueia
    if (perfil.status === 'Inativo') {
      await this.signOut();
      throw new Error('Conta desativada. Entre em contato com o administrador.');
    }
    
    return perfil;
  },

  async getPermissoesUsuario(): Promise<PermissaoModulo[]> {
    const { data, error } = await supabase.rpc('obter_permissoes_usuario');
    if (error) {
      console.error('Erro ao obter permissões do usuário:', error);
      throw error;
    }
    return (data ?? []) as PermissaoModulo[];
  },

  async signIn(email: string, password: string, remember: boolean = true): Promise<PerfilUsuario> {
    const normalizedEmail = email.trim().toLowerCase();
    
    // Silencia o aviso de variável não utilizada do TypeScript para remember
    remember;
    
    const { data, error } = await supabase.auth.signInWithPassword({
      email: normalizedEmail,
      password: password,
    });

    if (error) {
      console.error('Erro de autenticação no Supabase:', error);
      const msg = error.message.toLowerCase();
      
      // Registrar evento de auditoria para falha de login
      try {
        await supabase.rpc('registrar_evento_auditoria', {
          p_evento: 'login_falha',
          p_usuario_id: null,
          p_ip_origem: '127.0.0.1',
          p_user_agent: typeof window !== 'undefined' ? window.navigator.userAgent : 'System (Vitest)'
        });
      } catch (ae) {
        console.error('Erro ao gravar log de auditoria de falha:', ae);
      }

      // GoTrue retorna erro 400 para credenciais inválidas ou e-mail não confirmado
      if (msg.includes('email_not_confirmed') || msg.includes('confirm') || msg.includes('verified')) {
        throw new Error('Confirme seu e-mail antes de fazer login.');
      }
      if (msg.includes('invalid') || msg.includes('credentials') || error.status === 400) {
        throw new Error('E-mail ou senha inválidos.');
      }
      
      throw new Error('Serviço de autenticação temporariamente indisponível.');
    }

    if (!data.user) {
      throw new Error('Serviço de autenticação temporariamente indisponível.');
    }

    try {
      const perfil = await this.getPerfilUsuario();
      if (!perfil) {
        throw new Error('Perfil não encontrado. Entre em contato com o administrador.');
      }

      // Registrar evento de auditoria para sucesso de login
      try {
        await supabase.rpc('registrar_evento_auditoria', {
          p_evento: 'login_sucesso',
          p_usuario_id: data.user.id,
          p_ip_origem: '127.0.0.1',
          p_user_agent: typeof window !== 'undefined' ? window.navigator.userAgent : 'System (Vitest)'
        });
      } catch (ae) {
        console.error('Erro ao gravar log de auditoria de sucesso:', ae);
      }

      return perfil;
    } catch (e: any) {
      throw e;
    }
  },

  async signOut(): Promise<void> {
    const { error } = await supabase.auth.signOut();
    if (error) {
      console.error('Erro ao deslogar:', error);
    }
  },

  async resetPassword(email: string): Promise<void> {
    const normalizedEmail = email.trim().toLowerCase();
    const redirectUrl = `${window.location.origin}/reset-password`;
    
    const { error } = await supabase.auth.resetPasswordForEmail(normalizedEmail, {
      redirectTo: redirectUrl
    });
    
    if (error) {
      console.error('Erro ao solicitar redefinição de senha:', error);
      throw new Error('Erro ao processar a solicitação de redefinição de senha.');
    }
  }
};
