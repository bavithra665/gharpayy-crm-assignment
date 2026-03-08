import { ReactNode, useState } from 'react';
import AppSidebar from './AppSidebar';
import CommandPalette from './CommandPalette';
import NotificationBell from './NotificationBell';
import QuickAddLead from './QuickAddLead';
import { Menu, Search } from 'lucide-react';
import { motion } from 'framer-motion';

export interface AppLayoutProps {
  children: ReactNode;
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}

const AppLayout = ({ children, title, subtitle, actions }: AppLayoutProps) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [cmdOpen, setCmdOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background">
      <AppSidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="lg:ml-[240px]">
        {/* Top bar */}
        <header className="sticky top-0 z-30 bg-background/70 glass border-b border-border px-4 md:px-8 py-4 flex items-center justify-between gap-4">
          <div className="flex items-center gap-3 min-w-0">
            <button className="lg:hidden p-2 -ml-2 rounded-xl hover:bg-secondary transition-colors" onClick={() => setSidebarOpen(true)}>
              <Menu size={20} className="text-foreground" />
            </button>
            <div className="min-w-0">
              <h1 className="font-display font-bold text-base md:text-lg text-foreground truncate tracking-tight">{title}</h1>
              {subtitle && <p className="text-2xs text-muted-foreground mt-0.5 truncate">{subtitle}</p>}
            </div>
          </div>
          <div className="flex items-center gap-2 md:gap-3 shrink-0">
            {actions}
            <NotificationBell />
            <button
              onClick={() => setCmdOpen(true)}
              className="hidden md:flex items-center gap-2 px-3 py-2 text-2xs text-muted-foreground bg-secondary rounded-xl hover:bg-muted transition-colors"
            >
              <Search size={14} />
              <span>Search...</span>
              <kbd className="ml-2 px-1.5 py-0.5 bg-background rounded text-[10px] font-mono border border-border">⌘K</kbd>
            </button>
            <button
              onClick={() => setCmdOpen(true)}
              className="md:hidden p-2 rounded-xl bg-secondary hover:bg-muted transition-colors"
            >
              <Search size={16} className="text-muted-foreground" />
            </button>
          </div>
        </header>

        {/* Content */}
        <motion.main
          className="p-4 md:p-8"
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, ease: [0.32, 0.72, 0, 1] }}
        >
          {children}
        </motion.main>
      </div>

      <CommandPalette open={cmdOpen} onOpenChange={setCmdOpen} />
      <QuickAddLead />
    </div>
  );
};

export default AppLayout;
