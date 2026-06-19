import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Users, Calendar, Shield, Zap, Trophy, BarChart3 } from 'lucide-react';

const FLOATING_ICONS = [
  { icon: '⚽', x: '10%', y: '20%', size: 40, delay: 0 },
  { icon: '🏀', x: '85%', y: '15%', size: 36, delay: 0.5 },
  { icon: '🏐', x: '75%', y: '75%', size: 32, delay: 1 },
  { icon: '🎾', x: '15%', y: '80%', size: 28, delay: 1.5 },
  { icon: '⛹️', x: '90%', y: '50%', size: 34, delay: 0.8 },
  { icon: '🏆', x: '5%', y: '50%', size: 38, delay: 1.2 },
];

const FEATURES = [
  { icon: Users, text: 'Team Management' },
  { icon: Calendar, text: 'Event Scheduling' },
  { icon: Shield, text: 'Squad Selection' },
  { icon: BarChart3, text: 'Performance Analytics' },
];

export default function SplashPage() {
  const navigate = useNavigate();
  const [showContent, setShowContent] = useState(false);

  useEffect(() => {
    const t1 = setTimeout(() => setShowContent(true), 600);
    const t2 = setTimeout(() => navigate('/onboarding', { replace: true }), 5500);
    return () => { clearTimeout(t1); clearTimeout(t2); };
  }, [navigate]);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center relative overflow-hidden bg-[#020806]">
      {/* Animated gradient background */}
      <div className="absolute inset-0">
        <div className="absolute inset-0 bg-gradient-to-br from-primary-dark/40 via-[#020806] to-surface-darker" />
        <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-[0.06]" />
        {/* Radial glow behind logo */}
        <motion.div
          className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] lg:w-[900px] lg:h-[900px] rounded-full"
          style={{ background: 'radial-gradient(circle, rgba(76,175,80,0.15) 0%, transparent 70%)' }}
          animate={{ scale: [1, 1.15, 1], opacity: [0.6, 1, 0.6] }}
          transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      {/* Floating sport icons */}
      {FLOATING_ICONS.map((item, i) => (
        <motion.div
          key={i}
          className="absolute pointer-events-none select-none"
          style={{ left: item.x, top: item.y, fontSize: item.size }}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: [0, 0.3, 0.15, 0.3], y: [20, -10, 20] }}
          transition={{ duration: 6, repeat: Infinity, delay: item.delay, ease: 'easeInOut' }}
        >
          {item.icon}
        </motion.div>
      ))}

      {/* Main content */}
      <div className="relative z-10 flex flex-col items-center gap-6 px-6 max-w-3xl mx-auto w-full">
        {/* Logo — large and prominent */}
        <motion.div
          className="relative"
          initial={{ opacity: 0, scale: 0.5 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8, ease: [0.42, 0, 0.58, 1] }}
        >
          {/* Glow ring around logo */}
          <motion.div
            className="absolute inset-0 rounded-full"
            style={{ boxShadow: '0 0 60px 20px rgba(76,175,80,0.2), 0 0 120px 60px rgba(76,175,80,0.1)' }}
            animate={{ scale: [1, 1.1, 1], opacity: [0.5, 1, 0.5] }}
            transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut' }}
          />
          <motion.img
            src="/assets/logo.png"
            alt="Equipex"
            className="w-40 h-40 md:w-52 md:h-52 lg:w-64 lg:h-64 object-contain relative z-10 drop-shadow-[0_0_30px_rgba(76,175,80,0.3)]"
            animate={{ rotate: 360 }}
            transition={{ duration: 20, repeat: Infinity, ease: 'linear' }}
          />
        </motion.div>

        {/* Brand name */}
        <motion.div
          className="text-center"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3, ease: [0.42, 0, 0.58, 1] }}
        >
          <h1 className="font-display text-5xl md:text-6xl lg:text-7xl text-white uppercase tracking-[0.2em]">
            Equipex
          </h1>
          <motion.div
            className="h-[2px] bg-gradient-to-r from-transparent via-primary to-transparent mt-4 mx-auto"
            initial={{ width: 0 }}
            animate={{ width: '100%' }}
            transition={{ duration: 1.2, delay: 0.8, ease: [0.42, 0, 0.58, 1] }}
          />
          <motion.p
            className="text-white/50 text-base md:text-lg lg:text-xl mt-4 tracking-widest uppercase font-light"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6, delay: 1 }}
          >
            Sports Club Management Platform
          </motion.p>
        </motion.div>

        {/* Feature pills — appear on delay */}
        {showContent && (
          <motion.div
            className="flex flex-wrap justify-center gap-3 mt-4"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: [0.42, 0, 0.58, 1] }}
          >
            {FEATURES.map((f, i) => (
              <motion.div
                key={f.text}
                className="flex items-center gap-2 px-4 py-2 rounded-pill bg-white/5 border border-white/10 backdrop-blur-sm"
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.3, delay: i * 0.1 }}
              >
                <f.icon size={16} className="text-primary" />
                <span className="text-white/70 text-sm font-medium">{f.text}</span>
              </motion.div>
            ))}
          </motion.div>
        )}

        {/* Loading bar */}
        <motion.div
          className="w-48 md:w-64 h-1 bg-white/10 rounded-full overflow-hidden mt-6"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
        >
          <motion.div
            className="h-full bg-gradient-to-r from-primary to-primary-light rounded-full"
            initial={{ width: '0%' }}
            animate={{ width: '100%' }}
            transition={{ duration: 4.5, ease: 'easeInOut', delay: 0.5 }}
          />
        </motion.div>
      </div>
    </div>
  );
}
