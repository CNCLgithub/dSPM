import { LucideIcon } from 'lucide-react';

interface TabButtonProps {
  icon: LucideIcon;
  label: string;
  isActive: boolean;
  onClick: () => void;
}

export function TabButton({ icon: Icon, label, isActive, onClick }: TabButtonProps) {
  return (
    <button
      onClick={onClick}
      className={`
        flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium
        transition-all duration-200 ease-in-out
        ${isActive 
          ? 'bg-wizard-accent text-wizard-text shadow-lg' 
          : 'text-wizard-muted hover:text-wizard-text hover:bg-wizard-accent/50'
        }
      `}
    >
      <Icon className="w-4 h-4" />
      <span>{label}</span>
    </button>
  );
}
