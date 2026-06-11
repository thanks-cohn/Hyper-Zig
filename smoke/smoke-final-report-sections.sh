#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/final-report.sh
source "$ROOT/scripts/lib/final-report.sh"

FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT
RUN_DIR="$FIXTURE_ROOT/logs/validation/run-001"
START_EPOCH="$(($(date -u +%s) - 1))"
mkdir -p "$RUN_DIR" "$FIXTURE_ROOT/logs/latest" "$FIXTURE_ROOT/smoke/transcripts" "$FIXTURE_ROOT/zig-out/bin"

printf 'command output\n' > "$RUN_DIR/build.log"
printf 'summary placeholder\n' > "$RUN_DIR/minimus-log-summary.txt"
printf 'latest build\n' > "$FIXTURE_ROOT/logs/latest/build.log"
printf 'transcript\n' > "$FIXTURE_ROOT/smoke/transcripts/latest-final-report.txt"
printf 'elf\n' > "$FIXTURE_ROOT/zig-out/bin/zign01d-v0"
ln -sfn "$RUN_DIR/minimus-log-summary.txt" "$FIXTURE_ROOT/logs/latest/validate-hyperzig-minimus-log-summary.txt"

REPORT="$RUN_DIR/final-report.txt"
{
    printf 'raw validation body\n'
    hyperzig_print_link_for_everything "$FIXTURE_ROOT" "$RUN_DIR" "$START_EPOCH"
    cat <<'SUMMARY'
MINIMUS LOG
===========
Repository: Hyper-Zig
Branch: smoke-fixture
Commit: smoke-fixture
Toolchain: smoke-fixture
Build status: PASS
Test status: PASS
What passed: final report section smoke checks
What failed: none
What changed: fixture artifacts only
What was proven: final report ordering and artifact links
What was not proven: full repository validation
Current milestone: final-report-smoke
Next milestone: keep reports discoverable
One-sentence summary: Final reports end with artifact navigation before the Minimus Log.
SUMMARY
} > "$REPORT"

python3 - "$REPORT" "$FIXTURE_ROOT" "$RUN_DIR" "$START_EPOCH" "$ROOT" <<'PY'
import os
import subprocess
import sys
from pathlib import Path

report = Path(sys.argv[1])
fixture_root = sys.argv[2]
run_dir = sys.argv[3]
start_epoch = sys.argv[4]
repo_root = Path(sys.argv[5])
text = report.read_text()

link = "A LINK FOR EVERYTHING"
minimus = "MINIMUS LOG"
assert link in text, "A LINK FOR EVERYTHING missing"
assert minimus in text, "MINIMUS LOG missing"
assert text.index(link) < text.index(minimus), "A LINK FOR EVERYTHING must appear before MINIMUS LOG"
assert text.rstrip().endswith("Final reports end with artifact navigation before the Minimus Log."), "MINIMUS LOG must be the final major section"

link_body = text.split(link, 1)[1].split(minimus, 1)[0]
lines = link_body.splitlines()
addresses = []
for idx, line in enumerate(lines):
    if line == "Full Address:":
        assert idx + 1 < len(lines), "Full Address must be followed by an address"
        address = lines[idx + 1]
        assert os.path.isabs(address), f"address is not absolute: {address}"
        assert os.path.exists(address), f"listed artifact does not exist: {address}"
        addresses.append(address)
assert addresses, "no artifact addresses found"

cmd = (
    f"source {repo_root / 'scripts/lib/final-report.sh'}; "
    f"hyperzig_collect_artifacts {fixture_root!r} {run_dir!r} {start_epoch!r}"
)
expected = subprocess.check_output(["bash", "-lc", cmd], text=True).splitlines()
missing = sorted(set(expected) - set(addresses))
extra = sorted(set(addresses) - set(expected))
assert not missing, "produced artifacts omitted: " + ", ".join(missing)
assert not extra, "unexpected artifacts listed: " + ", ".join(extra)
PY

printf 'PASS final report sections\n'
