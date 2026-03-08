import { NavLink, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  Kanban,
  CalendarCheck,
  BarChart3,
  Settings,
  MessageSquare,
  History,
  X,
  LogOut,
  Moon,
  Sun,
} from 'lucide-react';
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/leads', icon: Users, label: 'Leads' },
  { to: '/pipeline', icon: Kanban, label: 'Pipeline' },
  { to: '/visits', icon: CalendarCheck, label: 'Visits' },
  { to: '/conversations', icon: MessageSquare, label: 'Conversations' },
  { to: '/analytics', icon: BarChart3, label: 'Analytics' },
  { to: '/historical', icon: History, label: 'Historical' },
];

const AppSidebar = ({ isOpen, onClose }: { isOpen?: boolean; onClose?: () => void }) => {
  const location = useLocation();
  const [dark, setDark] = useState(() => document.documentElement.classList.contains('dark'));

  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark);
  }, [dark]);

  return (
    <>
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 z-40 bg-foreground/20 glass lg:hidden"
            onClick={onClose}
          />
        )}
      </AnimatePresence>

      <aside
        className={`fixed left-0 top-0 z-50 h-screen w-[240px] flex flex-col border-r transition-transform duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
        style={{ background: 'hsl(var(--sidebar-bg))', borderColor: 'hsl(var(--sidebar-border))' }}
      >
        {/* Logo */}
        <div className="flex items-center justify-between px-5 py-5 border-b" style={{ borderColor: 'hsl(var(--sidebar-border))' }}>
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-accent flex items-center justify-center">
              <span className="text-accent-foreground font-display font-bold text-sm">G</span>
            </div>
            <div>
              <h1 className="font-display font-bold text-[13px] tracking-tight" style={{ color: 'hsl(var(--sidebar-active-fg))' }}>Gharpayy</h1>
              <p className="text-[10px]" style={{ color: 'hsl(var(--sidebar-fg))' }}>Lead Management</p>
            </div>
          </div>
          <button className="lg:hidden p-1 rounded-lg hover:bg-white/10 transition-colors" onClick={onClose}>
            <X size={18} style={{ color: 'hsl(var(--sidebar-fg))' }} />
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
          {navItems.map((item) => {
            const isActive = location.pathname === item.to;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                onClick={onClose}
                className={`sidebar-link ${isActive ? 'active' : ''}`}
              >
                <item.icon size={17} strokeWidth={isActive ? 2.2 : 1.8} />
                {item.label}
              </NavLink>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="px-3 py-4 border-t" style={{ borderColor: 'hsl(var(--sidebar-border))' }}>
          {/* Dark mode toggle */}
          <button
            onClick={() => setDark(!dark)}
            className="sidebar-link w-full mb-0.5"
          >
            {dark ? <Sun size={17} strokeWidth={1.8} /> : <Moon size={17} strokeWidth={1.8} />}
            {dark ? 'Light Mode' : 'Dark Mode'}
          </button>

          <NavLink to="/settings" onClick={onClose} className={`sidebar-link ${location.pathname === '/settings' ? 'active' : ''}`}>
            <Settings size={17} strokeWidth={1.8} />
            Settings
          </NavLink>

          <button onClick={signOut} className="sidebar-link w-full mt-0.5 hover:!text-destructive">
            <LogOut size={17} strokeWidth={1.8} />
            Sign Out
          </button>

          {/* User info */}
          <div className="mt-4 mx-1 p-3 rounded-xl" style={{ background: 'hsl(var(--sidebar-hover))' }}>
            <div className="flex items-center gap-2.5">
              <div className="w-7 h-7 rounded-full bg-accent/20 flex items-center justify-center">
                <span className="text-[10px] font-bold text-accent">
                  {(user?.user_metadata?.full_name || user?.email || 'U').charAt(0).toUpperCase()}
                </span>
              </div>
              <div className="min-w-0">
                <p className="text-[11px] font-medium truncate" style={{ color: 'hsl(var(--sidebar-active-fg))' }}>
                  {user?.user_metadata?.full_name || user?.email?.split('@')[0] || 'User'}
                </p>
                <p className="text-[10px] truncate" style={{ color: 'hsl(var(--sidebar-fg))' }}>
                  {user?.email || ''}
                </p>
              </div>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
};

export default AppSidebar;
