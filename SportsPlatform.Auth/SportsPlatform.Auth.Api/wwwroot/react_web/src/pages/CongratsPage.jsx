import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { scaleIn } from '../animations/variants';

export default function CongratsPage() {
  const navigate = useNavigate();

  const handleContinue = () => {
    navigate('/app', { replace: true });
  };

  return (
    <motion.div
      variants={scaleIn}
      initial="initial"
      animate="animate"
      exit="exit"
      className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-b from-primary to-white dark:from-surface-darker dark:to-surface-darkest relative overflow-hidden px-6"
    >
      <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-15" />

      <div className="relative z-10 flex flex-col items-center text-center max-w-md">
        <motion.img
          src="/assets/congrats.png"
          alt="Congratulations"
          className="w-48 h-48 object-contain mb-6"
          animate={{ scale: [1, 1.05, 1] }}
          transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
        />

        <h1 className="font-display text-title text-black dark:text-white uppercase mb-3">
          Congratulations!
        </h1>

        <p className="text-body-lg text-black/70 dark:text-white/70 mb-2">
          Your account has been created successfully.
        </p>

        <p className="text-body text-black/50 dark:text-white/50 mb-8">
          You can now create a club, join teams via invitations, and start managing your sports platform.
        </p>

        <button
          onClick={handleContinue}
          className="w-full max-w-xs py-3.5 rounded-card bg-primary text-white font-semibold text-body-lg hover:bg-primary-dark transition-colors"
          id="btn-congrats-continue"
        >
          Get Started
        </button>
      </div>
    </motion.div>
  );
}
