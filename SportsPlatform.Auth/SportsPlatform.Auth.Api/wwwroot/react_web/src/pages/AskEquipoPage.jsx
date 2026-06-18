import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import { Bot } from 'lucide-react';

export default function AskEquipoPage() {
  return (
    <PageTransition className="flex-1">
      <TopBar title="Ask Equipo" showBack />
      <div className="px-4 pb-24 lg:pb-8 flex items-center justify-center min-h-[50vh]">
        <EmptyState icon={Bot} title="Coming Soon" subtitle="AI assistant will be available in a future update" />
      </div>
    </PageTransition>
  );
}
