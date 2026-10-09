# Example PR body

A body for a branch that moved the orders endpoint from offset to cursor pagination. It passes `pr-preflight.sh --lint` in a repo with no PR template. Title: `feat(api): add cursor pagination to the orders endpoint`.

```markdown
## Summary

Replaces offset paging on `GET /orders` with an opaque cursor so large accounts stop timing out on deep pages, while keeping `page=` working for one release.

## Changes

- `listOrders` accepts `after` and returns `next_cursor`; the cursor encodes the partition key and created-at
- `page=` requests are served by the old path and answered with a `Deprecation` header
- `OrdersPage` in the dashboard reads `next_cursor` instead of counting pages
- Page size is capped at 200 in `orderQuerySchema`

## Impact

Clients that compute total page counts from `X-Total-Count` lose that header on cursor requests; the dashboard no longer uses it, and the two external integrations were notified in #4871.

## Testing

- [ ] `pnpm test apps/api/orders` — covers cursor round-trips and the partition boundary
- [ ] Load `/orders?after=<cursor>` on the staging account with 400k orders and confirm p95 under 300 ms in Grafana
- [ ] Request `/orders?page=3` and confirm the `Deprecation` header and unchanged payload
```

## Why it lints clean

- Every required section is present and spelled as a whole line: `## Summary`, `## Changes`, `## Testing`.
- No bracketed placeholders remain; each testing item names a real command, path, or observable.
- Nothing describes who or what wrote it; the body ends on its last section of content.
- `## Impact` is included only because the header removal is something a reviewer must weigh; a PR without such a consequence omits the section.
- Every bullet names its subject and states a fact in one tense; none opens with an -ing word, hedges (should, may), or a vague verb (improve, clean up). The lint warns on those rather than failing, since each has a rare legitimate use.
