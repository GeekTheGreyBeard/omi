'use client';

import { useMemo, useState } from 'react';
import {
  AlertCircle,
  Brain,
  CalendarClock,
  Check,
  CircleCheck,
  Inbox,
  Loader2,
  RefreshCw,
  Search,
  Sparkles,
  Tag,
  X,
} from 'lucide-react';
import { PageHeader } from '@/components/layout/PageHeader';
import { cn } from '@/lib/utils';
import { useReviewInbox, type ReviewTypeFilter } from '@/hooks/useReviewInbox';
import type { ReviewItem } from '@/types/conversation';

const FILTERS: Array<{ value: ReviewTypeFilter; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'memory', label: 'Memories' },
  { value: 'action', label: 'Actions' },
];

function formatDate(value?: string | null): string {
  if (!value) return 'No date';
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value));
}

function getItemTitle(item: ReviewItem): string {
  if (item.title) return item.title;
  return item.type === 'memory' ? 'Candidate memory' : 'Suggested action';
}

function getItemText(item: ReviewItem): string {
  return item.proposed_content || item.content;
}

function confidenceLabel(confidence?: number | null): string | null {
  if (confidence === undefined || confidence === null || Number.isNaN(confidence)) {
    return null;
  }

  const percent = confidence <= 1 ? Math.round(confidence * 100) : Math.round(confidence);
  return `${percent}% confidence`;
}

interface ReviewCardProps {
  item: ReviewItem;
  saving: boolean;
  onApprove: (item: ReviewItem) => Promise<void>;
  onReject: (item: ReviewItem) => Promise<void>;
  onUpdate: (item: ReviewItem, content: string) => Promise<void>;
  editingDisabled: boolean;
}

