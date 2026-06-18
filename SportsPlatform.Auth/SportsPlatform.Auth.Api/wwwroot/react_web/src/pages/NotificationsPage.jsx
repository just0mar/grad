import TopBar from '../components/TopBar';
import PageTransition from '../components/PageTransition';
import EmptyState from '../components/EmptyState';
import { Bell } from 'lucide-react';

export default function NotificationsPage() {
  return (
    <PageTransition className="flex-1">
      <TopBar title="Notifications" showBack />
      <div className="px-4 pb-24 lg:pb-8 flex items-center justify-center min-h-[50vh]">
        <EmptyState icon={Bell} title="Coming Soon" subtitle="Notifications will be available in a future update" />
      </div>
    </PageTransition>
  );
}
