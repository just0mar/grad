import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';
import { fabExpand } from '../animations/variants';
import useTheme from '../hooks/useTheme';

export default function SpeedDial({ actions = [], icon: MainIcon }) {
  const [expanded, setExpanded] = useState(false);
  const { isDark } = useTheme();

  return (
    <div className="fixed bottom-20 lg:bottom-8 right-4 z-50 flex flex-col items-end gap-2" id="speed-dial">
      {/* Action buttons */}
      <AnimatePresence>
        {expanded &&
          actions.map((action, i) => (
            <motion.button
              key={action.label}
              custom={actions.length - 1 - i}
              variants={fabExpand}
              initial="initial"
              animate="animate"
              exit="exit"
              onClick={() => {
                setExpanded(false);
                action.onClick?.();
              }}
              className={`flex items-center gap-2 px-4 py-3 rounded-pill text-sm font-medium shadow-lg transition-colors ${
                isDark
                  ? 'bg-surface-dark text-white border border-white/10 hover:bg-accent/20 hover:border-accent'
                  : 'bg-white text-black border border-transparent hover:bg-accent/10 hover:border-accent'
              }`}
              id={`fab-action-${action.label.toLowerCase().replace(/\s+/g, '-')}`}
            >
              {action.icon && <action.icon size={18} className="text-primary" />}
              <span>{action.label}</span>
            </motion.button>
          ))}
      </AnimatePresence>

      {/* Main FAB */}
      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={() => setExpanded((prev) => !prev)}
        className="w-14 h-14 rounded-full bg-primary-dark flex items-center justify-center shadow-xl text-white transition-transform"
        id="fab-main"
        aria-label={expanded ? 'Close menu' : 'Open menu'}
      >
        {expanded ? <X size={24} /> : MainIcon ? <MainIcon size={24} /> : <span className="text-2xl">🏀</span>}
      </motion.button>
    </div>
  );
}
