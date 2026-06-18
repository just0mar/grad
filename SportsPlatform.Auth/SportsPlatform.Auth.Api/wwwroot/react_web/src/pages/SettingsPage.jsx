import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import useTheme from '../hooks/useTheme';
import { Moon, Sun, Bell, Shield, Info, ChevronRight } from 'lucide-react';

export default function SettingsPage() {
  const { isDark, toggleTheme } = useTheme();

  const items = [
    { icon: isDark ? Sun : Moon, label: isDark ? 'Light Mode' : 'Dark Mode', onClick: toggleTheme },
    { icon: Bell, label: 'Notification Preferences', onClick: () => {} },
    { icon: Shield, label: 'Privacy & Security', onClick: () => {} },
    { icon: Info, label: 'About Equipex', onClick: () => {} },
  ];

  return (
    <PageTransition className="flex-1">
      <TopBar title="Settings" showBack />
      <div className="px-4 pb-24 lg:pb-8">
        <div className={`rounded-2xl overflow-hidden ${isDark ? 'bg-surface-dark' : 'bg-white shadow-sm'}`}>
          {items.map((item, i) => (
            <button key={item.label} onClick={item.onClick}
              className={`w-full flex items-center justify-between px-4 py-4 transition-colors ${isDark ? 'hover:bg-white/5' : 'hover:bg-gray-50'} ${i < items.length - 1 ? (isDark ? 'border-b border-white/5' : 'border-b border-gray-100') : ''}`}>
              <div className="flex items-center gap-3">
                <item.icon size={20} className={isDark ? 'text-white/70' : 'text-gray-600'} />
                <span className={`text-body font-medium ${isDark ? 'text-white' : 'text-black'}`}>{item.label}</span>
              </div>
              <ChevronRight size={18} className={isDark ? 'text-white/40' : 'text-gray-400'} />
            </button>
          ))}
        </div>
      </div>
    </PageTransition>
  );
}
