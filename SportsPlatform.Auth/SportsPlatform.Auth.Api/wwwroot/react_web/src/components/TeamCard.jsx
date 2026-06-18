import { motion } from 'framer-motion';
import { Globe, Users } from 'lucide-react';
import { cardHover } from '../animations/variants';
import useTheme from '../hooks/useTheme';

export default function TeamCard({ team, selected = false, onClick }) {
  const { isDark } = useTheme();

  if (!team) return null;

  return (
    <motion.div
      variants={cardHover}
      initial="rest"
      whileHover="hover"
      whileTap="tap"
      onClick={onClick}
      className={`rounded-2xl flex flex-col items-center justify-center p-6 shadow-md border cursor-pointer min-h-[160px] md:min-h-[180px] lg:min-h-[200px] transition-colors ${
        selected
          ? 'bg-primary text-white border-primary shadow-lg'
          : isDark
          ? 'bg-surface-dark border-white/5 hover:border-primary/30'
          : 'bg-white/80 border-gray-100 hover:border-primary/30'
      }`}
    >
      <div className={`w-14 h-14 md:w-16 md:h-16 rounded-full flex items-center justify-center mb-3 ${selected ? 'bg-white/20' : 'bg-primary/10'}`}>
        <Globe size={24} className={selected ? 'text-white' : 'text-primary'} />
      </div>
      <h3 className={`text-base md:text-lg font-bold text-center ${selected ? 'text-white' : isDark ? 'text-white' : 'text-black'}`}>
        {team.teamName}
      </h3>
      <div className="flex items-center gap-1 mt-1.5">
        <Users size={14} className={selected ? 'text-white/70' : isDark ? 'text-white/50' : 'text-gray-500'} />
        <p className={`text-sm font-medium ${selected ? 'text-white/80' : isDark ? 'text-white/70' : 'text-gray-600'}`}>
          {team.memberCount || 0} members
        </p>
      </div>
      {team.creatorName && (
        <span className={`text-xs mt-2 px-2 py-0.5 rounded-pill ${
          selected ? 'bg-white/15 text-white/80' : isDark ? 'bg-white/10 text-white/50' : 'bg-gray-100 text-gray-500'
        }`}>
          {team.creatorName}
        </span>
      )}
    </motion.div>
  );
}
