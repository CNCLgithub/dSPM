/**
 * Stability Wizard - Type Definitions
 * 
 * Central type definitions for the stability wizard application.
 */

// ============================================
// DYNAMICAL SYSTEM TYPES
// ============================================

/** A single dynamical equation ẏᵢ = f(y) */
export interface DynamicalEquation {
  /** 1-based index corresponding to output variable */
  index: number;
  /** LaTeX representation of the equation RHS */
  latex: string;
  /** Time constant for this equation */
  tau: string | number;
  /** Whether this equation is shown in visualizations */
  enabled: boolean;
  /** Display color for nullcline visualization */
  color: string;
  /** Optional human-readable description */
  description?: string;
  /** 'recurrent' or 'external' output type */
  outputType: 'recurrent' | 'external';
}

/** A constant/parameter in the dynamical system */
export interface SystemConstant {
  /** LaTeX name (e.g., "\\sigma", "\\beta") */
  name: string;
  /** Current numeric value */
  value: number;
  /** Slider minimum bound */
  min: number;
  /** Slider maximum bound */
  max: number;
  /** Slider step size */
  step: number;
  /** Optional display name */
  displayName?: string;
  /** Optional description */
  description?: string;
}

/** A state variable (recurrent y or external x) */
export interface StateVariable {
  /** Internal name (y1, y2, x1, etc.) */
  name: string;
  /** Display name with subscript (y₁, y₂, etc.) */
  displayName: string;
  /** Current slider value */
  value: number;
  /** Slider minimum */
  min: number;
  /** Slider maximum */
  max: number;
  /** Slider step */
  step: number;
  /** True if this is an external input (x), false if recurrent (y) */
  isExternal: boolean;
  /** Display color */
  color?: string;
}

// ============================================
// EIGENANALYSIS TYPES
// ============================================

/** A single eigenvalue (possibly complex) */
export interface Eigenvalue {
  real: number;
  imag: number;
}

/** Classification of fixed point stability */
export type StabilityType = 'stable' | 'unstable' | 'saddle' | 'center' | 'unknown';

/** A fixed point of the dynamical system */
export interface FixedPoint {
  /** Index for identification */
  id: number;
  /** Coordinates in state space */
  coordinates: number[];
  /** Eigenvalues of the Jacobian at this point */
  eigenvalues: Eigenvalue[];
  /** Stability classification */
  stability: StabilityType;
  /** Optional: the Jacobian matrix */
  jacobian?: number[][];
}

// ============================================
// VISUALIZATION TYPES
// ============================================

/** Bounds for 2D/3D visualization */
export interface ViewBounds {
  xMin: number;
  xMax: number;
  yMin: number;
  yMax: number;
  zMin?: number;
  zMax?: number;
}

/** Axis selection for phase space visualization */
export interface AxisSelection {
  /** Index of state variable for x-axis */
  x: number;
  /** Index of state variable for y-axis */
  y: number;
  /** Index of state variable for z-axis (3D mode) */
  z?: number;
}

/** A point in nullcline data */
export interface NullclinePoint {
  x: number;
  y: number;
}

/** Nullcline data for one equation */
export interface NullclineData {
  equationIndex: number;
  points: NullclinePoint[];
  color: string;
}

/** A single vector in the flow field */
export interface FlowVector {
  x: number;
  y: number;
  dx: number;
  dy: number;
  magnitude: number;
}

/** Trajectory data from simulation */
export interface TrajectoryData {
  /** Initial condition */
  ic: number[];
  /** Array of state vectors over time */
  points: number[][];
  /** Display color */
  color: string;
  /** Optional time array */
  time?: number[];
}

// ============================================
// STABILITY WIZARD ANALYSIS TYPES
// ============================================

/** Diagnostic result from StabilityWizard */
export interface DiagnosticResult {
  scaleOk: boolean;
  centeredOk: boolean;
  timescaleOk: boolean;
  eigenstructureOk: boolean;
}

/** Suggestion from the wizard */
export interface WizardSuggestion {
  type: 'info' | 'warning' | 'error' | 'success';
  title: string;
  description: string;
  action?: {
    label: string;
    actionId: string;
  };
}

/** Full analysis result from StabilityWizard.m */
export interface AnalysisResult {
  fixedPoints: FixedPoint[];
  diagnostics: DiagnosticResult;
  suggestions: WizardSuggestion[];
  suggestedBScale?: number;
  suggestedGamma?: number;
  estimatedRange?: [number, number][];
  centerOfMass?: number[];
}

// ============================================
// CHAT/AI TYPES (Suggestions Tab)
// ============================================

export type MessageRole = 'user' | 'assistant' | 'system';

export interface ChatMessage {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: Date;
}

// ============================================
// WIKI TYPES
// ============================================

export type WikiCategory = 'getting-started' | 'theory' | 'examples' | 'reference';

export interface WikiPage {
  id: string;
  title: string;
  category: WikiCategory;
  content: string;
  icon?: string;
}

// ============================================
// APPLICATION STATE TYPES
// ============================================

export type TabId = 'nullcline' | 'flowfield' | 'suggestions' | 'wiki';

export interface AppState {
  // Connection
  isConnected: boolean;
  systemName: string;
  
  // System definition
  equations: DynamicalEquation[];
  constants: SystemConstant[];
  stateVariables: StateVariable[];
  
  // Analysis
  fixedPoints: FixedPoint[];
  analysisResult: AnalysisResult | null;
  
  // Visualization
  activeTab: TabId;
  viewBounds: ViewBounds;
  selectedAxes: AxisSelection;
  showNullclines: boolean;
  showFixedPoints: boolean;
  showTrajectories: boolean;
  
  // Trajectories
  trajectories: TrajectoryData[];
  
  // Wiki
  currentWikiPage: string;
  
  // Chat
  chatMessages: ChatMessage[];
}

// ============================================
// MATLAB BRIDGE TYPES
// ============================================

export type MatlabMessageType = 
  | 'SYSTEM_UPDATE'
  | 'ANALYSIS_RESULT'
  | 'NULLCLINE_DATA'
  | 'FLOWFIELD_DATA'
  | 'TRAJECTORY_RESULT'
  | 'ERROR'
  | 'DISCONNECT';

export interface MatlabMessage {
  type: MatlabMessageType;
  payload: unknown;
}

export type FrontendMessageType =
  | 'REQUEST_ANALYSIS'
  | 'REQUEST_NULLCLINE'
  | 'REQUEST_FLOWFIELD'
  | 'REQUEST_TRAJECTORY'
  | 'UPDATE_CONSTANT'
  | 'UPDATE_STATE'
  | 'APPLY_SUGGESTION';

export interface FrontendMessage {
  type: FrontendMessageType;
  payload: unknown;
}
