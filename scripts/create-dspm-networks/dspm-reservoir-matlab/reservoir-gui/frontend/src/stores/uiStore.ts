import { create } from 'zustand';

interface UIState {
  // Theme
  isDarkMode: boolean;
  
  // Header visibility (controlled by MATLAB or URL param)
  showHeader: boolean;
  
  // Network schematic state
  isClosedLoop: boolean;
  selectedEquationIndex: number | null;
  
  // Panel visibility
  showParameterPanel: boolean;
  
  // Status messages
  statusMessage: string;
  statusType: 'info' | 'success' | 'warning' | 'error';
  
  // Actions
  toggleDarkMode: () => void;
  setDarkMode: (dark: boolean) => void;
  setShowHeader: (show: boolean) => void;
  toggleLoop: () => void;
  setClosedLoop: (closed: boolean) => void;
  selectEquation: (index: number | null) => void;
  toggleParameterPanel: () => void;
  setStatus: (message: string, type?: 'info' | 'success' | 'warning' | 'error') => void;
  clearStatus: () => void;
}

// Detect system dark mode preference
const getSystemDarkModePreference = (): boolean => {
  if (typeof window !== 'undefined' && window.matchMedia) {
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  return false;
};

// Get initial dark mode and apply to document
const initialDarkMode = getSystemDarkModePreference();
if (typeof document !== 'undefined') {
  if (initialDarkMode) {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
}

export const useUIStore = create<UIState>((set) => ({
  isDarkMode: initialDarkMode,
  showHeader: true, // Default to showing header
  isClosedLoop: false,
  selectedEquationIndex: null,
  showParameterPanel: true,
  statusMessage: 'Ready',
  statusType: 'info',

  toggleDarkMode: () => set((state) => {
    const newDarkMode = !state.isDarkMode;
    // Update document class for Tailwind dark mode
    if (newDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
    return { isDarkMode: newDarkMode };
  }),
  
  setDarkMode: (dark) => {
    if (dark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
    set({ isDarkMode: dark });
  },

  setShowHeader: (show) => set({ showHeader: show }),

  toggleLoop: () => set((state) => ({ isClosedLoop: !state.isClosedLoop })),
  
  setClosedLoop: (closed) => set({ isClosedLoop: closed }),
  
  selectEquation: (index) => set({ selectedEquationIndex: index }),
  
  toggleParameterPanel: () => set((state) => ({ 
    showParameterPanel: !state.showParameterPanel 
  })),
  
  setStatus: (message, type = 'info') => set({ 
    statusMessage: message, 
    statusType: type 
  }),
  
  clearStatus: () => set({ 
    statusMessage: 'Ready', 
    statusType: 'info' 
  }),
}));
