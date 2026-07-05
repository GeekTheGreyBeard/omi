'use client';

import { useEffect } from 'react';
import { ReviewInbox } from '@/components/review/ReviewInbox';
import { MixpanelManager } from '@/lib/analytics/mixpanel';

export default function ReviewPage() {
  useEffect(() => {
    MixpanelManager.pageView('Review Inbox');
  }, []);

  return <ReviewInbox />;
}
