#!/bin/bash
# Build the case 0005 probe fixtures: 0005-fixtures.sh <out dir>
# Fourteen tiny Python repos, each with a two-commit conventional history and
# one dirty change. Expected answers are in 0005.md. Uses BSD (macOS) sed -i.
mkdir -p "${1:?usage: 0005-fixtures.sh <out dir>}" && OUT="$(cd "$1" && pwd)"
new() { # name
  D="$OUT/$1"; mkdir -p "$D/src" "$D/tests"; cd "$D" || exit 1; git init -q
  printf '# %s\n\nA small utility module.\n' "$1" > README.md
}
c() { git add -A && git commit -q -m "$1"; }

# P1 obvious fix: the last page is missing.
new P1
cat > src/pager.py <<'EOF'
def page_numbers(total_items, per_page):
    pages = (total_items + per_page - 1) // per_page
    return list(range(1, pages))
EOF
c 'feat(pager): add page_numbers'
cat > tests/test_pager.py <<'EOF'
from src.pager import page_numbers


def test_single_page():
    assert page_numbers(5, 10) == [1]
EOF
c 'test(pager): cover a single page'
cat > src/pager.py <<'EOF'
def page_numbers(total_items, per_page):
    pages = (total_items + per_page - 1) // per_page
    return list(range(1, pages + 1))
EOF
cat >> tests/test_pager.py <<'EOF'


def test_partial_last_page():
    assert page_numbers(25, 10) == [1, 2, 3]
EOF

# P2 fix with a hidden cause: id() values are reused after an object is freed.
new P2
cat > src/profile_cache.py <<'EOF'
_cache = {}


def cached_profile(user, load):
    key = id(user)
    if key not in _cache:
        _cache[key] = load(user)
    return _cache[key]
EOF
c 'feat(cache): cache loaded profiles per user'
cat > tests/test_profile_cache.py <<'EOF'
from src.profile_cache import cached_profile


class User:
    def __init__(self, pk):
        self.pk = pk


def test_same_user_hits_cache():
    calls = []
    u = User(1)
    cached_profile(u, lambda x: calls.append(x) or x.pk)
    cached_profile(u, lambda x: calls.append(x) or x.pk)
    assert len(calls) == 1
EOF
c 'test(cache): cover a repeat lookup'
cat > src/profile_cache.py <<'EOF'
_cache = {}


def cached_profile(user, load):
    key = user.pk
    if key not in _cache:
        _cache[key] = load(user)
    return _cache[key]
EOF
cat >> tests/test_profile_cache.py <<'EOF'


def test_freed_user_does_not_leak_into_next():
    """CPython reuses an id() once its object is freed, so a new user could
    receive the profile cached for a user that no longer exists."""
    cached_profile(User(2), lambda x: "profile-2")
    assert cached_profile(User(3), lambda x: "profile-3") == "profile-3"
EOF

# P3 self-explanatory feature: a --version flag.
new P3
cat > src/cli.py <<'EOF'
import argparse

__version__ = "1.4.0"


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tally")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args(argv)
    for path in args.paths:
        print(path)
EOF
c 'feat(cli): add the tally entry point'
cat > tests/test_cli.py <<'EOF'
from src.cli import main


def test_prints_paths(capsys):
    main(["a.txt"])
    assert capsys.readouterr().out == "a.txt\n"
EOF
c 'test(cli): cover path printing'
cat > src/cli.py <<'EOF'
import argparse

__version__ = "1.4.0"


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tally")
    parser.add_argument("--version", action="version", version=f"tally {__version__}")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args(argv)
    for path in args.paths:
        print(path)
EOF
cat >> tests/test_cli.py <<'EOF'


def test_version(capsys):
    import pytest
    with pytest.raises(SystemExit):
        main(["--version"])
    assert capsys.readouterr().out == "tally 1.4.0\n"
EOF

# P4 feature whose need is not visible: a UTF-8 BOM so Excel reads accents.
new P4
cat > src/export.py <<'EOF'
import csv


def export_contacts(path, contacts):
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["name", "email"])
        for c in contacts:
            writer.writerow([c["name"], c["email"]])
