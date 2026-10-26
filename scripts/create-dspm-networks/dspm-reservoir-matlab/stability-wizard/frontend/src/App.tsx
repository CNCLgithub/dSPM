import { useState } from 'react';
import { Wand2, GitBranch, Compass, Lightbulb, BookOpen } from 'lucide-react';
import { TabButton } from './components/common/TabButton';
import { NullclineViewer } from './components/nullcline/NullclineViewer';
import { FlowFieldViewer } from './components/flowfield/FlowFieldViewer';
import { SuggestionsPanel } from './components/suggestions/SuggestionsPanel';
import { WikiPanel } from './components/wiki/WikiPanel';
import { useWizardStore } from './stores/wizardStore';

type TabId = 'nullcline' | 'flowfield' | 'suggestions' | 'wiki';

const tabs: { id: TabId; label: string; icon: typeof Wand2 }[] = [
  { id: 'nullcline', label: 'Nullclines', icon: GitBranch },
  { id: 'flowfield', label: 'Flow Field', icon: Compass },
  { id: 'suggestions', label: 'Suggestions', icon: Lightbulb },
  { id: 'wiki', label: 'Wiki', icon: BookOpen },
];

function App() {
  const [activeTab, setActiveTab] = useState<TabId>('nullcline');
  const { isConnected, systemName } = useWizardStore();

  return (
    <div className="h-screen w-screen flex flex-col bg-wizard-bg">
      {/* Header */}
      <header className="flex items-center justify-between px-6 py-3 bg-wizard-panel border-b border-wizard-accent">
        <div className="flex items-center gap-3">
          <Wand2 className="w-6 h-6 text-wizard-highlight" />
          <h1 className="text-lg font-semibold text-wizard-text">Stability Wizard</h1>
          {systemName && <span className="text-sm text-wizard-muted">— {systemName}</span>}
        </div>
        
        <div className="flex items-center gap-2">
          <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-wizard-success' : 'bg-wizard-error'}`} />
          <span className="text-xs text-wizard-muted">
            {isConnected ? 'Connected to MATLAB' : 'Disconnected'}
          </span>
        </div>
      </header>

      {/* Tab Navigation */}
      <nav className="flex gap-1 px-4 py-2 bg-wizard-panel border-b border-wizard-accent">
        {tabs.map((tab) => (
          <TabButton
            key={tab.id}
            icon={tab.icon}
            label={tab.label}
            isActive={activeTab === tab.id}
            onClick={() => setActiveTab(tab.id)}
          />
        ))}
      </nav>

      {/* Main Content */}
      <main className="flex-1 overflow-hidden">
        <div className="h-full tab-content">
          {activeTab === 'nullcline' && <NullclineViewer />}
          {activeTab === 'flowfield' && <FlowFieldViewer />}
          {activeTab === 'suggestions' && <SuggestionsPanel />}
          {activeTab === 'wiki' && <WikiPanel />}
        </div>
      </main>

      {/* Footer */}
      <footer className="px-4 py-2 bg-wizard-panel border-t border-wizard-accent text-xs text-wizard-muted">
        <div className="flex justify-between">
          <span>dSPM Stability Wizard v0.1.0</span>
          <span>Press ? for keyboard shortcuts</span>
        </div>
      </footer>
    </div>
  );
}

export default App;
