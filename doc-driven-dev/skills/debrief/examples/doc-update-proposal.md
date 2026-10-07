# Example: a Step 3 doc-update proposal

The task changed how timestamps move through the app: they are now stored and passed in UTC and converted to local time only when displayed. The existing convention said the opposite, so this is a **Replacement**, and the **Why:** line is mandatory.

```
**Updates needed:**

Update `docs/conventions/dates-and-times.md`:
- Replace "store and pass timestamps in the user's local time" with "store and pass timestamps in UTC; convert to local time only at the display boundary"
  **Why:** removes timezone math from every internal layer and stops DST-driven off-by-one bugs at integration points
- Remove the example showing a Date object passed straight from the form into storage

Update `docs/conventions/_index.md`:
- Update the dates-and-times summary to reflect the UTC boundary rule
```

## What the example shows

- The replacement names both the old wording and the new, so the user can see exactly what flips.
- The **Why:** records what the old rule cost. A future agent meeting local-time code in a half-migrated file reads this and keeps moving toward UTC instead of "fixing" back.
- The stale in-doc example is removed in the same proposal; a convention whose example contradicts it is worse than no example.
- The `_index.md` summary is updated alongside, because summaries are how `/brief` triages relevance without opening every file.
