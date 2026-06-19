export default function LoadingSpinner() {
  return (
    <div className="flex items-center justify-center min-h-[200px] w-full">
      <div className="relative">
        <div className="w-12 h-12 rounded-full border-4 border-primary/20 border-t-primary animate-spin" />
      </div>
    </div>
  );
}
