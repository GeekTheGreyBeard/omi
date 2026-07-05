'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  getMemories,
  getReviewInbox,
  reviewInboxItem,
  reviewMemory,
  updateReviewInboxItem,
} from '@/lib/api';
import type {
  Memory,
  ReviewInboxSummary,
  ReviewItem,
  ReviewItemType,
} from '@/types/conversation';

export type ReviewTypeFilter = ReviewItemType | 'all';

const EMPTY_SUMMARY: ReviewInboxSummary = {
  pending: 0,
  memories: 0,
  actions: 0,
};

function memoryToReviewItem(memory: Memory): ReviewItem {
  return {
    id: memory.id,
    type: 'memory',
    status: 'pending',
    content: memory.content,
    proposed_content: memory.content,
    created_at: memory.created_at,
    updated_at: memory.updated_at,
    confidence: memory.scoring ? Number(memory.scoring) : null,
    tags: memory.tags || [],
    source: {
      conversation_id: memory.conversation_id,
      app_id: memory.app_id,
    },
    raw: memory,
  };
}

function isMissingReviewRoute(error: unknown): boolean {
  return error instanceof Error && error.message.includes('404');
}

export interface UseReviewInboxReturn {
  items: ReviewItem[];
  summary: ReviewInboxSummary;
  loading: boolean;
  savingId: string | null;
  error: string | null;
  backendMode: 'review-api' | 'memory-fallback' | 'unavailable';
  typeFilter: ReviewTypeFilter;
  setTypeFilter: (filter: ReviewTypeFilter) => void;
  refresh: () => Promise<void>;
  approve: (item: ReviewItem) => Promise<void>;
  reject: (item: ReviewItem) => Promise<void>;
  updateItem: (
    item: ReviewItem,
    updates: Partial<Pick<ReviewItem, 'content' | 'proposed_content' | 'due_at' | 'tags'>>,
  ) => Promise<void>;
}

export function useReviewInbox(): UseReviewInboxReturn {
  const [items, setItems] = useState<ReviewItem[]>([]);
  const [summary, setSummary] = useState<ReviewInboxSummary>(EMPTY_SUMMARY);
  const [typeFilter, setTypeFilter] = useState<ReviewTypeFilter>('all');
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [backendMode, setBackendMode] = useState<UseReviewInboxReturn['backendMode']>('review-api');

  const loadFallbackMemories = useCallback(async () => {
    const memories = await getMemories({ limit: 100 });
    const pendingMemories = memories
      .filter((memory) => !memory.reviewed && !memory.deleted)
      .map(memoryToReviewItem);

    setItems(pendingMemories);
    setSummary({
      pending: pendingMemories.length,
      memories: pendingMemories.length,
      actions: 0,
    });
    setBackendMode('memory-fallback');
  }, []);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await getReviewInbox({
        limit: 100,
        status: 'pending',
        type: typeFilter,
      });
      setItems(response.items);
      setSummary(response.summary);
      setBackendMode('review-api');
    } catch (err) {
      if (isMissingReviewRoute(err)) {
        try {
          await loadFallbackMemories();
          setError('Unified review API is not available yet. Showing unreviewed memories only.');
        } catch (fallbackErr) {
          setBackendMode('unavailable');
          setItems([]);
          setSummary(EMPTY_SUMMARY);
          setError(fallbackErr instanceof Error ? fallbackErr.message : 'Failed to load review inbox');
        }
      } else {
        setBackendMode('unavailable');
        setItems([]);
        setSummary(EMPTY_SUMMARY);
        setError(err instanceof Error ? err.message : 'Failed to load review inbox');
      }
    } finally {
      setLoading(false);
    }
  }, [loadFallbackMemories, typeFilter]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const removeLocalItem = useCallback((id: string) => {
    setItems((current) => current.filter((item) => item.id !== id));
    setSummary((current) => ({
      ...current,
      pending: Math.max(0, current.pending - 1),
    }));
  }, []);

  const approve = useCallback(async (item: ReviewItem) => {
    setSavingId(item.id);
    setError(null);

    try {
      if (backendMode === 'memory-fallback' && item.type === 'memory') {
        await reviewMemory(item.id, true);
      } else {
        await reviewInboxItem(item.id, true);
      }
      removeLocalItem(item.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to approve item');
    } finally {
      setSavingId(null);
    }
  }, [backendMode, removeLocalItem]);

  const reject = useCallback(async (item: ReviewItem) => {
    setSavingId(item.id);
    setError(null);

    try {
      if (backendMode === 'memory-fallback' && item.type === 'memory') {
        await reviewMemory(item.id, false);
      } else {
        await reviewInboxItem(item.id, false);
      }
      removeLocalItem(item.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to reject item');
    } finally {
      setSavingId(null);
    }
  }, [backendMode, removeLocalItem]);

  const updateItem = useCallback<UseReviewInboxReturn['updateItem']>(async (item, updates) => {
    if (backendMode === 'memory-fallback') {
      setError('Editing review candidates needs the unified /v1/review/items/{id} route.');
      return;
    }

    setSavingId(item.id);
    setError(null);

    try {
      const updated = await updateReviewInboxItem(item.id, updates);
      setItems((current) => current.map((candidate) => (
        candidate.id === item.id ? { ...candidate, ...updated } : candidate
      )));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update item');
    } finally {
      setSavingId(null);
    }
  }, [backendMode]);

  const filteredItems = useMemo(() => {
    if (typeFilter === 'all' || backendMode === 'review-api') {
      return items;
    }

    return items.filter((item) => item.type === typeFilter);
  }, [backendMode, items, typeFilter]);

  return {
    items: filteredItems,
    summary,
    loading,
    savingId,
    error,
    backendMode,
    typeFilter,
    setTypeFilter,
    refresh,
    approve,
    reject,
    updateItem,
  };
}
