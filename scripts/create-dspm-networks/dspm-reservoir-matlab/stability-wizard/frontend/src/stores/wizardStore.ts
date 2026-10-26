/**
 * Stability Wizard - Zustand Store
 * 
 * Central state management for the stability wizard application.
 * Handles communication with MATLAB backend via postMessage.
 */

import { create } from 'zustand';
import type {
  DynamicalEquation,
  SystemConstant,
  StateVariable,
  FixedPoint,
  AnalysisResult,
  ViewBounds,
  AxisSelection,
  TrajectoryData,
  ChatMessage,
  TabId,
} from '@/types';
import { NULLCLINE_COLORS, DEFAULT_VIEW_BOUNDS } from '@/constants/defaults';

// ============================================
// STORE STATE INTERFACE
// ============================================

interface WizardState {
  // Connection state
  isConnected: boolean;
  systemName: string;
  
  // Dynamical system definition
  equations: DynamicalEquation[];
  constants: SystemConstant[];
  stateVariables: StateVariable[];
  
  // Analysis results from MATLAB
  fixedPoints: FixedPoint[];
  analysisResult: AnalysisResult | null;
  isAnalyzing: boolean;
  
  // Navigation
  activeTab: TabId;
  
  // Visualization settings
  viewBounds: ViewBounds;
  selectedAxes: AxisSelection;
  showNullclines: boolean;
  showFixedPoints: boolean;
  showTrajectories: boolean;
  showGrid: boolean;
  is3DMode: boolean;
  arrowDensity: number;
  
  // Trajectories
  trajectories: TrajectoryData[];
  
  // Wiki
  currentWikiPage: string;
  
  // Chat
  chatMessages: ChatMessage[];
  isChatLoading: boolean;
  
  // ============================================
  // ACTIONS
  // ============================================
  
  // Connection
  setConnected: (connected: boolean) => void;
  setSystemName: (name: string) => void;
  
  // System definition
  setEquations: (equations: DynamicalEquation[]) => void;
  toggleEquation: (index: number) => void;
  setEquationColor: (index: number, color: string) => void;
  setConstants: (constants: SystemConstant[]) => void;
  updateConstant: (name: string, value: number) => void;
  updateConstantBounds: (name: string, min: number, max: number) => void;
  setStateVariables: (variables: StateVariable[]) => void;
  updateStateVariable: (name: string, value: number) => void;
  updateStateVariableBounds: (name: string, min: number, max: number) => void;
  
  // Analysis
  setFixedPoints: (fps: FixedPoint[]) => void;
  setAnalysisResult: (result: AnalysisResult | null) => void;
  setIsAnalyzing: (analyzing: boolean) => void;
  
  // Navigation
  setActiveTab: (tab: TabId) => void;
  
  // Visualization
  setViewBounds: (bounds: Partial<ViewBounds>) => void;
  resetViewBounds: () => void;
  zoomIn: () => void;
  zoomOut: () => void;
  setSelectedAxes: (axes: Partial<AxisSelection>) => void;
  toggleNullclines: () => void;
  toggleFixedPoints: () => void;
  toggleTrajectories: () => void;
  toggleGrid: () => void;
  toggle3DMode: () => void;
  setArrowDensity: (density: number) => void;
  
  // Trajectories
  addTrajectory: (ic: number[], color?: string) => void;
  removeTrajectory: (index: number) => void;
  clearTrajectories: () => void;
  updateTrajectoryData: (index: number, points: number[][]) => void;
  
  // Wiki
  setCurrentWikiPage: (page: string) => void;
  
  // Chat
  addChatMessage: (message: Omit<ChatMessage, 'id' | 'timestamp'>) => void;
  clearChatMessages: () => void;
  setIsChatLoading: (loading: boolean) => void;
  
  // MATLAB Communication
  requestAnalysis: () => void;
  requestNullclineData: () => void;
  requestFlowFieldData: () => void;
  requestTrajectory: (ic: number[], duration: number) => void;
  applySuggestion: (actionId: string) => void;
}

// ============================================
// CREATE STORE
// ============================================

