import { motion } from 'framer-motion';
import { Trophy, Dumbbell, FileText, FlaskConical } from 'lucide-react';
import { cardHover } from '../animations/variants';

const EVENT_CONFIG = {
  Match: { gradient: ['#0D47A1', '#1976D2'], icon: Trophy, image: '/assets/ball.jpg' },
  Training: { gradient: ['#1B5E20', '#2E7D32'], icon: Dumbbell, image: '/assets/Dumbell.jpg' },
  Meeting: { gradient: ['#66BB6A', '#4CAF50'], icon: FileText, image: '/assets/event.jpg' },
  Test: { gradient: ['#082E6F', '#0D47A1'], icon: FlaskConical, image: '/assets/event.jpg' },
};

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default function EventCard({ event }) {
  const config = EVENT_CONFIG[event.eventType] || EVENT_CONFIG.Meeting;
  const Icon = config.icon;
  const date = new Date(event.startAt);
  const dateStr = `${date.getDate()} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
  const timeStr = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  return (
    <motion.div
      variants={cardHover} initial="rest" whileHover="hover" whileTap="tap"
      className="w-[155px] md:w-[200px] lg:w-[240px] h-[150px] md:h-[170px] lg:h-[190px] flex-shrink-0 rounded-event overflow-hidden relative cursor-pointer"
      style={{ boxShadow: `0 4px 10px ${config.gradient[0]}80` }}
    >
      <img src={config.image} alt={event.eventType} className="absolute inset-0 w-full h-full object-cover" />
      <div className="absolute inset-0" style={{ background: `linear-gradient(to top, ${config.gradient[0]}E0, ${config.gradient[1]}73)` }} />
      <div className="relative z-10 flex flex-col justify-between h-full p-3.5 md:p-4">
        <span className="self-start px-2.5 py-1 rounded-pill bg-white/25 text-white text-xs md:text-sm font-bold backdrop-blur-sm">
          {event.eventType}
        </span>
        <Icon size={30} className="text-white md:hidden" />
        <Icon size={36} className="text-white hidden md:block" />
        <div>
          <p className="text-white text-xs md:text-sm font-bold">{event.title || dateStr}</p>
          <p className="text-white/70 text-[11px] md:text-xs">{dateStr} · {timeStr}</p>
          {event.description && <p className="text-white/70 text-[11px] md:text-xs truncate mt-0.5">{event.description}</p>}
        </div>
      </div>
    </motion.div>
  );
}
