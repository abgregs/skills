# Worked example: team-membership notifications

User invokes `/sweep` after stating: *"Add in-app notification + email when an admin removes a user from a team."*

## Rendered plan

```
## /sweep results for: "Add in-app notification + email when an admin removes a user from a team"

### Inferred domain
Team-membership state-change notifications — in-app + email, sent to the affected user or the relevant party when team membership changes.

### Pattern audit
- Canonical pattern: TeamInviteEmail template + createNotification + NotificationItemRow case-handler. Refs: `src/components/emails/TeamInviteEmail.tsx`, `src/app/_actions/team-actions.ts → inviteMemberImpl`, `src/components/notifications/NotificationItemRow.tsx` (team_join branch).
- Drift observed: none.
- Recommendation: conform to the TeamInviteEmail visual structure, the createNotification + team-context-via-FK pattern, and the per-type message-handler branch in NotificationItemRow.

### Original task
Owner removes a member from a team → send in-app notification + email to the removed user.

### Obvious siblings (recommended to bundle)
- [ ] Member voluntarily leaves team → notify team owner + send email. Mirror of the remove flow with recipient/actor inverted. ~100% reuse of email template + notification wiring shape.

### Borderline siblings (your call)
- [ ] Member role changed (member ↔ admin) → notify the affected user + send email. Workflow shape identical; UX intent slightly different (informational vs. consequential). Reuse: ~80%.
- [ ] Team ownership transferred → notify all admins + send emails. Multi-recipient; workflow diverges slightly because the fanout differs. Reuse: ~60%.

### Optional follow-ups
- None.

### Ask
Confirm which obvious and borderline items to include. After approval I'll hand off the expanded scope for execution (optionally via /brief for doc-aligned planning).
```

## What happens next

The user might accept the obvious sibling, accept the role-change borderline, and defer the ownership-transfer borderline as a separate later task. The agent then proceeds with the expanded scope.

## Why this example holds

- Every sibling shares the original task's shape (an email template plus a notification row keyed on a membership event); nothing cross-domain (analytics, audit logs) appears, even as a follow-up.
- Reuse percentages make the obvious/borderline split checkable rather than a feeling.
- The ownership-transfer item is borderline because its fan-out diverges, which is exactly the workflow-divergence stopping point the guardrails describe.
