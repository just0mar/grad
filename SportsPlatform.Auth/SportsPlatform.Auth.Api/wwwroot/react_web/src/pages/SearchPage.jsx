import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import { Search as SearchIcon } from 'lucide-react';

export default function SearchPage() {
  return (
    <PageTransition className="flex-1">
      <TopBar title="Search" showBack />
      <div className="px-4 pb-24 lg:pb-8 flex items-center justify-center min-h-[50vh]">
        <EmptyState icon={SearchIcon} title="Coming Soon" subtitle="Search will be available in a future update" />
      </div>
    </PageTransition>
  );
}
