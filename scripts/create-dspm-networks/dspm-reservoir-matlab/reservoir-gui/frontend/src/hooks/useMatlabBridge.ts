import { useEffect, useCallback, useRef, useState } from 'react';
import { useReservoirStore } from '@/stores/reservoirStore';
import { useUIStore } from '@/stores/uiStore';
import type { MatlabMessage } from '@/types/matlab';
import type { 
  SaveResponse, 
  CompileResponse, 
  UserPreset,
  PresetNode,
} from '@/types/saveSchema';

/**
 * Hook for communicating with MATLAB via postMessage
 * When running standalone (not in MATLAB), provides mock responses
 */
export function useMatlabBridge() {
  const isInMatlab = useRef(false);
  const [isSaving, setIsSaving] = useState(false);
  const [showSaveDialog, setShowSaveDialog] = useState(false);
  
  const { 
    config, 
    networkName,
    networkDescription,
    setCompiling, 
    setCompileResult,
    setUserPresets,
    setPresetTree,
    setRandomSeed,
    getNetworkSaveFile,
    loadPresetV2,
  } = useReservoirStore();
  const { setStatus } = useUIStore();

  // Check if we're running inside MATLAB's uihtml (iframe)
  useEffect(() => {
    isInMatlab.current = window.parent !== window;
    console.log(`[MatlabBridge] Running in ${isInMatlab.current ? 'MATLAB' : 'standalone'} mode`);
    
    // Request list of user presets on load
    if (isInMatlab.current) {
      setTimeout(() => {
        sendToMatlab({ action: 'list_presets' });
      }, 100);
    }
  }, []);

  // Listen for messages from MATLAB via postMessage
  useEffect(() => {
    const handleMessage = (event: MessageEvent<MatlabMessage>) => {
      if (!event.data || !event.data.action) return;
      
      const { action, payload } = event.data;
      console.log('[MatlabBridge] Received:', action, payload);
      
      switch (action) {
          case 'init': {
          const initPayload = payload as {
            standaloneMode: boolean;
            // These fields match NetworkSaveFile schema when standaloneMode is false
            version?: string;
            name?: string;
            description?: string;
            config?: {
              n_neurons: number;
              gamma: number;
              dt: number;
              B_scale: number;
              B_sparsity: number;
              random_seed: number;
              expansion_point: {
                x: Record<string, number>;
                y: Record<string, number>;
              };
            };
            topology?: {
              n_recurrent_inputs: number;
              n_external_inputs: number;
              n_recurrent_outputs: number;
              n_external_outputs: number;
            };
            inferred?: {
              jet_order: number;
              decompilation_order: number;
            };
            equations?: Array<{
              index: number;
              outputType: string;
              tau: string;
              latex: string;
            }>;
            constants?: Array<{
              name: string;
              value: number;
              description?: string;
            }>;
          };
          
          if (!initPayload.standaloneMode && initPayload.config && initPayload.topology) {
            // Build a preset-like object from the init payload
            const presetData = {
              name: initPayload.name || '',
              description: initPayload.description || '',
              config: initPayload.config,
              topology: initPayload.topology,
              inferred: initPayload.inferred || { jet_order: 2, decompilation_order: 3 },
              equations: initPayload.equations || [],
              constants: initPayload.constants || [],
              version: initPayload.version || '1.0',
              created: new Date().toISOString(),
              modified: new Date().toISOString(),
              is_preset: false,
              isBuiltIn: false,
            };
            
            loadPresetV2(presetData as UserPreset);
            setStatus('Loaded reservoir from MATLAB', 'success');
          } else {
            setStatus('Connected to MATLAB', 'success');
          }
          break;
        }
          
        case 'compile_result': {
          const result = payload as CompileResponse;
          setCompileResult({
            success: result.success,
            residual: result.residual,
            relativeError: result.relative_error,
            rankR: result.rank,
            nMonomials: result.n_monomials,
            errorMessage: result.error_message,
          });
          setCompiling(false);
          if (result.success) {
            setStatus(`Compiled (error: ${result.relative_error.toExponential(2)}, rank: ${result.rank})`, 'success');
          } else {
            setStatus(`Compilation failed: ${result.error_message}`, 'error');
          }
          break;
        }
        
        case 'save_result': {
          const result = payload as SaveResponse;
          setIsSaving(false);
          if (result.success) {
            setRandomSeed(result.seed);
            setStatus(`Saved to ${result.filepath}`, 'success');
            sendToMatlab({ action: 'list_presets' });
          } else {
            setStatus(`Save failed: ${result.error_message}`, 'error');
          }
          setShowSaveDialog(false);
          break;
        }
        
        case 'presets_list': {
          const result = payload as { user_presets: UserPreset[]; preset_tree?: PresetNode[] };
          setUserPresets(result.user_presets || []);
          setPresetTree(result.preset_tree || []);
          break;
        }
        
        case 'remove_preset_result': {
          const result = payload as { success: boolean; error_message?: string };
          if (result.success) {
            setStatus('Removed from presets', 'success');
            sendToMatlab({ action: 'list_presets' });
          } else {
            setStatus(`Failed to remove: ${result.error_message}`, 'error');
          }
          break;
        }
          
        case 'simulate_result':
          setStatus('Simulation complete', 'success');
          break;
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [setCompileResult, setCompiling, setStatus, setUserPresets, setPresetTree, setRandomSeed,loadPresetV2]);

  // Send message to MATLAB
  const sendToMatlab = useCallback((message: MatlabMessage) => {
    console.log('[MatlabBridge] Sending:', message.action, message.payload);
    
    if (isInMatlab.current) {
      window.parent.postMessage(message, '*');
    } else {
      // Standalone mode - use mock responses
      mockMatlabResponse(message);
    }
  }, []);

  // Mock MATLAB responses for standalone development
  const mockMatlabResponse = useCallback((message: MatlabMessage) => {
    setTimeout(() => {
      switch (message.action) {
        case 'compile':
          setCompiling(true);
          setStatus('Compiling...', 'info');
          
          setTimeout(() => {
            const mockResult: CompileResponse = {
              success: true,
              residual: Math.random() * 1e-6,
              relative_error: Math.random() * 0.01,
              rank: Math.floor(config.nNeurons * 0.8),
              condition_number: 100 + Math.random() * 1000,
              n_monomials: 22,
              jet_order: 1,
              decompilation_order: 2,
            };
            setCompileResult({
              success: mockResult.success,
              residual: mockResult.residual,
              relativeError: mockResult.relative_error,
              rankR: mockResult.rank,
              nMonomials: mockResult.n_monomials,
            });
            setCompiling(false);
            setStatus(`Compiled (error: ${mockResult.relative_error.toExponential(2)}, rank: ${mockResult.rank})`, 'success');
          }, 1500);
          break;
          
        case 'save': {
          setIsSaving(true);
          setTimeout(() => {
            const mockSeed = Math.floor(Math.random() * 1000000);
            setRandomSeed(mockSeed);
            setIsSaving(false);
            setShowSaveDialog(false);
            setStatus('Saved (mock)', 'success');
          }, 500);
          break;
        }
        
        case 'list_presets':
          setUserPresets([]);
          break;
          
        case 'remove_preset':
          setStatus('Remove requires MATLAB connection', 'warning');
          break;
          
        case 'simulate':
          setStatus('Simulation complete (mock)', 'success');
          break;
          
        case 'export':
          setStatus('Exported to workspace (mock)', 'success');
          break;
      }
    }, 100);
  }, [config.nNeurons, setCompiling, setCompileResult, setStatus, setUserPresets, setRandomSeed]);

  // Compile action
  const compile = useCallback(() => {
    const saveFile = getNetworkSaveFile(
      networkName || 'Untitled',
      networkDescription || '',
      false
    );

    setCompiling(true);
    setStatus('Compiling...', 'info');
    sendToMatlab({ action: 'compile', payload: saveFile });
  }, [getNetworkSaveFile, networkName, networkDescription, setCompiling, setStatus, sendToMatlab]);

  // Export to MATLAB workspace
  const exportToWorkspace = useCallback(() => {
    const saveFile = getNetworkSaveFile(
      networkName || 'reservoir',
      networkDescription || '',
      false
    );
    sendToMatlab({ action: 'export', payload: saveFile });
    setStatus('Exported to MATLAB workspace', 'success');
  }, [getNetworkSaveFile, networkName, networkDescription, sendToMatlab, setStatus]);

  // Open save dialog
  const openSaveDialog = useCallback(() => {
    setShowSaveDialog(true);
  }, []);

  // Close save dialog
  const closeSaveDialog = useCallback(() => {
    setShowSaveDialog(false);
  }, []);

  // Save configuration with name/description
  const saveConfig = useCallback((name: string, description: string, addToPresets: boolean) => {
    const saveFile = getNetworkSaveFile(name, description, addToPresets);
    
    setIsSaving(true);
    setStatus('Saving...', 'info');
    sendToMatlab({ action: 'save', payload: saveFile });
  }, [getNetworkSaveFile, sendToMatlab, setStatus]);

  // Open save dialog (for button click)
  const saveConfigLegacy = useCallback(() => {
    openSaveDialog();
  }, [openSaveDialog]);

  // Remove a preset (delete from presets/ folder)
  const removePreset = useCallback((filepath: string) => {
    sendToMatlab({ action: 'remove_preset', payload: { filepath } });
  }, [sendToMatlab]);

  return {
    isInMatlab: isInMatlab.current,
    isSaving,
    showSaveDialog,
    sendToMatlab,
    compile,
    exportToWorkspace,
    saveConfig: saveConfigLegacy,
    saveConfigWithDetails: saveConfig,
    openSaveDialog,
    closeSaveDialog,
    removePreset,
  };
}
