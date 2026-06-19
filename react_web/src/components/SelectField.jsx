import useTheme from '../hooks/useTheme';

export default function SelectField({ label, value, onChange, options = [], optionValues, id }) {
  const { isDark } = useTheme();

  return (
    <div className="w-full">
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        id={id}
        className={`w-full px-4 py-3 rounded-card border-2 text-body outline-none transition-colors appearance-none cursor-pointer ${
          isDark
            ? 'bg-surface-dark text-white border-accent/50 focus:border-accent'
            : 'bg-white text-black border-accent/50 focus:border-accent'
        }`}
      >
        <option value="" disabled>
          {label}
        </option>
        {options.map((opt, i) => (
          <option key={optionValues ? optionValues[i] : opt} value={optionValues ? optionValues[i] : opt}>
            {opt}
          </option>
        ))}
      </select>
    </div>
  );
}
