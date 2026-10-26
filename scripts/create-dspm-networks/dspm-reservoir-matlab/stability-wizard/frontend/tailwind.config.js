/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Dark wizard theme - deep blues and purples with accent highlights
        wizard: {
          // Backgrounds
          bg: {
            DEFAULT: '#0f0f1a',
            secondary: '#161625',
            tertiary: '#1e1e32',
          },
          // Panels and surfaces
          panel: {
            DEFAULT: '#1a1a2e',
            hover: '#222240',
            active: '#2a2a4a',
          },
          // Accent colors
          accent: {
            DEFAULT: '#6366f1',  // Indigo
            hover: '#818cf8',
            muted: '#4f46e5',
          },
          // Highlights
          highlight: {
            DEFAULT: '#e94560',  // Rose/red
            secondary: '#f472b6', // Pink
            tertiary: '#a855f7',  // Purple
          },
          // Text
          text: {
            DEFAULT: '#f1f5f9',
            secondary: '#94a3b8',
            muted: '#64748b',
            dim: '#475569',
          },
          // Semantic colors
          success: '#4ade80',
          warning: '#fbbf24',
          error: '#f87171',
          info: '#60a5fa',
          // Nullcline colors (for equations)
          nullcline: {
            1: '#e94560',
            2: '#4ade80',
            3: '#60a5fa',
            4: '#fbbf24',
            5: '#a78bfa',
            6: '#f472b6',
          },
          // Fixed point markers
          fp: {
            stable: '#4ade80',
            unstable: '#f87171',
            saddle: '#fbbf24',
            center: '#60a5fa',
          }
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'Fira Code', 'monospace'],
        math: ['STIX Two Math', 'Cambria Math', 'serif'],
      },
      boxShadow: {
        'wizard': '0 4px 20px rgba(99, 102, 241, 0.15)',
        'wizard-lg': '0 8px 40px rgba(99, 102, 241, 0.2)',
        'glow': '0 0 20px rgba(233, 69, 96, 0.3)',
        'glow-accent': '0 0 20px rgba(99, 102, 241, 0.4)',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'glow': 'glow 2s ease-in-out infinite alternate',
      },
      keyframes: {
        glow: {
          '0%': { boxShadow: '0 0 5px rgba(233, 69, 96, 0.2)' },
          '100%': { boxShadow: '0 0 20px rgba(233, 69, 96, 0.4)' },
        }
      },
      backgroundImage: {
        'grid-pattern': `linear-gradient(rgba(99, 102, 241, 0.03) 1px, transparent 1px),
                        linear-gradient(90deg, rgba(99, 102, 241, 0.03) 1px, transparent 1px)`,
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
      },
      backgroundSize: {
        'grid': '20px 20px',
      },
    },
  },
  plugins: [],
}
