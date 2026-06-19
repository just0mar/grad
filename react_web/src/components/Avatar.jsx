export default function Avatar({ src, alt, size = 'md', className = '' }) {
  const sizes = {
    sm: 'w-8 h-8',
    md: 'w-12 h-12',
    lg: 'w-16 h-16',
    xl: 'w-20 h-20',
  };

  return (
    <img
      src={src || '/assets/clubicon.png'}
      alt={alt}
      className={`${sizes[size]} rounded-full object-cover bg-gray-200 ${className}`}
    />
  );
}
