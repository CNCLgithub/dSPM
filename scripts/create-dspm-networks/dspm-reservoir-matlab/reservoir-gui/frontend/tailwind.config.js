/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Muted port colors - light mode
        'port-ext-in': {
          DEFAULT: '#9F5858',
          muted: '#9F585880',
          subtle: '#9F585820',
        },
        'port-ext-out': {
          DEFAULT: '#4A8F8A',
          muted: '#4A8F8A80',
          subtle: '#4A8F8A20',
        },
        'port-rec-in': {
          DEFAULT: '#4A5C7A',
          muted: '#4A5C7A80',
          subtle: '#4A5C7A20',
        },
        'port-rec-out': {
          DEFAULT: '#A68B4B',
          muted: '#A68B4B80',
          subtle: '#A68B4B20',
        },
      },
      boxShadow: {
        'soft': '0 2px 8px -2px rgba(0, 0, 0, 0.05), 0 4px 16px -4px rgba(0, 0, 0, 0.05)',
        'soft-lg': '0 4px 12px -2px rgba(0, 0, 0, 0.08), 0 8px 24px -4px rgba(0, 0, 0, 0.06)',
      },
    },
  },
  plugins: [],
};
