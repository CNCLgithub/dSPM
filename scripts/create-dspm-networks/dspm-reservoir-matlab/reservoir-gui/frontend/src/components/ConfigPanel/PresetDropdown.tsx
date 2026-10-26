import React, { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { ChevronDown, ChevronRight, Minus, Plus, Folder } from 'lucide-react';
import { BUILT_IN_PRESETS_V2, BUILT_IN_PRESET_CATEGORIES } from '@/types/presets';
import { useReservoirStore } from '@/stores/reservoirStore';
import { useUIStore } from '@/stores/uiStore';
import type { BuiltInPreset, UserPreset, NetworkSaveFile, PresetFolder, PresetFile } from '@/types/saveSchema';

type PresetItem = BuiltInPreset | UserPreset;

interface PresetDropdownProps {
  onSelect: (preset: PresetItem) => void;
  onRemovePreset?: (filepath: string) => void;
}

// Helper to get preset by name
const getPresetByName = (name: string): BuiltInPreset | undefined => {
  return BUILT_IN_PRESETS_V2.find(p => p.name === name);
};

// ============================================================================
// Built-in Category Submenu (hover to show presets in category)
// ============================================================================

interface CategorySubmenuProps {
  categoryName: string;
  presetNames: string[];
  parentRect: DOMRect;
  onSelectPreset: (preset: BuiltInPreset) => void;
  onClose: () => void;
}

const CategorySubmenu: React.FC<CategorySubmenuProps> = ({
  categoryName: _categoryName,
  presetNames,
  parentRect,
  onSelectPreset,
  onClose,
}) => {
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useEffect(() => {
    const menuWidth = 220;
    const viewportWidth = window.innerWidth;
    
    let left = parentRect.right + 2;
    if (left + menuWidth > viewportWidth - 10) {
      left = parentRect.left - menuWidth - 2;
    }
    
    setPosition({
      top: parentRect.top,
      left,
    });
  }, [parentRect]);

  return createPortal(
    <div
      data-submenu="true"
      style={{
        position: 'fixed',
        top: position.top,
        left: position.left,
        zIndex: 10000,
      }}
      className="min-w-[200px] max-h-[300px] overflow-auto
                 bg-white dark:bg-slate-900
                 border border-slate-200 dark:border-slate-700
                 rounded-lg shadow-lg py-1"
      onMouseLeave={onClose}
    >
      {presetNames.map((name) => {
        const preset = getPresetByName(name);
        if (!preset) return null;
        
        return (
          <button
            key={name}
            onClick={() => onSelectPreset(preset)}
            className="w-full px-3 py-2 text-sm text-left
                       text-slate-700 dark:text-slate-200
                       hover:bg-slate-50 dark:hover:bg-slate-800
                       transition-colors"
          >
            {preset.name}
          </button>
        );
      })}
    </div>,
    document.body
  );
};

// ============================================================================
// Built-in Category Item (folder with hover submenu)
// ============================================================================

interface CategoryItemProps {
  name: string;
  presetNames: string[];
  isHovered: boolean;
  onHover: () => void;
  onUnhover: () => void;
  onSelectPreset: (preset: BuiltInPreset) => void;
}

const CategoryItem: React.FC<CategoryItemProps> = ({
  name,
  presetNames,
  isHovered,
  onHover,
  onUnhover,
  onSelectPreset,
}) => {
  const itemRef = useRef<HTMLDivElement>(null);
  const [itemRect, setItemRect] = useState<DOMRect | null>(null);

  useEffect(() => {
    if (isHovered && itemRef.current) {
      setItemRect(itemRef.current.getBoundingClientRect());
    }
  }, [isHovered]);

  return (
    <div
      ref={itemRef}
      onMouseEnter={onHover}
      className="relative"
    >
      <div
        className={`flex items-center justify-between px-3 py-2 text-sm
                   text-slate-700 dark:text-slate-200
                   hover:bg-slate-50 dark:hover:bg-slate-800
                   cursor-default transition-colors
                   ${isHovered ? 'bg-slate-50 dark:bg-slate-800' : ''}`}
      >
        <span className="flex items-center gap-2">
          <Folder className="w-3.5 h-3.5 text-slate-400" />
          {name}
        </span>
        <ChevronRight className="w-3.5 h-3.5 text-slate-400" />
      </div>
      
      {isHovered && itemRect && (
        <CategorySubmenu
          categoryName={name}
          presetNames={presetNames}
          parentRect={itemRect}
          onSelectPreset={onSelectPreset}
          onClose={onUnhover}
        />
      )}
    </div>
  );
};

// ============================================================================
// User Preset Folder Submenu (for nested user presets)
// ============================================================================

interface UserFolderSubmenuProps {
  folder: PresetFolder;
  parentRect: DOMRect;
  onSelectPreset: (preset: UserPreset) => void;
  onRemovePreset?: (filepath: string) => void;
  onClose: () => void;
}

const UserFolderSubmenu: React.FC<UserFolderSubmenuProps> = ({ 
  folder, 
  parentRect, 
  onSelectPreset, 
  onRemovePreset,
  onClose 
}) => {
  const [hoveredFolder, setHoveredFolder] = useState<string | null>(null);
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useEffect(() => {
    const menuWidth = 220;
    const viewportWidth = window.innerWidth;
    
    let left = parentRect.right + 2;
    if (left + menuWidth > viewportWidth - 10) {
      left = parentRect.left - menuWidth - 2;
    }
    
    setPosition({
      top: parentRect.top,
      left,
    });
  }, [parentRect]);

  return createPortal(
    <div
      data-submenu="true"
      style={{
        position: 'fixed',
        top: position.top,
        left: position.left,
        zIndex: 10000,
      }}
      className="min-w-[200px] max-h-[300px] overflow-auto
                 bg-white dark:bg-slate-900
                 border border-slate-200 dark:border-slate-700
                 rounded-lg shadow-lg py-1"
      onMouseLeave={onClose}
    >
      {folder.children.map((node) => {
        if (node.type === 'folder') {
          const folderNode = node as PresetFolder;
          return (
            <UserFolderItem
              key={`folder:${folderNode.path}`}
              folder={folderNode}
              isHovered={hoveredFolder === folderNode.path}
              onHover={() => setHoveredFolder(folderNode.path)}
              onUnhover={() => setHoveredFolder(null)}
              onSelectPreset={onSelectPreset}
              onRemovePreset={onRemovePreset}
            />
          );
        } else {
          const fileNode = node as PresetFile;
          return (
            <UserPresetItem
              key={`file:${fileNode.preset.filepath || fileNode.preset.name}`}
              preset={fileNode.preset}
              onSelect={() => onSelectPreset(fileNode.preset)}
              onRemove={onRemovePreset}
            />
          );
        }
      })}
    </div>,
    document.body
  );
};

// ============================================================================
// User Folder Item (hover submenu for user preset folders)
// ============================================================================

interface UserFolderItemProps {
  folder: PresetFolder;
  isHovered: boolean;
  onHover: () => void;
  onUnhover: () => void;
  onSelectPreset: (preset: UserPreset) => void;
  onRemovePreset?: (filepath: string) => void;
}

const UserFolderItem: React.FC<UserFolderItemProps> = ({
  folder,
  isHovered,
  onHover,
  onUnhover,
  onSelectPreset,
  onRemovePreset,
}) => {
  const itemRef = useRef<HTMLDivElement>(null);
  const [itemRect, setItemRect] = useState<DOMRect | null>(null);

  useEffect(() => {
    if (isHovered && itemRef.current) {
      setItemRect(itemRef.current.getBoundingClientRect());
    }
  }, [isHovered]);

  return (
    <div
      ref={itemRef}
      onMouseEnter={onHover}
      className="relative"
    >
      <div
        className={`flex items-center justify-between px-3 py-2 text-sm
                   text-slate-700 dark:text-slate-200
                   hover:bg-slate-50 dark:hover:bg-slate-800
                   cursor-default transition-colors
                   ${isHovered ? 'bg-slate-50 dark:bg-slate-800' : ''}`}
      >
        <span className="flex items-center gap-2">
          <Folder className="w-3.5 h-3.5 text-slate-400" />
          {folder.name}
        </span>
        <ChevronRight className="w-3.5 h-3.5 text-slate-400" />
      </div>
      
      {isHovered && itemRect && (
        <UserFolderSubmenu
          folder={folder}
          parentRect={itemRect}
          onSelectPreset={onSelectPreset}
          onRemovePreset={onRemovePreset}
          onClose={onUnhover}
        />
      )}
    </div>
  );
};

// ============================================================================
// User Preset Item (single file)
// ============================================================================

interface UserPresetItemProps {
  preset: UserPreset;
  onSelect: () => void;
  onRemove?: (filepath: string) => void;
}

const UserPresetItem: React.FC<UserPresetItemProps> = ({ preset, onSelect, onRemove }) => {
  const handleRemove = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (preset.filepath && onRemove) {
      onRemove(preset.filepath);
    }
  };

  return (
    <div
      className="group flex items-center
                 hover:bg-slate-50 dark:hover:bg-slate-800
                 transition-colors"
    >
      <button
        onClick={onSelect}
        className="flex-1 px-3 py-2 text-sm text-left
                   text-slate-700 dark:text-slate-200"
      >
        {preset.name}
      </button>
      {preset.filepath && onRemove && (
        <button
          onClick={handleRemove}
          className="p-1.5 mr-1 rounded
                     text-slate-300 dark:text-slate-600
                     hover:text-red-500 dark:hover:text-red-400
                     hover:bg-red-50 dark:hover:bg-red-900/20
                     opacity-0 group-hover:opacity-100
                     transition-all"
          title="Remove from presets"
        >
          <Minus className="w-3.5 h-3.5" />
        </button>
      )}
    </div>
  );
};

