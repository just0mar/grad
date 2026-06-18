import useTheme from '../hooks/useTheme';

export default function EmptyState({ icon: Icon, title, subtitle }) {
  const { isDark } = useTheme();

  return (
    <div className="flex flex-col items-center justify-center py-16 px-8">
      {Icon && <Icon size={48} className={isDark ? 'text-white/30' : 'text-gray-300'} />}
      <p className={`mt-4 text-body-lg font-semibold ${isDark ? 'text-white/50' : 'text-gray-500'}`}>
        {title}
      </p>
      {subtitle && (
        <p className={`mt-1 text-body ${isDark ? 'text-white/30' : 'text-gray-400'}`}>
          {subtitle}
        </p>
      )}
    </div>
  );
}
