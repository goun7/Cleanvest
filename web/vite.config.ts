import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    rolldownOptions: {
      output: {
        // ethers (~500kB) ayri chunk -> ana bundle kucuk kalir
        advancedChunks: {
          groups: [
            { name: 'ethers', test: /node_modules\/ethers/ },
            { name: 'react', test: /node_modules\/(react|react-dom|scheduler)/ },
          ],
        },
      },
    },
  },
})
