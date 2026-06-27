import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../aptus.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
