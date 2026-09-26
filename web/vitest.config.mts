import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/__tests__/setup.ts'],
    // Teknik borc KAPANDI (gece turu 13, 2026-09-25): vitest --root . ile
    // calistirilinca lib/ altindaki 217 vendored OZ/forge-std hardhat testi
    // toplaniyor ve "164 FAILED - REGRESYON!" false alarm'i uretiyordu.
    // Bunlar BIZIM testlerimiz degil. lib/ + build artifaktlari haric tutulur.
    exclude: [
      '**/node_modules/**',
      '**/lib/**',
      '**/out/**',
      '**/cache/**',
      '**/dist/**',
      '**/.git/**',
    ],
  },
})