EOF
c 'feat(export): export contacts as CSV'
cat > tests/test_export.py <<'EOF'
from src.export import export_contacts


def test_header(tmp_path):
    p = tmp_path / "c.csv"
    export_contacts(p, [])
    assert p.read_text(encoding="utf-8-sig").startswith("name,email")
EOF
c 'test(export): cover the CSV header'
cat > src/export.py <<'EOF'
import csv


def export_contacts(path, contacts):
    # Excel reads UTF-8 without a BOM as the ANSI code page, so names such
    # as "Zoë" and "José" opened garbled.
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["name", "email"])
        for c in contacts:
            writer.writerow([c["name"], c["email"]])
EOF
cat >> tests/test_export.py <<'EOF'


def test_starts_with_bom(tmp_path):
    p = tmp_path / "c.csv"
    export_contacts(p, [])
    assert p.read_bytes().startswith(b"\xef\xbb\xbf")
EOF

# P5 pure refactor: one email check shared by two callers.
new P5
cat > src/users.py <<'EOF'
import re


def signup(email, password):
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise ValueError("invalid email")
    return {"email": email, "password": password}


def invite(email, team):
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise ValueError("invalid email")
    return {"email": email, "team": team}
EOF
c 'feat(users): add signup and invite'
cat > tests/test_users.py <<'EOF'
import pytest
from src.users import invite, signup


def test_rejects_bad_email():
    with pytest.raises(ValueError):
        signup("nope", "pw")
    with pytest.raises(ValueError):
        invite("nope", "core")
EOF
c 'test(users): cover email rejection'
cat > src/users.py <<'EOF'
import re

_EMAIL = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")


def _check_email(email):
    if not _EMAIL.fullmatch(email):
        raise ValueError("invalid email")


def signup(email, password):
    _check_email(email)
    return {"email": email, "password": password}


def invite(email, team):
    _check_email(email)
    return {"email": email, "team": team}
EOF

# P6 perf change with a measured figure.
new P6
cat > src/tokenize.py <<'EOF'
from .stopwords import STOPWORDS


def tokens(text):
    return [w for w in text.lower().split() if w not in STOPWORDS]
EOF
printf 'STOPWORDS = [%s]\n' '"a", "an", "the", "of", "to"' > src/stopwords.py
c 'feat(tokenize): drop stopwords from tokens'
cat > tests/test_tokenize.py <<'EOF'
from src.tokenize import tokens


def test_drops_stopwords():
    assert tokens("The end of a story") == ["end", "story"]
EOF
c 'test(tokenize): cover stopword removal'
cat > src/tokenize.py <<'EOF'
from .stopwords import STOPWORDS

# A frozenset: with the full 12k-word list, list membership took 38% of
# tokens() time on a 2 MB corpus.
_STOP = frozenset(STOPWORDS)


def tokens(text):
    return [w for w in text.lower().split() if w not in _STOP]
EOF

# ---- Held-out fixtures: the wording was not tuned on these.

