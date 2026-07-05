# Review Inbox API Contract

The web review inbox is prepared for a unified authenticated review API under the existing
`/api/proxy` path.

## List Pending Candidates

`GET /v1/review/inbox?status=pending&type=all&limit=100&offset=0`

Response:

```json
{
  "items": [
    {
      "id": "review-item-id",
      "type": "memory",
      "status": "pending",
      "title": "Optional short label",
      "content": "Original extracted text",
      "proposed_content": "Editable proposed text",
      "created_at": "2026-06-28T12:00:00Z",
      "updated_at": "2026-06-28T12:00:00Z",
      "due_at": null,
      "confidence": 0.82,
      "tags": ["project"],
      "source": {
        "conversation_id": "conversation-id",
        "conversation_title": "Optional source title",
        "app_id": "optional-app-id",
        "app_name": "Optional app name"
      }
    }
  ],
  "summary": {
    "pending": 1,
    "memories": 1,
    "actions": 0,
    "approved_today": 0,
    "rejected_today": 0
  },
  "has_more": false
}
```

The frontend also accepts compatibility aliases `review_items` or `candidates` for `items`,
`totals` for `summary`, and `hasMore` for `has_more`.

## Review Candidate

`PATCH /v1/review/items/{id}`

Approve or reject:

```json
{ "status": "approved" }
```

Editable draft update:

```json
{
  "content": "Updated text",
  "proposed_content": "Updated text",
  "due_at": "2026-06-29T16:00:00Z",
  "tags": ["project"]
}
```

Expected behavior:

- Approving a `memory` candidate creates or marks the memory accepted.
- Approving an `action` candidate creates or marks the action item accepted.
- Rejecting either type records the rejection and removes it from the pending inbox.
- The route should return the updated `ReviewItem` for draft edits.

## Current Fallback

If `GET /v1/review/inbox` returns 404, the web page falls back to `/v3/memories` and displays
unreviewed memories only. In fallback mode, memory approve/reject uses
`POST /v3/memories/{id}/review?value=true|false`; action candidates and draft editing require the
unified `/v1/review/*` routes.
