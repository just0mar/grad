import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { motion } from 'framer-motion';
import { pageVariants } from '../animations/variants';
import FormInput from '../components/FormInput';
import useAuth from '../hooks/useAuth';

export default function SignUpPage() {
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [username, setUsername] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [dob, setDob] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();
  const { signup } = useAuth();

  const handleSignUp = async () => {
    if (!email || !name || !password || !dob) {
      setError('Please fill in all required fields (Email, Name, Password, Date of Birth)');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    setError('');
    setIsLoading(true);
    try {
      await signup({ email, password, name, username: username || undefined, phoneNumber: phoneNumber || undefined, dob });
      navigate('/congrats', { replace: true });
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.message || 'Registration failed. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <motion.div
      variants={pageVariants}
      initial="initial"
      animate="animate"
      exit="exit"
      className="min-h-screen bg-gradient-to-b from-primary to-white dark:from-surface-darker dark:to-surface-darkest relative overflow-hidden"
    >
      <div className="absolute inset-0 bg-[url('/assets/background.png')] bg-cover bg-center opacity-15" />

      <div className="relative z-10 min-h-screen flex flex-col px-6 pt-6 pb-8 max-w-lg mx-auto w-full">
        {/* Header */}
        <div className="flex items-center gap-2 mb-8">
          <button
            onClick={() => navigate('/onboarding')}
            className="p-2 rounded-full text-black dark:text-white hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
            id="btn-signup-back"
          >
            <ArrowLeft size={22} />
          </button>
          <h1 className="font-display text-title text-black dark:text-white uppercase">
            SIGN UP
          </h1>
        </div>

        {/* Error message */}
        {error && (
          <div className="mb-4 p-3 rounded-card bg-red-500/10 border border-red-500/30 text-red-500 text-sm font-medium">
            {error}
          </div>
        )}

        {/* Form */}
        <div className="flex flex-col gap-4">
          <FormInput label="Email *" type="email" value={email} onChange={(e) => setEmail(e.target.value)} id="input-signup-email" />
          <FormInput label="Full Name *" value={name} onChange={(e) => setName(e.target.value)} id="input-signup-name" />
          <FormInput label="Username (optional)" value={username} onChange={(e) => setUsername(e.target.value)} id="input-signup-username" />
          <FormInput label="Phone Number (optional)" type="tel" value={phoneNumber} onChange={(e) => setPhoneNumber(e.target.value)} id="input-signup-phone" />
          <FormInput label="Password *" type="password" value={password} onChange={(e) => setPassword(e.target.value)} id="input-signup-password" />
          <FormInput label="Confirm Password *" type="password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} id="input-signup-confirm" />
          <FormInput label="Date of Birth *" type="date" value={dob} onChange={(e) => setDob(e.target.value)} id="input-signup-dob" />

          <button
            onClick={handleSignUp}
            disabled={isLoading}
            className="w-full py-3.5 rounded-card bg-primary text-white font-semibold text-body-lg hover:bg-primary-dark transition-colors mt-2 disabled:opacity-60"
            id="btn-finish-signup"
          >
            {isLoading ? 'Creating account...' : 'Create Account'}
          </button>
        </div>
      </div>
    </motion.div>
  );
}
