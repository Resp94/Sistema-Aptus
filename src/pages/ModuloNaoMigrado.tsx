import { Link } from 'react-router-dom'

export default function ModuloNaoMigrado() {
  return (
    <div style={{ padding: '40px', textAlign: 'center', fontFamily: 'var(--font-body)', background: 'var(--bg)', color: 'var(--fg)', minHeight: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
      <h1 style={{ fontSize: '32px', marginBottom: '16px' }}>Módulo Não Migrado</h1>
      <p style={{ color: 'var(--muted)', marginBottom: '24px', maxWidth: '400px' }}>
        Esta tela ainda não foi convertida para React. Use o Dashboard enquanto a migração avança.
      </p>
      <Link to="/dashboard" style={{ display: 'inline-block', padding: '10px 20px', background: 'var(--accent)', color: 'var(--accent-on)', borderRadius: 'var(--radius-md)', textDecoration: 'none', fontWeight: 'bold' }}>
        Ir para o Dashboard
      </Link>
    </div>
  )
}
