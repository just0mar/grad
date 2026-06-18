// Framer Motion variants mapped from Flutter animations
// All durations/curves extracted from the Flutter source code

export const pageVariants = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0, transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] } },
  exit: { opacity: 0, y: -20, transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] } },
};

export const fadeIn = {
  initial: { opacity: 0 },
  animate: { opacity: 1, transition: { duration: 0.3, ease: 'easeInOut' } },
  exit: { opacity: 0, transition: { duration: 0.2, ease: 'easeInOut' } },
};

export const slideUp = {
  initial: { opacity: 0, y: 40 },
  animate: { opacity: 1, y: 0, transition: { duration: 0.4, ease: [0.42, 0, 0.58, 1] } },
  exit: { opacity: 0, y: 40, transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] } },
};

export const slideInRight = {
  initial: { opacity: 0, x: 60 },
  animate: { opacity: 1, x: 0, transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] } },
  exit: { opacity: 0, x: -60, transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] } },
};

export const scaleIn = {
  initial: { opacity: 0, scale: 0.9 },
  animate: { opacity: 1, scale: 1, transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] } },
  exit: { opacity: 0, scale: 0.9, transition: { duration: 0.2, ease: [0.42, 0, 0.58, 1] } },
};

export const cardHover = {
  rest: { scale: 1 },
  hover: { scale: 1.02, transition: { duration: 0.15, ease: 'easeOut' } },
  tap: { scale: 0.98, transition: { duration: 0.1, ease: 'easeOut' } },
};

export const fabExpand = {
  initial: { opacity: 0, scale: 0.5, y: 20 },
  animate: (i) => ({
    opacity: 1,
    scale: 1,
    y: 0,
    transition: { duration: 0.2, delay: i * 0.05, ease: [0.42, 0, 0.58, 1] },
  }),
  exit: (i) => ({
    opacity: 0,
    scale: 0.5,
    y: 20,
    transition: { duration: 0.15, delay: i * 0.03, ease: [0.42, 0, 0.58, 1] },
  }),
};

export const staggerContainer = {
  animate: {
    transition: {
      staggerChildren: 0.08,
    },
  },
};

export const staggerItem = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0, transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] } },
};

export const onboardingSlide = {
  initial: (direction) => ({
    x: direction > 0 ? 300 : -300,
    opacity: 0,
  }),
  animate: {
    x: 0,
    opacity: 1,
    transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] },
  },
  exit: (direction) => ({
    x: direction > 0 ? -300 : 300,
    opacity: 0,
    transition: { duration: 0.3, ease: [0.42, 0, 0.58, 1] },
  }),
};

export const modalOverlay = {
  initial: { opacity: 0 },
  animate: { opacity: 1, transition: { duration: 0.2 } },
  exit: { opacity: 0, transition: { duration: 0.15 } },
};

export const modalContent = {
  initial: { opacity: 0, scale: 0.95, y: 20 },
  animate: { opacity: 1, scale: 1, y: 0, transition: { duration: 0.25, ease: [0.42, 0, 0.58, 1] } },
  exit: { opacity: 0, scale: 0.95, y: 20, transition: { duration: 0.2 } },
};