export const useWizardStore = create<WizardState>((set, get) => ({
  // Initial state
  isConnected: false,
  systemName: '',
  
  equations: [],
  constants: [],
  stateVariables: [],
  
  fixedPoints: [],
  analysisResult: null,
  isAnalyzing: false,
  
  activeTab: 'nullcline',
  
  viewBounds: { ...DEFAULT_VIEW_BOUNDS },
  selectedAxes: { x: 0, y: 1 },
  showNullclines: true,
  showFixedPoints: true,
  showTrajectories: true,
  showGrid: true,
  is3DMode: false,
  arrowDensity: 20,
  
  trajectories: [],
  
  currentWikiPage: 'introduction',
  
  chatMessages: [
    {
      id: 'welcome',
      role: 'assistant',
      content: 'Welcome to the Stability Wizard! I can help you understand your dynamical system, analyze fixed points, and suggest improvements for reservoir compatibility. What would you like to know?',
      timestamp: new Date(),
    },
  ],
  isChatLoading: false,
  
  // ============================================
  // ACTION IMPLEMENTATIONS
  // ============================================
  
  setConnected: (connected) => set({ isConnected: connected }),
  setSystemName: (name) => set({ systemName: name }),
  
  setEquations: (equations) => set({
    equations: equations.map((eq, i) => ({
      ...eq,
      color: eq.color || NULLCLINE_COLORS[i % NULLCLINE_COLORS.length],
      enabled: eq.enabled ?? true,
    })),
  }),
  
  toggleEquation: (index) => set((state) => ({
    equations: state.equations.map((eq, i) =>
      i === index ? { ...eq, enabled: !eq.enabled } : eq
    ),
  })),
  
  setEquationColor: (index, color) => set((state) => ({
    equations: state.equations.map((eq, i) =>
      i === index ? { ...eq, color } : eq
    ),
  })),
  
  setConstants: (constants) => set({ constants }),
  
  updateConstant: (name, value) => {
    set((state) => ({
      constants: state.constants.map((c) =>
        c.name === name ? { ...c, value } : c
      ),
    }));
    // Notify MATLAB
    sendToMatlab({ type: 'UPDATE_CONSTANT', payload: { name, value } });
  },
  
  updateConstantBounds: (name, min, max) => set((state) => ({
    constants: state.constants.map((c) =>
      c.name === name ? { ...c, min, max } : c
    ),
  })),
  
  setStateVariables: (variables) => set({ stateVariables: variables }),
  
  updateStateVariable: (name, value) => {
    set((state) => ({
      stateVariables: state.stateVariables.map((v) =>
        v.name === name ? { ...v, value } : v
      ),
    }));
    sendToMatlab({ type: 'UPDATE_STATE', payload: { name, value } });
  },
  
  updateStateVariableBounds: (name, min, max) => set((state) => ({
    stateVariables: state.stateVariables.map((v) =>
      v.name === name ? { ...v, min, max } : v
    ),
  })),
  
  setFixedPoints: (fps) => set({ fixedPoints: fps }),
  setAnalysisResult: (result) => set({ analysisResult: result }),
  setIsAnalyzing: (analyzing) => set({ isAnalyzing: analyzing }),
  
  setActiveTab: (tab) => set({ activeTab: tab }),
  
  setViewBounds: (bounds) => set((state) => ({
    viewBounds: { ...state.viewBounds, ...bounds },
  })),
  
  resetViewBounds: () => set({ viewBounds: { ...DEFAULT_VIEW_BOUNDS } }),
  
  zoomIn: () => set((state) => {
    const { viewBounds } = state;
    const scale = 0.8;
    const xCenter = (viewBounds.xMin + viewBounds.xMax) / 2;
    const yCenter = (viewBounds.yMin + viewBounds.yMax) / 2;
    const xRange = (viewBounds.xMax - viewBounds.xMin) * scale / 2;
    const yRange = (viewBounds.yMax - viewBounds.yMin) * scale / 2;
    return {
      viewBounds: {
        ...viewBounds,
        xMin: xCenter - xRange,
        xMax: xCenter + xRange,
        yMin: yCenter - yRange,
        yMax: yCenter + yRange,
      },
    };
  }),
  
  zoomOut: () => set((state) => {
    const { viewBounds } = state;
    const scale = 1.25;
    const xCenter = (viewBounds.xMin + viewBounds.xMax) / 2;
    const yCenter = (viewBounds.yMin + viewBounds.yMax) / 2;
    const xRange = (viewBounds.xMax - viewBounds.xMin) * scale / 2;
    const yRange = (viewBounds.yMax - viewBounds.yMin) * scale / 2;
    return {
      viewBounds: {
        ...viewBounds,
        xMin: xCenter - xRange,
        xMax: xCenter + xRange,
        yMin: yCenter - yRange,
        yMax: yCenter + yRange,
      },
    };
  }),
  
  setSelectedAxes: (axes) => set((state) => ({
    selectedAxes: { ...state.selectedAxes, ...axes },
  })),
  
  toggleNullclines: () => set((state) => ({ showNullclines: !state.showNullclines })),
  toggleFixedPoints: () => set((state) => ({ showFixedPoints: !state.showFixedPoints })),
  toggleTrajectories: () => set((state) => ({ showTrajectories: !state.showTrajectories })),
  toggleGrid: () => set((state) => ({ showGrid: !state.showGrid })),
  toggle3DMode: () => set((state) => ({ is3DMode: !state.is3DMode })),
  setArrowDensity: (density) => set({ arrowDensity: density }),
  
  addTrajectory: (ic, color) => set((state) => {
    const colorIndex = state.trajectories.length;
    return {
      trajectories: [
        ...state.trajectories,
        {
          ic,
          points: [ic],
          color: color || `hsl(${colorIndex * 60}, 70%, 50%)`,
        },
      ],
    };
  }),
  
  removeTrajectory: (index) => set((state) => ({
    trajectories: state.trajectories.filter((_, i) => i !== index),
  })),
  
  clearTrajectories: () => set({ trajectories: [] }),
  
  updateTrajectoryData: (index, points) => set((state) => ({
    trajectories: state.trajectories.map((t, i) =>
      i === index ? { ...t, points } : t
    ),
  })),
  
  setCurrentWikiPage: (page) => set({ currentWikiPage: page }),
  
  addChatMessage: (message) => set((state) => ({
    chatMessages: [
      ...state.chatMessages,
      {
        ...message,
        id: `msg-${Date.now()}`,
        timestamp: new Date(),
      },
    ],
  })),
  
  clearChatMessages: () => set({
    chatMessages: [{
      id: 'welcome',
      role: 'assistant',
      content: 'Chat cleared. How can I help you?',
      timestamp: new Date(),
    }],
  }),
  
  setIsChatLoading: (loading) => set({ isChatLoading: loading }),
  
  // MATLAB Communication
  requestAnalysis: () => {
    set({ isAnalyzing: true });
    const state = get();
    sendToMatlab({
      type: 'REQUEST_ANALYSIS',
      payload: {
        equations: state.equations,
        constants: state.constants,
      },
    });
  },
  
  requestNullclineData: () => {
    const state = get();
    sendToMatlab({
      type: 'REQUEST_NULLCLINE',
      payload: {
        equations: state.equations.filter((e) => e.enabled),
        constants: state.constants,
        viewBounds: state.viewBounds,
        selectedAxes: state.selectedAxes,
      },
    });
  },
  
  requestFlowFieldData: () => {
    const state = get();
    sendToMatlab({
      type: 'REQUEST_FLOWFIELD',
      payload: {
        equations: state.equations,
        constants: state.constants,
        viewBounds: state.viewBounds,
        selectedAxes: state.selectedAxes,
        density: state.arrowDensity,
      },
    });
  },
  
  requestTrajectory: (ic, duration) => {
    sendToMatlab({
      type: 'REQUEST_TRAJECTORY',
      payload: { initialCondition: ic, duration },
    });
  },
  
  applySuggestion: (actionId) => {
    sendToMatlab({
      type: 'APPLY_SUGGESTION',
      payload: { actionId },
    });
  },
}));

