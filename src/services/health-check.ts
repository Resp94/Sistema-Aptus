import { supabase } from './supabase'

export async function checkSupabaseHealth(): Promise<{ healthy: boolean; message: string }> {
  try {
    // Fazemos uma chamada simples à API do Supabase. Mesmo contra uma tabela inexistente, 
    // se o Supabase responder com erro de tabela inexistente (e não erro de conexão), 
    // significa que a API REST está ativa e respondendo.
    const { error } = await supabase.from('_health_check').select('*').limit(1)

    // Se o código de erro for PGRST116, PGRST205 ou 42P01, a API está saudável e acessível.
    // Erros de conexão ou CORS não retornam estes códigos específicos da base de dados.
    if (error && error.code !== 'PGRST116' && error.code !== '42P01' && error.code !== 'PGRST205') {
      return {
        healthy: false,
        message: `Falha na conexão REST: ${error.message} (Código: ${error.code})`,
      }
    }

    return {
      healthy: true,
      message: 'Conexão com a API REST do Supabase está ativa e saudável!',
    }
  } catch (err: any) {
    return {
      healthy: false,
      message: `Erro ao tentar conectar: ${err.message || err}`,
    }
  }
}
