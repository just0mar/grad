import useTheme from '../hooks/useTheme';

export default function AnnouncementCard({ announcement }) {
  const { isDark } = useTheme();
  const a = announcement;

  const bgColor = a.isEmergency
    ? isDark ? 'bg-red-900/80' : 'bg-red-50'
    : isDark ? 'bg-surface-dark' : 'bg-white';

  const borderStyle = a.isEmergency
    ? isDark ? 'border border-red-400/50' : 'border border-red-200'
    : '';

  return (
    <div
      className={`rounded-card p-4 mb-3 shadow-sm ${bgColor} ${borderStyle}`}
      id={`announcement-${a.id}`}
    >
      <div className="flex items-center gap-3">
        <img
          src={a.authorImage}
          alt={a.authorName}
          className="w-12 h-12 rounded-full object-cover bg-gray-200"
        />
        <div className="flex-1">
          <p className={`font-bold text-[15px] ${isDark ? 'text-white' : 'text-black'}`}>
            {a.authorName}
          </p>
          <p className={`text-body-sm ${isDark ? 'text-white/50' : 'text-black/50'}`}>
            {a.authorRole}
          </p>
        </div>
        {a.isEmergency && (
          <span className="px-2 py-1 rounded-pill bg-red-500 text-white text-badge">
            Emergency
          </span>
        )}
      </div>
      <p className={`mt-2.5 text-body ${isDark ? 'text-white' : 'text-black'}`}>
        {a.caption}
      </p>
    </div>
  );
}