# H1 rename with its call sites: one commit, no Why.
new H1
cat > src/geo.py <<'EOF'
def dist(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5
EOF
cat > src/route.py <<'EOF'
from .geo import dist


def length(points):
    return sum(dist(a, b) for a, b in zip(points, points[1:]))
EOF
cat > src/report.py <<'EOF'
from .geo import dist


def farthest(origin, points):
    return max(points, key=lambda p: dist(origin, p))
EOF
c 'feat(geo): add route length and farthest point'
printf 'from src.route import length\n\n\ndef test_length():\n    assert length([(0, 0), (3, 4)]) == 5\n' > tests/test_route.py
c 'test(route): cover route length'
sed -i '' 's/def dist(/def distance(/' src/geo.py
sed -i '' 's/import dist$/import distance/; s/dist(a, b)/distance(a, b)/; s/dist(origin, p)/distance(origin, p)/' src/route.py src/report.py

# H2 a refactor that makes room for a feature: two commits, refactor first.
new H2
cat > src/report.py <<'EOF'
def render_text(orders):
    lines = []
    for o in orders:
        total = o["qty"] * o["price"]
        lines.append(f'{o["sku"]}  {o["qty"]} x {o["price"]:.2f} = {total:.2f}')
    return "\n".join(lines)
EOF
c 'feat(report): render orders as text'
printf 'from src.report import render_text\n\n\ndef test_text():\n    assert render_text([{"sku": "A", "qty": 2, "price": 1.5}]) == "A  2 x 1.50 = 3.00"\n' > tests/test_report.py
c 'test(report): cover text rendering'
cat > src/report.py <<'EOF'
def rows(orders):
    for o in orders:
        yield o["sku"], o["qty"], o["price"], o["qty"] * o["price"]


def render_text(orders):
    return "\n".join(f"{s}  {q} x {p:.2f} = {t:.2f}" for s, q, p, t in rows(orders))
EOF
cat > src/report_csv.py <<'EOF'
import csv
import io

from .report import rows


def render_csv(orders):
    out = io.StringIO()
    w = csv.writer(out)
    w.writerow(["sku", "qty", "price", "total"])
    w.writerows(rows(orders))
    return out.getvalue()
EOF
printf 'from src.report_csv import render_csv\n\n\ndef test_csv():\n    assert render_csv([{"sku": "A", "qty": 2, "price": 1.5}]).splitlines()[1] == "A,2,1.5,3.0"\n' > tests/test_report_csv.py
git add -N src/report_csv.py tests/test_report_csv.py

# H3 fix whose cause is outside the code: Why.
new H3
cat > src/billing_client.py <<'EOF'
import urllib.request

TIMEOUT_SECONDS = 5


def fetch_invoice(url):
    with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as r:
        return r.read()
EOF
c 'feat(billing): fetch invoices from the billing API'
printf 'from src import billing_client\n\n\ndef test_timeout_is_set():\n    assert billing_client.TIMEOUT_SECONDS > 0\n' > tests/test_billing_client.py
c 'test(billing): check the timeout is set'
cat > src/billing_client.py <<'EOF'
import urllib.request

# The billing API's p99 latency reaches 9 s during month-end invoice runs.
TIMEOUT_SECONDS = 15


def fetch_invoice(url):
    with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as r:
        return r.read()
EOF

# H4 fix whose subject says it all: no Why.
new H4
cat > src/names.py <<'EOF'
def display_name(user):
    return user["first"] + " " + user["last"]
EOF
c 'feat(names): add display_name'
printf 'from src.names import display_name\n\n\ndef test_full():\n    assert display_name({"first": "Ada", "last": "Lovelace"}) == "Ada Lovelace"\n' > tests/test_names.py
c 'test(names): cover a full name'
cat > src/names.py <<'EOF'
def display_name(user):
    return " ".join(p for p in (user["first"], user.get("last")) if p)
EOF
cat >> tests/test_names.py <<'EOF'


def test_no_last_name():
    assert display_name({"first": "Cher"}) == "Cher"
EOF

# H5 dependency bump with the code that adapts to it: one commit.
new H5
printf 'httpx==0.27.0\n' > requirements.txt
cat > src/fetch.py <<'EOF'
import httpx


def get_page(url):
    return httpx.get(url, allow_redirects=True).text
EOF
c 'feat(fetch): fetch pages over HTTP'
printf 'from src import fetch\n\n\ndef test_has_get_page():\n    assert callable(fetch.get_page)\n' > tests/test_fetch.py
c 'test(fetch): check get_page exists'
printf 'httpx==0.28.1\n' > requirements.txt
sed -i '' 's/allow_redirects=True/follow_redirects=True/' src/fetch.py

# H6 a fix and a feature from one theme, sharing only the changelog: fix and feat commits.
new H6
cat > src/export_csv.py <<'EOF'
import csv
import io


def to_csv(rows):
    out = io.StringIO()
    csv.writer(out).writerows(rows[:-1])
    return out.getvalue()
EOF
printf '# Changelog\n\n## Unreleased\n' > CHANGELOG.md
c 'feat(export): export rows as CSV'
printf 'from src.export_csv import to_csv\n\n\ndef test_header_only():\n    assert to_csv([["a"], ["b"]]).splitlines()[0] == "a"\n' > tests/test_export_csv.py
c 'test(export): cover the CSV header'
sed -i '' 's/writerows(rows\[:-1\])/writerows(rows)/' src/export_csv.py
printf '\n\ndef test_keeps_last_row():\n    assert to_csv([["a"], ["b"]]).splitlines() == ["a", "b"]\n' >> tests/test_export_csv.py
cat > src/export_tsv.py <<'EOF'
import csv
import io


def to_tsv(rows):
    out = io.StringIO()
    csv.writer(out, delimiter="\t").writerows(rows)
    return out.getvalue()
EOF
printf 'from src.export_tsv import to_tsv\n\n\ndef test_tabs():\n    assert to_tsv([["a", "b"]]) == "a\\tb\\r\\n"\n' > tests/test_export_tsv.py
printf '\n### Added\n\n- Export rows as TSV.\n\n### Fixed\n\n- CSV export keeps the last row.\n' >> CHANGELOG.md
git add -N src/export_tsv.py tests/test_export_tsv.py

# H7 two different fixes of one type, sharing only the changelog: two fix commits.
new H7
cat > src/duration.py <<'EOF'
def format_duration(seconds):
    minutes, secs = divmod(seconds, 60)
    return f"{int(minutes)}m {round(secs)}s"
EOF
cat > src/slug.py <<'EOF'
import re


def slugify(title):
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).lstrip("-")
EOF
printf '# Changelog\n\n## Unreleased\n' > CHANGELOG.md
c 'feat(text): add format_duration and slugify'
printf 'from src.duration import format_duration\n\n\ndef test_basic():\n    assert format_duration(61) == "1m 1s"\n' > tests/test_duration.py
printf 'from src.slug import slugify\n\n\ndef test_basic():\n    assert slugify("Hi there") == "hi-there"\n' > tests/test_slug.py
c 'test(text): cover duration and slug basics'
cat > src/duration.py <<'EOF'
def format_duration(seconds):
    minutes, secs = divmod(round(seconds), 60)
    return f"{minutes}m {secs}s"
