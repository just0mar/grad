import useTheme from '../hooks/useTheme';

export default function FormInput({
  label,
  type = 'text',
  value,
  onChange,
  id,
  ...props
}) {
  const { isDark } = useTheme();

  return (
    <div className="w-full">
      <input
        type={type}
        value={value}
        onChange={onChange}
        placeholder={label}
        id={id}
        className={`w-full px-4 py-3 rounded-card border-2 text-body outline-none transition-colors ${
          isDark
            ? 'bg-surface-dark text-white border-accent/50 focus:border-accent placeholder:text-white/40'
            : 'bg-white text-black border-accent/50 focus:border-accent placeholder:text-black/40'
        }`}
        {...props}
      />
    </div>
  );
}
