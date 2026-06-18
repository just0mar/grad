import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { motion } from 'framer-motion';
import { pageVariants } from '../animations/variants';
import FormInput from '../components/FormInput';
import useAuth from '../hooks/useAuth';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();
  const { login } = useAuth();

  const handleLogin = async () => {
    if (!email || !password) {
      setError('Please enter email and password');
      return;
    }
    setError('');
    setIsLoading(true);
    try {
      await login({ email, password });
      navigate('/app', { replace: true });
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.message || 'Login failed. Please check your credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleGoogleLogin = () => {
    // Redirect to the shared backend Google OAuth endpoint.
    const baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5122';
    const returnUrl = `${window.location.origin}/app`;
    window.location.href = `${baseUrl}/auth/google?returnUrl=${encodeURIComponent(returnUrl)}`;
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') handleLogin();
  };

  return (
    <motion.div
      variants={pageVariants}
      initial="initial"
      animate="animate"
      exit="exit"
      className="min-h-screen bg-gradient-to-b from-primary to-white dark:from-surface-darker dark:to-surface-darkest relative overflow-hidden"
    >
      {/* Pattern overlay */}
      <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-[0.08]" />

      {/* Desktop: center the form in a card / Mobile: full-screen */}
      <div className="relative z-10 min-h-screen flex flex-col items-center justify-center px-6 py-8">
        <div className="w-full max-w-md lg:max-w-lg lg:bg-white/80 lg:dark:bg-surface-dark/80 lg:backdrop-blur-xl lg:rounded-3xl lg:p-10 lg:shadow-2xl lg:border lg:border-white/20 lg:dark:border-white/5">
          {/* Header */}
          <div className="flex items-center gap-2 mb-8">
            <button
              onClick={() => navigate('/onboarding')}
              className="p-2 rounded-full text-black dark:text-white hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
              id="btn-login-back"
            >
              <ArrowLeft size={22} />
            </button>
            <h1 className="font-display text-3xl md:text-4xl text-black dark:text-white uppercase">
              LOG IN
            </h1>
          </div>

          {/* Error message */}
          {error && (
            <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm font-medium">
              {error}
            </div>
          )}

          {/* Form */}
          <div className="flex flex-col gap-4" onKeyDown={handleKeyDown}>
            <FormInput
              label="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              id="input-email"
            />
            <FormInput
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              id="input-password"
            />

            <button
              onClick={handleLogin}
              disabled={isLoading}
              className="w-full py-3.5 rounded-card bg-primary text-white font-semibold text-lg hover:bg-primary-dark transition-colors mt-2 shadow-lg shadow-primary/25 disabled:opacity-60"
              id="btn-login-submit"
            >
              {isLoading ? 'Logging in...' : 'Log in'}
            </button>

            <button
              onClick={() => navigate('/signup')}
              className="w-full py-3.5 rounded-card border-2 border-black dark:border-white text-black dark:text-white font-semibold text-lg hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
              id="btn-create-account"
            >
              Create Account
            </button>

            {/* Social login */}
            <div className="flex justify-center gap-5 mt-6">
              <button
                onClick={handleGoogleLogin}
                className="w-12 h-12 flex items-center justify-center rounded-full bg-gray-100 dark:bg-white/10 hover:bg-gray-200 dark:hover:bg-white/20 transition-colors"
                id="btn-google-login"
              >
                <span className="text-2xl text-red-500 font-bold leading-none">G</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
