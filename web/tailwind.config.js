/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        // Cleanvest marka paleti - koyu tematik kurumsal finans
        ink: {
          900: "#070b14",
          800: "#0b1120",
          700: "#111a2e",
          600: "#1a2540",
          500: "#243257",
        },
        fx: {
          base: "#0ea5e9",
          glow: "#22d3ee",
          yield: "#34d399",
          gold: "#fbbf24",
          warn: "#f97316",
          danger: "#f43f5e",
        },
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "sans-serif"],
        mono: ["JetBrains Mono", "ui-monospace", "monospace"],
      },
      animation: {
        "pulse-slow": "pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        shimmer: "shimmer 2.5s linear infinite",
      },
      keyframes: {
        shimmer: {
          "0%": { backgroundPosition: "-1000px 0" },
          "100%": { backgroundPosition: "1000px 0" },
        },
      },
    },
  },
  plugins: [],
};
