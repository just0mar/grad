import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { onboardingSlide } from '../animations/variants';
import { ChevronRight, ChevronLeft } from 'lucide-react';

const PAGES = [
  {
    image: '/assets/unite.png',
    title: 'UNITE',
    body: 'Bring together athletes, coaches, and staff into one powerful platform. Manage your club like a pro with tools built for every role.',
    accent: 'from-primary/20 to-emerald-500/10',
  },
  {
    image: '/assets/tactical.png',
    title: 'TACTICAL',
    body: 'Plan strategies, track performance, and stay ahead of the competition. Every match, every session — optimized for peak performance.',
    accent: 'from-blue-500/20 to-indigo-500/10',
  },
  {
    image: '/assets/peak.png',
    title: 'PEAK',
    body: 'Reach your full potential with Equipex. Whether you are a player, coach, or manager — this is your edge.',
    accent: 'from-amber-500/20 to-orange-500/10',
  },
];

export default function OnboardingPage() {
  const [current, setCurrent] = useState(0);
  const [direction, setDirection] = useState(0);
  const navigate = useNavigate();

  const goNext = () => {
    if (current < PAGES.length - 1) {
      setDirection(1);
      setCurrent((p) => p + 1);
    }
  };

  const goPrev = () => {
    if (current > 0) {
      setDirection(-1);
      setCurrent((p) => p - 1);
    }
  };

  const page = PAGES[current];

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-b from-primary to-white dark:from-surface-darker dark:to-surface-darkest relative overflow-hidden">
      {/* Background pattern overlay */}
      <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-[0.08]" />

      {/* Desktop: two-column split / Mobile: stacked */}
      <div className="relative z-10 flex-1 flex flex-col lg:flex-row items-center justify-center px-6 lg:px-16 max-w-7xl mx-auto w-full gap-8 lg:gap-16">

        {/* Left side — Image */}
        <div className="flex-1 flex items-center justify-center lg:justify-end w-full max-w-md lg:max-w-lg">
          <AnimatePresence mode="wait" custom={direction}>
            <motion.div
              key={current}
              custom={direction}
              variants={onboardingSlide}
              initial="initial"
              animate="animate"
              exit="exit"
              className="relative"
            >
              {/* Soft accent glow behind image */}
              <div className={`absolute inset-0 blur-3xl rounded-full bg-gradient-to-br ${page.accent} scale-110`} />
              <img
                src={page.image}
                alt={page.title}
                className="w-64 h-64 md:w-80 md:h-80 lg:w-96 lg:h-96 object-contain relative z-10"
              />
            </motion.div>
          </AnimatePresence>
        </div>

        {/* Right side — Text content */}
        <div className="flex-1 flex flex-col items-center lg:items-start max-w-md lg:max-w-lg w-full">
          <AnimatePresence mode="wait" custom={direction}>
            <motion.div
              key={`text-${current}`}
              custom={direction}
              variants={onboardingSlide}
              initial="initial"
              animate="animate"
              exit="exit"
              className="text-center lg:text-left"
            >
              <h2 className="font-display text-4xl md:text-5xl lg:text-6xl text-black dark:text-white uppercase tracking-wider mb-4 lg:mb-6">
                {page.title}
              </h2>
              <p className="text-body-lg md:text-lg lg:text-xl text-black/60 dark:text-white/60 leading-relaxed">
                {page.body}
              </p>
            </motion.div>
          </AnimatePresence>

          {/* Page Dots */}
          <div className="flex gap-2.5 mt-8 lg:mt-10 mb-8">
            {PAGES.map((_, i) => (
              <button
                key={i}
                onClick={() => {
                  setDirection(i > current ? 1 : -1);
                  setCurrent(i);
                }}
                className={`h-2.5 rounded-full transition-all duration-300 ${
                  i === current ? 'bg-primary w-10' : 'bg-gray-400/40 w-2.5 hover:bg-gray-400/60'
                }`}
                aria-label={`Go to page ${i + 1}`}
              />
            ))}
          </div>

          {/* Buttons */}
          <div className="w-full flex flex-col gap-3">
            {current === PAGES.length - 1 ? (
              <>
                <button
                  onClick={() => navigate('/login')}
                  className="w-full py-3.5 rounded-card bg-primary text-white font-semibold text-lg hover:bg-primary-dark transition-colors shadow-lg shadow-primary/25"
                  id="btn-login"
                >
                  Log in
                </button>
                <button
                  onClick={() => navigate('/signup')}
                  className="w-full py-3.5 rounded-card border-2 border-black dark:border-white text-black dark:text-white font-semibold text-lg hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
                  id="btn-signup"
                >
                  Create Account
                </button>
              </>
            ) : (
              <div className="flex gap-3">
                {current > 0 && (
                  <button
                    onClick={goPrev}
                    className="flex items-center justify-center gap-1 flex-1 py-3.5 rounded-card border-2 border-gray-300 dark:border-white/20 text-black dark:text-white font-medium hover:bg-gray-100 dark:hover:bg-white/10 transition-colors"
                  >
                    <ChevronLeft size={18} />
                    Back
                  </button>
                )}
                <button
                  onClick={goNext}
                  className="flex items-center justify-center gap-1 flex-1 py-3.5 rounded-card bg-primary text-white font-semibold hover:bg-primary-dark transition-colors shadow-lg shadow-primary/25"
                >
                  Next
                  <ChevronRight size={18} />
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
