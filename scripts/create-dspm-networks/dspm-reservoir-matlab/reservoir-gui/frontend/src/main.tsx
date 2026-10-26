import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { useUIStore } from '@/stores/uiStore';
import 'katex/dist/katex.min.css';
import './index.css';

// Auto-detect if running inside MATLAB's uihtml
function isInMatlabEnvironment(): boolean {
  // Check 1: Loaded via file:// protocol (MATLAB loads local HTML files)
  if (window.location.protocol === 'file:') {
    return true;
  }
  
  // Check 2: Running in an iframe (uihtml embeds content)
  if (window.parent !== window) {
    return true;
  }
  
  // Check 3: URL parameter override (for testing)
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('matlab') === 'true') {
    return true;
  }
  
  return false;
}

// If in MATLAB, hide the header (MATLAB's uifigure already has a title bar)
if (isInMatlabEnvironment()) {
  useUIStore.getState().setShowHeader(false);
}

// Render the app
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
