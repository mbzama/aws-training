import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    // Proxy /users/* and /movies/* to the remote dev servers.
    // base: '/users' on the users app means all its assets are served under
    // /users/... so every proxied path resolves correctly.
    proxy: {
      '/users': { target: 'http://localhost:3001', changeOrigin: true },
      '/movies': { target: 'http://localhost:3002', changeOrigin: true },
    },
  },
})
