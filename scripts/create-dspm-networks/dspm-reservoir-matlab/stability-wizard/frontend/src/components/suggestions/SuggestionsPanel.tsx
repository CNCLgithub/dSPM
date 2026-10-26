import { useState, useRef, useEffect } from 'react';
import { Send, Info, Bot, User } from 'lucide-react';
import { Panel } from '../common/Panel';

interface Message { id: string; role: 'user' | 'assistant'; content: string; timestamp: Date; }

export function SuggestionsPanel() {
  const [messages, setMessages] = useState<Message[]>([
    { id: '1', role: 'assistant', content: "Hello! I'm your Stability Wizard assistant. I can help you understand dynamical systems, suggest improvements, and explain reservoir computing theory. What would you like to know?", timestamp: new Date() },
  ]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => { messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const handleSend = () => {
    if (!inputValue.trim()) return;
    const userMsg: Message = { id: Date.now().toString(), role: 'user', content: inputValue, timestamp: new Date() };
    setMessages(prev => [...prev, userMsg]);
    setInputValue('');
    setIsLoading(true);
    
    // Placeholder response
    setTimeout(() => {
      const response = inputValue.toLowerCase().includes('scale') 
        ? "Scaling is crucial because tanh has a linear regime in [-0.5, 0.5]. Values outside this range cause saturation and loss of computational capacity."
        : "That's a great question! In the full implementation, I'll be powered by a fine-tuned LLM for dynamical systems. Check the Wiki tab for tutorials!";
      setMessages(prev => [...prev, { id: (Date.now()+1).toString(), role: 'assistant', content: response, timestamp: new Date() }]);
      setIsLoading(false);
    }, 1000);
  };

  const suggestions = [
    { type: 'info', title: 'No Analysis Yet', description: 'Run stability analysis to get recommendations.' },
  ];

  return (
    <div className="h-full flex">
      {/* Suggestions */}
      <div className="w-96 border-r border-wizard-accent overflow-y-auto p-4 space-y-4">
        <Panel title="Analysis Suggestions">
          <div className="space-y-3">
            {suggestions.map((s, i) => (
              <div key={i} className="p-3 rounded-lg border border-wizard-accent bg-wizard-accent/30">
                <div className="flex items-start gap-3">
                  <Info className="w-5 h-5 text-wizard-muted" />
                  <div>
                    <h4 className="font-medium text-sm mb-1">{s.title}</h4>
                    <p className="text-xs text-wizard-muted">{s.description}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </Panel>
      </div>

      {/* Chat */}
      <div className="flex-1 flex flex-col">
        <div className="px-4 py-3 border-b border-wizard-accent flex items-center gap-2">
          <Bot className="w-5 h-5 text-wizard-highlight" />
          <h3 className="font-medium">AI Assistant</h3>
          <span className="text-xs text-wizard-muted">(Placeholder - will use local LLM)</span>
        </div>
        
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.map(msg => (
            <div key={msg.id} className={`flex gap-3 ${msg.role === 'user' ? 'flex-row-reverse' : ''}`}>
              <div className={`w-8 h-8 rounded-full flex items-center justify-center ${msg.role === 'user' ? 'bg-wizard-highlight' : 'bg-wizard-accent'}`}>
                {msg.role === 'user' ? <User className="w-4 h-4" /> : <Bot className="w-4 h-4" />}
              </div>
              <div className={`max-w-[80%] p-3 rounded-lg ${msg.role === 'user' ? 'bg-wizard-highlight/20' : 'bg-wizard-panel border border-wizard-accent'}`}>
                <p className="text-sm whitespace-pre-wrap">{msg.content}</p>
              </div>
            </div>
          ))}
          {isLoading && (
            <div className="flex gap-3">
              <div className="w-8 h-8 rounded-full bg-wizard-accent flex items-center justify-center"><Bot className="w-4 h-4" /></div>
              <div className="bg-wizard-panel border border-wizard-accent p-3 rounded-lg">
                <div className="flex gap-1">
                  <span className="w-2 h-2 bg-wizard-muted rounded-full animate-bounce" />
                  <span className="w-2 h-2 bg-wizard-muted rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                  <span className="w-2 h-2 bg-wizard-muted rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                </div>
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        <div className="p-4 border-t border-wizard-accent">
          <div className="flex gap-2">
            <input type="text" value={inputValue} onChange={e => setInputValue(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && handleSend()}
              placeholder="Ask about scaling, stability, bifurcations..."
              className="flex-1 px-4 py-2 bg-wizard-accent text-wizard-text rounded-lg border border-wizard-accent focus:border-wizard-highlight outline-none" />
            <button onClick={handleSend} disabled={!inputValue.trim() || isLoading}
              className="px-4 py-2 bg-wizard-highlight text-white rounded-lg hover:bg-wizard-highlight/80 disabled:opacity-50 transition-colors">
              <Send className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
