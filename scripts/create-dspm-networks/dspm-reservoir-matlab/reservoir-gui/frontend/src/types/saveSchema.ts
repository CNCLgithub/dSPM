// Save file schema for programmed networks
// Version 1.0

export interface SavedEquation {
  index: number;
  outputType: 'external' | 'recurrent';
  tau: string;                    // Coefficient τ(t), can be symbolic
  latex: string;                  // LaTeX RHS: f(x,y)
  symbolic?: string;              // MATLAB symbolic form (optional, can be inferred)
}

export interface SavedConstant {
  name: string;                   // LaTeX symbol: '\sigma', '\beta_0'
  value: number;                  // Numeric value for computation
  display_value?: string;         // Optional LaTeX string for display (e.g., "\\frac{8}{3}")
  description?: string;
}

export interface SavedExpansionPoint {
  x: Record<string, number>;      // External inputs: { "1": 0, "2": 1.5 }
  y: Record<string, number>;      // Recurrent inputs: { "1": 0, "2": 0 }
}

export interface SavedConfig {
  n_neurons: number;
  gamma: number;
  dt: number;
  B_scale: number;
  B_sparsity: number;
  random_seed: number;
  expansion_point: SavedExpansionPoint;
}

export interface SavedTopology {
  n_external_inputs: number;
  n_external_outputs: number;
  n_recurrent_inputs: number;
  n_recurrent_outputs: number;
}

export interface SavedInferred {
  jet_order: number;
  decompilation_order: number;
}

export interface NetworkSaveFile {
  version: string;                // Schema version: "1.0"
  name: string;
  description: string;
  created: string;                // ISO 8601 timestamp
  modified: string;               // ISO 8601 timestamp
  is_preset: boolean;             // Show in preset dropdown
  
  config: SavedConfig;
  topology: SavedTopology;
  inferred: SavedInferred;
  
  equations: SavedEquation[];
  constants: SavedConstant[];
}

// Preset extends NetworkSaveFile with optional filepath
export interface UserPreset extends NetworkSaveFile {
  filepath?: string;              // Path on disk (populated by MATLAB)
  isBuiltIn: false;
}

export interface BuiltInPreset extends NetworkSaveFile {
  isBuiltIn: true;
}

// Nested preset structure for folders
export interface PresetFolder {
  type: 'folder';
  name: string;                   // Folder display name
  path: string;                   // Full path to folder
  children: PresetNode[];         // Contents (files and subfolders)
}

export interface PresetFile {
  type: 'file';
  preset: UserPreset;
}

export type PresetNode = PresetFolder | PresetFile;

export type PresetItem = UserPreset | BuiltInPreset;

// Compile request/response types for MATLAB bridge
export interface CompileRequest {
  config: SavedConfig;
  topology: SavedTopology;
  equations: SavedEquation[];
  constants: SavedConstant[];
}

export interface CompileResponse {
  success: boolean;
  residual: number;
  relative_error: number;
  rank: number;
  condition_number: number;
  n_monomials: number;
  jet_order: number;
  decompilation_order: number;
  error_message?: string;
}

export interface SaveRequest {
  name: string;
  description: string;
  add_to_presets: boolean;
  config: SavedConfig;
  topology: SavedTopology;
  equations: SavedEquation[];
  constants: SavedConstant[];
}

export interface SaveResponse {
  success: boolean;
  filepath: string;
  seed: number;                   // The seed that was generated/used
  error_message?: string;
}

export interface LoadResponse {
  success: boolean;
  data?: NetworkSaveFile;
  error_message?: string;
}

export interface ListPresetsResponse {
  success: boolean;
  built_in: BuiltInPreset[];
  user_presets: UserPreset[];
  error_message?: string;
}

// Saved network summary (for browsing saved-networks/)
export interface SavedNetworkSummary {
  name: string;
  description: string;
  filepath: string;
  filename: string;
  modified: number;
}

export interface BrowseSavedNetworksResponse {
  success: boolean;
  networks: SavedNetworkSummary[];
  error_message?: string;
}

export interface RemovePresetResponse {
  success: boolean;
  filepath: string;
  error_message?: string;
}

export interface AddToPresetsResponse {
  success: boolean;
  filepath: string;
  error_message?: string;
}

export interface LoadNetworkResponse {
  success: boolean;
  data?: NetworkSaveFile;
  cancelled?: boolean;
  error_message?: string;
}