function ReviewCard({
  item,
  saving,
  onApprove,
  onReject,
  onUpdate,
  editingDisabled,
}: ReviewCardProps) {
  const [draft, setDraft] = useState(getItemText(item));
  const [isDirty, setIsDirty] = useState(false);
  const sourceTitle = item.source?.conversation_title || item.source?.app_name;
  const confidence = confidenceLabel(item.confidence);

  const handleDraftChange = (value: string) => {
    setDraft(value);
    setIsDirty(value.trim() !== getItemText(item).trim());
  };

  const handleSave = async () => {
    const nextContent = draft.trim();
    if (!nextContent || !isDirty) return;
    await onUpdate(item, nextContent);
    setIsDirty(false);
  };

  const handleApprove = async () => {
    if (isDirty && !editingDisabled) {
      await handleSave();
    }
    await onApprove(item);
  };

  return (
    <article className="rounded-lg border border-white/[0.06] bg-bg-secondary/80 p-4 shadow-sm">
      <div className="flex flex-col gap-4">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <span
                className={cn(
                  'inline-flex h-7 w-7 items-center justify-center rounded-lg',
                  item.type === 'memory'
                    ? 'bg-purple-primary/15 text-purple-primary'
                    : 'bg-info/15 text-info'
                )}
              >
                {item.type === 'memory' ? (
                  <Brain className="h-4 w-4" />
                ) : (
                  <CircleCheck className="h-4 w-4" />
                )}
              </span>
              <h2 className="truncate text-base font-semibold text-text-primary">
                {getItemTitle(item)}
              </h2>
              <span className="rounded-md border border-white/[0.06] bg-bg-tertiary px-2 py-1 text-xs text-text-tertiary">
                {item.type === 'memory' ? 'Memory' : 'Action'}
              </span>
            </div>

            <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-text-quaternary">
              <span>{formatDate(item.created_at)}</span>
              {item.due_at && (
                <span className="inline-flex items-center gap-1">
                  <CalendarClock className="h-3.5 w-3.5" />
                  Due {formatDate(item.due_at)}
                </span>
              )}
              {sourceTitle && <span className="truncate">From {sourceTitle}</span>}
              {confidence && <span>{confidence}</span>}
            </div>
          </div>
        </div>

        <textarea
          value={draft}
          onChange={(event) => handleDraftChange(event.target.value)}
          disabled={saving || editingDisabled}
          rows={4}
          className={cn(
            'w-full resize-none rounded-lg border border-white/[0.06] bg-bg-primary px-3 py-3',
            'text-sm leading-6 text-text-secondary outline-none transition-colors',
            'focus:border-purple-primary/60 disabled:cursor-not-allowed disabled:opacity-70'
          )}
        />

        {item.tags && item.tags.length > 0 && (
          <div className="flex flex-wrap items-center gap-2">
            {item.tags.slice(0, 6).map((tag) => (
              <span
                key={tag}
                className="inline-flex items-center gap-1 rounded-md bg-bg-tertiary px-2 py-1 text-xs text-text-tertiary"
              >
                <Tag className="h-3 w-3" />
                {tag}
              </span>
            ))}
          </div>
        )}

        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="text-xs text-text-quaternary">
            {editingDisabled
              ? 'Editing will enable when the unified review route is available.'
              : isDirty
                ? 'Unsaved edit'
                : 'Ready for review'}
          </div>

          <div className="flex items-center gap-2">
            {isDirty && !editingDisabled && (
              <button
                type="button"
                onClick={handleSave}
                disabled={saving || !draft.trim()}
                className="inline-flex items-center gap-2 rounded-lg border border-white/[0.08] px-3 py-2 text-sm font-medium text-text-secondary transition-colors hover:bg-bg-tertiary disabled:cursor-not-allowed disabled:opacity-50"
              >
                {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
                Save
              </button>
            )}
            <button
              type="button"
              onClick={() => onReject(item)}
              disabled={saving}
              className="inline-flex items-center gap-2 rounded-lg border border-error/30 px-3 py-2 text-sm font-medium text-error transition-colors hover:bg-error/10 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <X className="h-4 w-4" />}
              Reject
            </button>
            <button
              type="button"
              onClick={handleApprove}
              disabled={saving || !draft.trim()}
              className="inline-flex items-center gap-2 rounded-lg bg-success px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-success/90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
              Approve
            </button>
          </div>
        </div>
      </div>
    </article>
  );
}

function ReviewSkeleton() {
  return (
    <div className="space-y-3">
      {[0, 1, 2].map((item) => (
        <div key={item} className="rounded-lg border border-white/[0.06] bg-bg-secondary p-4">
          <div className="skeleton h-5 w-1/3 rounded" />
          <div className="skeleton mt-4 h-24 rounded-lg" />
          <div className="mt-4 flex justify-end gap-2">
            <div className="skeleton h-9 w-20 rounded-lg" />
            <div className="skeleton h-9 w-24 rounded-lg" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function ReviewInbox() {
  const [searchQuery, setSearchQuery] = useState('');
  const {
    items,
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
  } = useReviewInbox();

  const filteredItems = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    if (!query) return items;

    return items.filter((item) => {
      const text = `${getItemTitle(item)} ${getItemText(item)} ${item.tags?.join(' ') || ''}`;
      return text.toLowerCase().includes(query);
    });
  }, [items, searchQuery]);

  const emptyMessage = searchQuery
    ? 'No review candidates match this search.'
    : 'No pending candidates need review.';

  const handleUpdate = async (item: ReviewItem, content: string) => {
    await updateItem(item, {
      content,
      proposed_content: content,
    });
  };

  return (
    <div className="flex h-full min-h-0 flex-col bg-bg-primary">
      <PageHeader title="Review" icon={Inbox} />

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto flex w-full max-w-6xl flex-col gap-5 px-4 py-5 sm:px-6 lg:px-8">
          <section className="grid gap-3 sm:grid-cols-3">
            <div className="rounded-lg border border-white/[0.06] bg-bg-secondary p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-text-tertiary">Pending</span>
                <Inbox className="h-4 w-4 text-text-quaternary" />
              </div>
              <p className="mt-2 text-2xl font-semibold text-text-primary">{summary.pending}</p>
            </div>
            <div className="rounded-lg border border-white/[0.06] bg-bg-secondary p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-text-tertiary">Memories</span>
                <Brain className="h-4 w-4 text-purple-primary" />
              </div>
              <p className="mt-2 text-2xl font-semibold text-text-primary">{summary.memories}</p>
            </div>
            <div className="rounded-lg border border-white/[0.06] bg-bg-secondary p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-text-tertiary">Actions</span>
                <CircleCheck className="h-4 w-4 text-info" />
              </div>
              <p className="mt-2 text-2xl font-semibold text-text-primary">{summary.actions}</p>
            </div>
          </section>

          {backendMode === 'memory-fallback' && (
            <div className="flex items-start gap-3 rounded-lg border border-warning/25 bg-warning/10 px-4 py-3 text-sm text-warning">
              <AlertCircle className="mt-0.5 h-4 w-4 flex-shrink-0" />
              <p>
                Unified review endpoints are not available yet. This page is showing unreviewed
                memory candidates only.
              </p>
            </div>
          )}

          {error && (
            <div className="flex items-start gap-3 rounded-lg border border-error/25 bg-error/10 px-4 py-3 text-sm text-error">
              <AlertCircle className="mt-0.5 h-4 w-4 flex-shrink-0" />
              <p>{error}</p>
            </div>
          )}

          <div className="flex flex-col gap-3 rounded-lg border border-white/[0.06] bg-bg-secondary p-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex rounded-lg bg-bg-primary p-1">
              {FILTERS.map((filter) => (
                <button
                  key={filter.value}
                  type="button"
                  onClick={() => setTypeFilter(filter.value)}
                  className={cn(
                    'rounded-md px-3 py-2 text-sm font-medium transition-colors',
                    typeFilter === filter.value
                      ? 'bg-bg-tertiary text-text-primary'
                      : 'text-text-tertiary hover:text-text-primary'
                  )}
                >
                  {filter.label}
                </button>
              ))}
            </div>

            <div className="flex flex-1 items-center gap-2 sm:max-w-md">
              <label className="relative flex-1">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-quaternary" />
                <input
                  value={searchQuery}
                  onChange={(event) => setSearchQuery(event.target.value)}
                  placeholder="Search review candidates"
                  className="h-10 w-full rounded-lg border border-white/[0.06] bg-bg-primary pl-9 pr-3 text-sm text-text-primary outline-none transition-colors placeholder:text-text-quaternary focus:border-purple-primary/60"
                />
              </label>
              <button
                type="button"
                onClick={refresh}
                disabled={loading}
                title="Refresh"
                className="inline-flex h-10 w-10 items-center justify-center rounded-lg border border-white/[0.08] text-text-secondary transition-colors hover:bg-bg-tertiary disabled:cursor-not-allowed disabled:opacity-50"
              >
                <RefreshCw className={cn('h-4 w-4', loading && 'animate-spin')} />
              </button>
            </div>
          </div>

          {loading ? (
            <ReviewSkeleton />
          ) : filteredItems.length > 0 ? (
            <div className="space-y-3">
              {filteredItems.map((item) => (
                <ReviewCard
                  key={item.id}
                  item={item}
                  saving={savingId === item.id}
                  onApprove={approve}
                  onReject={reject}
                  onUpdate={handleUpdate}
                  editingDisabled={backendMode !== 'review-api'}
                />
              ))}
            </div>
          ) : (
            <div className="flex min-h-[320px] flex-col items-center justify-center rounded-lg border border-dashed border-white/[0.08] bg-bg-secondary/60 px-6 text-center">
              <Sparkles className="h-8 w-8 text-text-quaternary" />
              <h2 className="mt-4 text-lg font-semibold text-text-primary">{emptyMessage}</h2>
              <p className="mt-2 max-w-md text-sm leading-6 text-text-tertiary">
                New extracted memories and task suggestions will appear here before they are added
                to the main workspace.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
