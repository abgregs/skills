#!/usr/bin/env python3
"""Audit which models subagents ACTUALLY used, vs the model-routing rubric.

Reads Claude Code's own transcripts (deterministic ground truth — no logging
required in the skill). For each subagent run it reports the serving model
(`message.model` in the subagent transcript) alongside the spawn's description
and agent type (`.meta.json`), then flags likely rubric violations:

  * FABLE-SUBAGENT  — a subagent served by Fable (planner delegation aside,
                      subagents should almost never run on Fable)
  * OPUS-TRIVIAL    — Opus serving a task whose description looks mechanical
                      (heuristic keyword match — a flag to eyeball, not a verdict)

Usage:  python3 audit.py [--days N] [--project SUBSTRING]
        --days     lookback window (default 7): subagent runs by transcript
                   mtime; requested/skill counts by each line's timestamp
                   (a session spanning the cutoff doesn't leak older calls)
        --project  only project dirs whose slug contains SUBSTRING (default all)
"""
import argparse, json, re, sys, time
from datetime import datetime
from pathlib import Path

TRIVIAL = re.compile(
    r"\b(list|count|find|read|check|grep|glob|locate|fetch|scan|map|look ?up|"
    r"inventory|enumerate|extract|parse|search)\b", re.I)

# Built by concatenation so this file never contains the literal marker —
# otherwise reading this script into a session makes its transcript match.
_C = "command-" + "name"
CMD_NEEDLES = tuple(f"<{_C}>{p}model-routing</{_C}>" for p in ("/", ""))

def tier(model: str) -> str:
    m = (model or "").lower()
    for k in ("fable", "opus", "sonnet", "haiku"):
        if k in m:
            return k
    return m or "(unknown)"

def line_epoch(d: dict):  # -> Optional[float]; ISO "…Z" timestamp → epoch seconds
    ts = d.get("timestamp")
    if not isinstance(ts, str):
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None

def first_model(jsonl: Path):  # -> Optional[str]; bare for py3.9 compat
    try:
        with jsonl.open() as f:
            for line in f:
                if '"assistant"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                m = (d.get("message") or {}).get("model")
                if m:
                    return m
    except OSError:
        pass
    return None

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=float, default=7)
    ap.add_argument("--project", default="")
    args = ap.parse_args()
    cutoff = time.time() - args.days * 86400

    root = Path.home() / ".claude" / "projects"
    rows, req_explicit, req_inherit, skill_fired = [], {}, 0, 0

    for proj in sorted(root.iterdir()):
        if not proj.is_dir() or args.project not in proj.name:
            continue
        # Actual serving models: subagent transcripts
        for sub in proj.glob("*/subagents/agent-*.jsonl"):
            if sub.stat().st_mtime < cutoff:
                continue
            meta = {}
            mp = sub.with_suffix("").with_suffix(".meta.json")  # agent-X.meta.json
            if not mp.exists():
                mp = sub.parent / (sub.stem + ".meta.json")
            if mp.exists():
                try:
                    meta = json.loads(mp.read_text())
                except (OSError, json.JSONDecodeError):
                    pass
            model = first_model(sub)
            if model:
                rows.append({
                    "model": model, "tier": tier(model),
                    "type": meta.get("agentType", "?"),
                    "desc": meta.get("description", "?"),
                    "proj": proj.name.rsplit("-", 2)[-1],
                })
        # Requested models: Agent tool_use in main transcripts. File mtime is
        # only a cheap pre-filter — sessions spanning the cutoff carry older
        # calls, so each counted line is windowed by its own timestamp.
        for tl in proj.glob("*.jsonl"):
            if tl.stat().st_mtime < cutoff:
                continue
            try:
                with tl.open() as f:
                    for line in f:
                        # User-typed /model-routing arrives as a command expansion,
                        # not a Skill tool call — count it directly. Full tag +
                        # user-role required: assistant tool calls that merely
                        # quote the marker (e.g. audit tooling) must not count.
                        is_cmd = any(n in line for n in CMD_NEEDLES)
                        is_agent = '"name":"Agent"' in line
                        is_skill = '"name":"Skill"' in line and "model-routing" in line
                        if not (is_cmd or is_agent or is_skill):
                            continue
                        try:
                            d = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        ts = line_epoch(d)
                        if ts is not None and ts < cutoff:
                            continue
                        if is_cmd:
                            if d.get("type") == "user":
                                skill_fired += 1
                            continue
                        for b in ((d.get("message") or {}).get("content") or []):
                            if not isinstance(b, dict):
                                continue
                            if b.get("name") == "Agent":
                                m = (b.get("input") or {}).get("model")
                                if m:
                                    req_explicit[m] = req_explicit.get(m, 0) + 1
                                else:
                                    req_inherit += 1
                            elif (b.get("name") == "Skill"
                                  and (b.get("input") or {}).get("skill") == "model-routing"):
                                skill_fired += 1
            except OSError:
                continue

    print(f"# Subagent model audit — last {args.days:g} days"
          f"{', project ~' + args.project if args.project else ''}\n")
    if not rows:
        print("No subagent runs found in window.")
        return

    hist: dict[str, int] = {}
    for r in rows:
        hist[r["tier"]] = hist.get(r["tier"], 0) + 1
    print("## Actual serving model (ground truth)")
    for t in ("haiku", "sonnet", "opus", "fable"):
        if t in hist:
            print(f"  {t:<7} {hist[t]:>4}  ({100*hist[t]//len(rows)}%)")
    for t, n in hist.items():
        if t not in ("haiku", "sonnet", "opus", "fable"):
            print(f"  {t:<7} {n:>4}")
    print(f"  total   {len(rows):>4}")

    print("\n## Routing decisions (explicit `model` param = a decision was made)")
    print(f"  explicit: {req_explicit or '(none)'}   unconsidered/inherit: {req_inherit}")
    print(f"  model-routing skill invocations in window: {skill_fired}")

    flags = []
    for r in rows:
        if r["tier"] == "fable":
            flags.append(("FABLE-SUBAGENT", r))
        elif r["tier"] == "opus" and TRIVIAL.search(r["desc"] or ""):
            flags.append(("OPUS-TRIVIAL?", r))
    print(f"\n## Red flags ({len(flags)})")
    for tag, r in flags[:25]:
        print(f"  [{tag}] {r['type']:<10} {r['desc'][:70]}  ({r['model']})")
    if not flags:
        print("  none — routing looks healthy")

if __name__ == "__main__":
    main()
