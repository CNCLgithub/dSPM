/**
 * Header Component
 * 
 * Top bar with logo, system name, and connection status.
 */

import { Wand2, Circle } from 'lucide-react';
import { useWizardStore } from '@/stores/wizardStore';

export function Header() {
  const { isConnected, systemName } = useWizardStore();

  return (
    <header className="flex items-center justify-between px-6 py-3 bg-wizard-panel border-b border-wizard-accent/20">
      {/* Logo and title */}
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-lg bg-wizard-accent/20">
          <Wand2 className="w-5 h-5 text-wizard-accent" />
        </div>
        <div>
          <h1 className="text-lg font-semibold text-wizard-text">
            Stability Wizard
          </h1>
          {systemName && (
            <p className="text-xs text-wizard-text-muted">
              {systemName}
            </p>
          )}
        </div>
      </div>

      {/* Connection status */}
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-wizard-bg-secondary">
          <Circle
            className={`w-2 h-2 ${
              isConnected 
                ? 'fill-wizard-success text-wizard-success' 
                : 'fill-wizard-error text-wizard-error'
            }`}
          />
          <span className="text-xs text-wizard-text-muted">
            {isConnected ? 'Connected to MATLAB' : 'Disconnected'}
          </span>
        </div>
      </div>
    </header>
  );
}
