import { useState } from 'react';
import { Book, Code, Beaker, GraduationCap, ChevronRight, Search } from 'lucide-react';

interface WikiPage { id: string; title: string; category: string; content: string; }

const wikiPages: WikiPage[] = [
  { id: 'intro', title: 'Introduction to dSPM', category: 'Getting Started',
    content: `# Introduction to dSPM\n\nThe dynamical Structure-Preserving Manifolds (dSPM) framework extends reservoir computing into quaternionic geometry on the 3-sphere (S³).\n\n## Key Concepts\n\n### The A=0 Reservoir\nUnlike traditional RC, dSPM uses an A=0 architecture where internal dynamics are purely contractive.\n\n### The Operating Point\nThe operating point r* becomes the symbolic origin of computation.` },
  { id: 'scaling', title: 'Scaling & Centering', category: 'Getting Started',
    content: `# Scaling & Centering\n\nPhysical systems must be translated to the reservoir's number-theoretic scale.\n\n## The Problem\nThe Lorenz attractor oscillates far outside [-0.5, 0.5].\n\n## The Solution\n1. Translate: Center dynamics at origin\n2. Scale: Fit within ±0.3\n3. Slow time: Match reservoir timescale` },
  { id: 'fixed-points', title: 'Fixed Points & Stability', category: 'Theory',
    content: `# Fixed Points & Stability\n\nUnderstanding fixed points is crucial for designing stable programs.\n\n## Eigenvalue Classification\n- All Re(λ) < 0: Stable\n- All Re(λ) > 0: Unstable\n- Mixed: Saddle` },
  { id: 'logic-gates', title: 'Logic Gates', category: 'Examples',
    content: `# Logic Gates via Dynamics\n\nBinary logic implemented using pitchfork bifurcations.\n\n## The Dynamical Core\nẏ = cx·y + ax·y³ + h(x₁, x₂)\n\nwhere h implements the specific logic.` },
  { id: 'api', title: 'MATLAB API', category: 'Reference',
    content: `# MATLAB API\n\n\`\`\`matlab\nres = dspm_reservoir('load', 'preset.json');\nres.condition([0.05; 0.05; -0.04]);\nres.close_loop();\n[r, y] = res.simulate(10000);\n\`\`\`` },
];

const categories = ['Getting Started', 'Theory', 'Examples', 'Reference'];
const categoryIcons: Record<string, typeof Book> = { 'Getting Started': Book, 'Theory': GraduationCap, 'Examples': Beaker, 'Reference': Code };

export function WikiPanel() {
  const [currentPageId, setCurrentPageId] = useState('intro');
  const [searchQuery, setSearchQuery] = useState('');
  
  const currentPage = wikiPages.find(p => p.id === currentPageId) || wikiPages[0];
  const filteredPages = searchQuery ? wikiPages.filter(p => p.title.toLowerCase().includes(searchQuery.toLowerCase())) : wikiPages;

  return (
    <div className="h-full flex">
      {/* Sidebar */}
      <div className="w-72 border-r border-wizard-accent overflow-y-auto">
        <div className="p-4 border-b border-wizard-accent">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-wizard-muted" />
            <input type="text" value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
              placeholder="Search wiki..." className="w-full pl-10 pr-4 py-2 bg-wizard-accent text-wizard-text text-sm rounded-lg border border-wizard-accent focus:border-wizard-highlight outline-none" />
          </div>
        </div>
        <nav className="p-4">
          {categories.map(cat => {
            const pages = filteredPages.filter(p => p.category === cat);
            if (pages.length === 0) return null;
            const Icon = categoryIcons[cat] || Book;
            return (
              <div key={cat} className="mb-4">
                <h3 className="text-xs font-semibold text-wizard-muted uppercase tracking-wider mb-2 flex items-center gap-2">
                  <Icon className="w-3 h-3" />{cat}
                </h3>
                <ul className="space-y-1">
                  {pages.map(page => (
                    <li key={page.id}>
                      <button onClick={() => setCurrentPageId(page.id)}
                        className={`w-full flex items-center gap-2 px-3 py-2 text-sm rounded-lg text-left ${currentPageId === page.id ? 'bg-wizard-accent text-wizard-text' : 'text-wizard-muted hover:text-wizard-text hover:bg-wizard-accent/50'}`}>
                        {page.title}
                        {currentPageId === page.id && <ChevronRight className="w-4 h-4 ml-auto" />}
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </nav>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        <div className="max-w-3xl mx-auto px-8 py-6">
          <div className="flex items-center gap-2 text-sm text-wizard-muted mb-6">
            <span>Wiki</span><ChevronRight className="w-4 h-4" /><span>{currentPage.category}</span><ChevronRight className="w-4 h-4" /><span className="text-wizard-text">{currentPage.title}</span>
          </div>
          <article className="prose prose-invert max-w-none">
            {currentPage.content.split('\n').map((line, i) => {
              if (line.startsWith('# ')) return <h1 key={i} className="text-2xl font-bold mt-6 mb-4">{line.slice(2)}</h1>;
              if (line.startsWith('## ')) return <h2 key={i} className="text-xl font-semibold mt-5 mb-3">{line.slice(3)}</h2>;
              if (line.startsWith('### ')) return <h3 key={i} className="text-lg font-medium mt-4 mb-2">{line.slice(4)}</h3>;
              if (line.startsWith('- ')) return <li key={i} className="text-wizard-muted ml-4">{line.slice(2)}</li>;
              if (line.startsWith('```')) return null;
              if (line.trim()) return <p key={i} className="text-wizard-muted my-2">{line}</p>;
              return <div key={i} className="h-2" />;
            })}
          </article>
        </div>
      </div>
    </div>
  );
}