EOF
sed -i '' 's/\.lstrip("-")/.strip("-")/' src/slug.py
printf '\n\ndef test_rounds_up_to_next_minute():\n    assert format_duration(119.6) == "2m 0s"\n' >> tests/test_duration.py
printf '\n\ndef test_no_trailing_hyphen():\n    assert slugify("Hello world!") == "hello-world"\n' >> tests/test_slug.py
printf '\n### Fixed\n\n- Durations just under a minute boundary no longer show 60s.\n- Slugs no longer end in a hyphen.\n' >> CHANGELOG.md

# H8 one fix that spans two scopes: one fix commit.
new H8
mkdir -p src/billing src/ui
cat > src/billing/price.py <<'EOF'
def order_total(items):
    return sum(i["unit_cents"] * i["qty"] for i in items) / 100
EOF
cat > src/ui/receipt.py <<'EOF'
from src.billing.price import order_total


def receipt_line(items):
    return f"Total: ${order_total(items) / 100:.2f}"
EOF
c 'feat(billing): show the order total on receipts'
printf 'from src.billing.price import order_total\n\n\ndef test_total():\n    assert order_total([{"unit_cents": 250, "qty": 2}])\n' > tests/test_price.py
c 'test(billing): cover order_total'
cat > src/billing/price.py <<'EOF'
def order_total_cents(items):
    return sum(i["unit_cents"] * i["qty"] for i in items)
EOF
cat > src/ui/receipt.py <<'EOF'
from src.billing.price import order_total_cents


def receipt_line(items):
    return f"Total: ${order_total_cents(items) / 100:.2f}"
EOF
cat > tests/test_price.py <<'EOF'
from src.billing.price import order_total_cents
from src.ui.receipt import receipt_line

ITEMS = [{"unit_cents": 600, "qty": 2}]


def test_total_in_cents():
    assert order_total_cents(ITEMS) == 1200


def test_receipt_shows_dollars():
    assert receipt_line(ITEMS) == "Total: $12.00"
EOF

for p in P1 P2 P3 P4 P5 P6 H1 H2 H3 H4 H5 H6 H7 H8; do echo "$p: $(git -C "$OUT/$p" diff --shortstat)"; done
