import { ReactNode, useState } from 'react';
import { ChevronDown, ChevronRight } from 'lucide-react';

interface PanelProps {
  title: string;
  children: ReactNode;
  collapsible?: boolean;
  defaultCollapsed?: boolean;
  className?: string;
  headerRight?: ReactNode;
}

export function Panel({
  title,
  children,
  collapsible = false,
  defaultCollapsed = false,
  className = '',
  headerRight,
}: PanelProps) {
  const [isCollapsed, setIsCollapsed] = useState(defaultCollapsed);

  return (
    <div className={`bg-wizard-panel border border-wizard-accent rounded-lg overflow-hidden ${className}`}>
      <div
        className={`flex items-center justify-between px-4 py-3 border-b border-wizard-accent
                   ${collapsible ? 'cursor-pointer hover:bg-wizard-accent/30' : ''}`}
        onClick={() => collapsible && setIsCollapsed(!isCollapsed)}
      >
        <div className="flex items-center gap-2">
          {collapsible && (
            isCollapsed ? <ChevronRight className="w-4 h-4 text-wizard-muted" /> : <ChevronDown className="w-4 h-4 text-wizard-muted" />
          )}
          <h3 className="text-sm font-semibold text-wizard-text">{title}</h3>
        </div>
        {headerRight && <div onClick={(e) => e.stopPropagation()}>{headerRight}</div>}
      </div>
      {!isCollapsed && <div className="p-4">{children}</div>}
    </div>
  );
}
