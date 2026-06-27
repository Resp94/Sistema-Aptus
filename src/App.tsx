import { useState, useEffect } from 'react';
import Login from './pages/Login';
import ResetPassword from './pages/ResetPassword';
import './App.css';

function App() {
  const [currentPath, setCurrentPath] = useState(window.location.pathname);
  const [hash, setHash] = useState(window.location.hash);

  useEffect(() => {
    const handleLocationChange = () => {
      setCurrentPath(window.location.pathname);
      setHash(window.location.hash);
    };

    window.addEventListener('popstate', handleLocationChange);
    // Também escuta alterações de hash
    window.addEventListener('hashchange', handleLocationChange);

    return () => {
      window.removeEventListener('popstate', handleLocationChange);
      window.removeEventListener('hashchange', handleLocationChange);
    };
  }, []);

  const isRecovery = hash.includes('type=recovery') || hash.includes('access_token=');

  if (isRecovery) {
    return <ResetPassword />;
  }

  // Roteamento SPA simples
  if (currentPath === '/login' || currentPath === '/' || currentPath === '/index.html') {
    return <Login />;
  }

  return (
    <div style={{ padding: '40px', textAlign: 'center', fontFamily: 'var(--font-body)', background: 'var(--bg)', color: 'var(--fg)', minHeight: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
      <h1 style={{ fontSize: '32px', marginBottom: '16px' }}>Módulo Não Migrado</h1>
      <p style={{ color: 'var(--muted)', marginBottom: '24px', maxWidth: '400px' }}>
        Este módulo ainda está no formato estático legado. Use o login para acessar os painéis correspondentes ao seu perfil de acesso.
      </p>
      <a href="/login" style={{ display: 'inline-block', padding: '10px 20px', background: 'var(--accent)', color: 'var(--accent-on)', borderRadius: 'var(--radius-md)', textDecoration: 'none', fontWeight: 'bold' }}>
        Ir para o Login
      </a>
    </div>
  );
}

export default App;
