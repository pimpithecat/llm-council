import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // Load env from parent directory (root .env)
  const rootEnv = loadEnv(mode, process.cwd() + '/..', '')
  const frontendPort = parseInt(rootEnv.FRONTEND_PORT || '5173', 10)
  
  return {
    plugins: [react()],
    server: {
      host: true, // Listen on all network interfaces (0.0.0.0)
      port: frontendPort,
      strictPort: true, // Fail if port is already in use (don't auto-switch)
    },
  }
})