// ============================================================================
// Main PresetDropdown Component
// ============================================================================

export const PresetDropdown: React.FC<PresetDropdownProps> = ({ 
  onSelect, 
  onRemovePreset,
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [hoveredCategory, setHoveredCategory] = useState<string | null>(null);
  const [hoveredUserFolder, setHoveredUserFolder] = useState<string | null>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [position, setPosition] = useState<{
    top?: number;
    bottom?: number;
    left: number;
    width: number;
    maxHeight: number;
  }>({ left: 0, width: 256, maxHeight: 400 });
  
  const { loadPresetV2, presetTree, userPresets } = useReservoirStore();
  const { setStatus } = useUIStore();

  // Update position when dropdown opens
  useEffect(() => {
    if (isOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      const menuWidth = Math.max(rect.width, 256);
      const menuHeight = 400;
      
      const spaceBelow = window.innerHeight - rect.bottom;
      const spaceAbove = rect.top;
      
      if (spaceBelow < menuHeight && spaceAbove > spaceBelow) {
        setPosition({
          top: undefined,
          bottom: window.innerHeight - rect.top + 4,
          left: rect.left,
          width: menuWidth,
          maxHeight: Math.min(menuHeight, spaceAbove - 8),
        });
      } else {
        setPosition({
          top: rect.bottom + 4,
          bottom: undefined,
          left: rect.left,
          width: menuWidth,
          maxHeight: Math.min(menuHeight, spaceBelow - 8),
        });
      }
    }
  }, [isOpen]);

  // Close on click outside
  useEffect(() => {
    if (!isOpen) return;
    
    const handleClickOutside = (e: MouseEvent) => {
      const target = e.target as Node;
      const clickedSubmenu = (e.target as Element).closest?.('[data-submenu]');
      if (
        buttonRef.current && !buttonRef.current.contains(target) &&
        menuRef.current && !menuRef.current.contains(target) &&
        !clickedSubmenu
      ) {
        setIsOpen(false);
      }
    };

    setTimeout(() => {
      document.addEventListener('mousedown', handleClickOutside);
    }, 0);
    
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen]);

  // Close on escape
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setIsOpen(false);
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, []);

  const handleSelectPreset = (preset: PresetItem) => {
    onSelect(preset);
    setIsOpen(false);
  };

  const handleAddFromFile = () => {
    setIsOpen(false);
    fileInputRef.current?.click();
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const json = JSON.parse(event.target?.result as string);
        if (json.version && json.name && json.config) {
          loadPresetV2(json as NetworkSaveFile & { isBuiltIn: false });
          setStatus(`Loaded: ${json.name}`, 'success');
        } else {
          setStatus('Invalid network file format', 'error');
        }
      } catch {
        setStatus('Failed to parse JSON file', 'error');
      }
    };
    reader.onerror = () => {
      setStatus('Failed to read file', 'error');
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // Separate folders and root-level files from presetTree
  const folders = presetTree.filter((node): node is PresetFolder => node.type === 'folder');
  const rootFiles = presetTree.filter((node): node is PresetFile => node.type === 'file');
  
  // Check if we have any user presets
  const hasUserPresets = presetTree.length > 0 || userPresets.length > 0;

  return (
    <>
      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".json"
        onChange={handleFileSelect}
        className="hidden"
      />
      
      <div className="relative">
        {/* Trigger button */}
        <button
          ref={buttonRef}
          onClick={() => setIsOpen(!isOpen)}
          className="w-full px-3 py-2 pr-8 text-sm text-left relative
                     bg-slate-50 dark:bg-slate-800 
                     border-0 rounded-lg
                     text-slate-600 dark:text-slate-300
                     hover:bg-slate-100 dark:hover:bg-slate-700
                     focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600
                     transition-colors"
        >
          Select preset...
          <ChevronDown className={`absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 
                                  text-slate-400 dark:text-slate-500 
                                  transition-transform ${isOpen ? 'rotate-180' : ''}`} />
        </button>

        {/* Dropdown menu via portal */}
        {isOpen && createPortal(
          <div
            ref={menuRef}
            style={{
              position: 'fixed',
              top: position.top,
              bottom: position.bottom,
              left: position.left,
              width: position.width,
              maxHeight: position.maxHeight,
              zIndex: 9999,
            }}
            className="overflow-auto
                       bg-white dark:bg-slate-900
                       border border-slate-200 dark:border-slate-700
                       rounded-lg shadow-lg"
          >
            {/* Built-in presets by category */}
            <div className="px-2 py-1.5 text-xs font-medium text-slate-400 dark:text-slate-500 uppercase tracking-wide">
              Built-in
            </div>
            
            {BUILT_IN_PRESET_CATEGORIES.map((category) => (
              <CategoryItem
                key={category.name}
                name={category.name}
                presetNames={category.presets}
                isHovered={hoveredCategory === category.name}
                onHover={() => {
                  setHoveredCategory(category.name);
                  setHoveredUserFolder(null);
                }}
                onUnhover={() => setHoveredCategory(null)}
                onSelectPreset={handleSelectPreset}
              />
            ))}
            
            {/* User presets section */}
            {hasUserPresets && (
              <>
                <div className="border-t border-slate-100 dark:border-slate-800 my-1" />
                <div className="px-2 py-1.5 text-xs font-medium text-slate-400 dark:text-slate-500 uppercase tracking-wide">
                  My Presets
                </div>
                
                {/* Render user folders */}
                {folders.map((folder) => (
                  <UserFolderItem
                    key={`folder:${folder.path}`}
                    folder={folder}
                    isHovered={hoveredUserFolder === folder.path}
                    onHover={() => {
                      setHoveredUserFolder(folder.path);
                      setHoveredCategory(null);
                    }}
                    onUnhover={() => setHoveredUserFolder(null)}
                    onSelectPreset={(preset) => handleSelectPreset(preset)}
                    onRemovePreset={onRemovePreset}
                  />
                ))}
                
                {/* Render root-level user files */}
                {rootFiles.map((fileNode) => (
                  <UserPresetItem
                    key={`file:${fileNode.preset.filepath || fileNode.preset.name}`}
                    preset={fileNode.preset}
                    onSelect={() => handleSelectPreset(fileNode.preset)}
                    onRemove={onRemovePreset}
                  />
                ))}
                
                {/* Fallback: render flat userPresets if tree is empty */}
                {presetTree.length === 0 && userPresets.map((preset) => (
                  <UserPresetItem
                    key={`user:${preset.filepath || preset.name}`}
                    preset={preset}
                    onSelect={() => handleSelectPreset(preset)}
                    onRemove={onRemovePreset}
                  />
                ))}
              </>
            )}
            
            {/* Add from file */}
            <div className="border-t border-slate-100 dark:border-slate-800 my-1" />
            <button
              onClick={handleAddFromFile}
              className="w-full px-3 py-2 text-sm text-left
                         flex items-center gap-2
                         text-slate-500 dark:text-slate-400
                         hover:text-slate-700 dark:hover:text-slate-200
                         hover:bg-slate-50 dark:hover:bg-slate-800
                         transition-colors"
            >
              <Plus className="w-3.5 h-3.5" />
              Load from file...
            </button>
          </div>,
          document.body
        )}
      </div>
    </>
  );
};
