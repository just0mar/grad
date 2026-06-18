/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#4CAF50',
          dark: '#1B6B3A',
          light: '#66BB6A',
          50: '#E8F5E9',
          100: '#C8E6C9',
          200: '#A5D6A7',
          300: '#81C784',
          400: '#66BB6A',
          500: '#4CAF50',
          600: '#43A047',
          700: '#388E3C',
          800: '#2E7D32',
          900: '#1B5E20',
        },
        accent: {
          DEFAULT: '#9C27B0',
          light: '#BA68C8',
          dark: '#7B1FA2',
        },
        surface: {
          dark: '#1B3A2D',
          darker: '#0A1F15',
          darkest: '#020806',
        },
        event: {
          match: '#0D47A1',
          'match-light': '#1976D2',
          training: '#1B5E20',
          'training-light': '#2E7D32',
          meeting: '#66BB6A',
          'meeting-light': '#4CAF50',
          test: '#082E6F',
          'test-light': '#0D47A1',
        },
      },
      fontFamily: {
        sans: ['Inter', 'SF Pro', 'system-ui', 'sans-serif'],
        display: ['Facon', 'Inter', 'sans-serif'],
      },
      fontSize: {
        'nav': ['11px', { lineHeight: '1.2', fontWeight: '700' }],
        'badge': ['11px', { lineHeight: '1.2', fontWeight: '700' }],
        'body-sm': ['13px', { lineHeight: '1.4' }],
        'body': ['14px', { lineHeight: '1.5' }],
        'body-lg': ['16px', { lineHeight: '1.5' }],
        'card-title': ['18px', { lineHeight: '1.3', fontWeight: '700' }],
        'section': ['18px', { lineHeight: '1.3', fontWeight: '700', letterSpacing: '0.075em' }],
        'heading': ['22px', { lineHeight: '1.3', fontWeight: '700', letterSpacing: '0.075em' }],
        'title': ['24px', { lineHeight: '1.3', fontWeight: '700' }],
        'splash': ['26px', { lineHeight: '1.3', fontWeight: '700', letterSpacing: '0.1em' }],
      },
      borderRadius: {
        'card': '12px',
        'event': '16px',
        'pill': '20px',
      },
      spacing: {
        '4.5': '18px',
        '13': '52px',
        '15': '60px',
        '18': '72px',
        'nav': '56px',
      },
      animation: {
        'spin-slow': 'spin 5s linear infinite',
      },
      minHeight: {
        'touch': '44px',
      },
      minWidth: {
        'touch': '44px',
      },
    },
  },
  plugins: [],
};