// ============================================
// MATLAB COMMUNICATION HELPERS
// ============================================

function sendToMatlab(message: { type: string; payload: unknown }) {
  if (typeof window !== 'undefined' && window.parent !== window) {
    window.parent.postMessage(message, '*');
  } else {
    console.log('[Wizard → MATLAB]', message);
  }
}

// Message handler for MATLAB responses
if (typeof window !== 'undefined') {
  window.addEventListener('message', (event) => {
    const { type, payload } = event.data || {};
    if (!type) return;
    
    const store = useWizardStore.getState();
    
    switch (type) {
      case 'SYSTEM_UPDATE':
        store.setEquations(payload.equations || []);
        store.setConstants(payload.constants || []);
        store.setStateVariables(payload.stateVariables || []);
        store.setSystemName(payload.name || '');
        store.setConnected(true);
        break;
        
      case 'ANALYSIS_RESULT':
        store.setFixedPoints(payload.fixedPoints || []);
        store.setAnalysisResult(payload);
        store.setIsAnalyzing(false);
        break;
        
      case 'NULLCLINE_DATA':
        // TODO: Handle nullcline data for visualization
        break;
        
      case 'FLOWFIELD_DATA':
        // TODO: Handle flow field data for visualization
        break;
        
      case 'TRAJECTORY_RESULT':
        // TODO: Update trajectory with simulation results
        break;
        
      case 'ERROR':
        console.error('[MATLAB Error]', payload);
        store.setIsAnalyzing(false);
        break;
        
      case 'DISCONNECT':
        store.setConnected(false);
        break;
    }
  });
}

// Export store hook
export default useWizardStore;
