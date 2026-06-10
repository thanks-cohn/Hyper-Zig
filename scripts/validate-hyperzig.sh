#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
LOG_ROOT="$ROOT/logs/validation"
RUN_DIR="$LOG_ROOT/$STAMP"
SUMMARY_LOG="$RUN_DIR/minimus-log-summary.txt"
COMMAND_LOG="$RUN_DIR/validate-hyperzig.log"
mkdir -p "$RUN_DIR" "$ROOT/logs/latest"
: > "$COMMAND_LOG"
: > "$SUMMARY_LOG"
ln -sfn "$COMMAND_LOG" "$ROOT/logs/latest/validate-hyperzig.log"
ln -sfn "$SUMMARY_LOG" "$ROOT/logs/latest/validate-hyperzig-minimus-log-summary.txt"

# Mirror validator output into the per-run log without hiding command output.
exec > >(tee -a "$COMMAND_LOG") 2>&1

REQUIRED_SMOKES=(
    "smoke/smoke-hv-status-v0.sh"
    "smoke/smoke-hv-capability-v0.sh"
)
OPTIONAL_DECLARED_SMOKES=(
    "smoke/smoke-csr-v0.sh"
    "smoke/smoke-pmm-v0.sh"
    "smoke/smoke-heap-v0.sh"
    "smoke/smoke-all.sh"
    "smoke/smoke-stability.sh"
)

STATUS_NAMES=()
STATUS_VALUES=()
STATUS_CODES=()
SMOKE_NAMES=()
SMOKE_VALUES=()
SMOKE_LOGS=()
SMOKE_TRANSCRIPTS=()
MISSING_OPTIONAL=()
BLOCKERS=()
COMPLETED=()
MISSING_MILESTONES=()

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
section() { printf '\n[%s][HYPER-ZIG][VALIDATE] %s\n' "$(stamp)" "$*"; }
record_status() {
    STATUS_NAMES+=("$1")
    STATUS_VALUES+=("$2")
    STATUS_CODES+=("$3")
}
record_smoke() {
    SMOKE_NAMES+=("$1")
    SMOKE_VALUES+=("$2")
    SMOKE_LOGS+=("$3")
    SMOKE_TRANSCRIPTS+=("$4")
}
contains_path() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}
run_check() {
    local name="$1"; shift
    local safe_name="${name//[^A-Za-z0-9_.-]/_}"
    local out="$RUN_DIR/${safe_name}.log"
    section "RUN $name: $*"
    "$@" 2>&1 | tee "$out"
    local rc=${PIPESTATUS[0]}
    if [[ $rc -eq 0 ]]; then
        record_status "$name" "PASS" "$rc"
        COMPLETED+=("$name")
        section "PASS $name (log=$out)"
    else
        record_status "$name" "FAIL" "$rc"
        BLOCKERS+=("$name failed with exit $rc; log=$out")
        section "FAIL $name exit=$rc (log=$out)"
    fi
    return 0
}
run_smoke() {
    local smoke="$1"
    local base="$(basename "$smoke" .sh)"
    local out="$RUN_DIR/${base}.log"
    section "RUN smoke $smoke"
    bash "$ROOT/$smoke" 2>&1 | tee "$out"
    local rc=${PIPESTATUS[0]}
    local value="PASS"
    if [[ $rc -ne 0 ]]; then
        value="FAIL"
        BLOCKERS+=("$smoke failed with exit $rc; log=$out")
    else
        COMPLETED+=("$smoke")
    fi
    local transcript=""
    case "$base" in
        smoke-hv-status-v0) transcript="$ROOT/smoke/transcripts/latest-hv-status-v0.txt" ;;
        smoke-hv-capability-v0) transcript="$ROOT/smoke/transcripts/latest-hv-capability-v0.txt" ;;
        *) transcript="$(find "$ROOT/smoke/transcripts" -maxdepth 1 -type f -name "*${base#smoke-}*" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')" ;;
    esac
    record_smoke "$smoke" "$value" "$out" "$transcript"
    section "$value smoke $smoke exit=$rc (log=$out transcript=${transcript:-unknown})"
    return 0
}
short_commit() { git rev-parse --short HEAD 2>/dev/null || printf 'unknown'; }
branch_name() { git branch --show-current 2>/dev/null || printf 'unknown'; }
zig_path() {
    if [[ -n "${ZIG:-}" ]]; then printf '%s' "$ZIG"; else command -v zig 2>/dev/null || printf 'zig-not-found'; fi
}
zig_version() {
    local zp; zp="$(zig_path)"
    "$zp" version 2>/dev/null || printf 'unknown'
}
status_for() {
    local name="$1" i
    for ((i=0; i<${#STATUS_NAMES[@]}; i++)); do
        [[ "${STATUS_NAMES[$i]}" == "$name" ]] && { printf '%s' "${STATUS_VALUES[$i]}"; return; }
    done
    printf 'MISSING'
}
smoke_status_for() {
    local name="$1" i
    for ((i=0; i<${#SMOKE_NAMES[@]}; i++)); do
        [[ "${SMOKE_NAMES[$i]}" == "$name" ]] && { printf '%s' "${SMOKE_VALUES[$i]}"; return; }
    done
    printf 'MISSING'
}

section "Hyper-Zig canonical validation starting"
printf 'Repository root: %s\n' "$ROOT"
printf 'Branch: %s\n' "$(branch_name)"
printf 'Commit: %s\n' "$(short_commit)"
printf 'Zig path: %s\n' "$(zig_path)"
printf 'Zig version: %s\n' "$(zig_version)"
printf 'Run directory: %s\n' "$RUN_DIR"

run_check "check-zig-version" "$ROOT/scripts/check-zig-version.sh"
run_check "build" "$ROOT/scripts/build.sh"

DISCOVERED=()
while IFS= read -r -d '' f; do
    rel="${f#$ROOT/}"
    DISCOVERED+=("$rel")
done < <(find "$ROOT/smoke" -maxdepth 1 -type f -name 'smoke-*.sh' -print0 | sort -z)

for smoke in "${REQUIRED_SMOKES[@]}"; do
    if [[ -x "$ROOT/$smoke" || -f "$ROOT/$smoke" ]]; then
        run_smoke "$smoke"
    else
        record_smoke "$smoke" "MISSING" "" ""
        BLOCKERS+=("required smoke missing: $smoke")
        MISSING_MILESTONES+=("required smoke missing: $smoke")
    fi
done

for smoke in "${DISCOVERED[@]}"; do
    contains_path "$smoke" "${REQUIRED_SMOKES[@]}" && continue
    run_smoke "$smoke"
done

for smoke in "${OPTIONAL_DECLARED_SMOKES[@]}"; do
    if ! contains_path "$smoke" "${DISCOVERED[@]}" && ! contains_path "$smoke" "${REQUIRED_SMOKES[@]}"; then
        MISSING_OPTIONAL+=("$smoke")
        record_smoke "$smoke" "MISSING" "" ""
    fi
done

MISSING_MILESTONES+=(
    "Linux guest support (not implemented; do not claim)"
    "guest execution (not implemented; do not claim)"
    "VM/vCPU objects (not smoke-proven as implemented)"
)

FAIL_COUNT=0
for v in "${STATUS_VALUES[@]}" "${SMOKE_VALUES[@]}"; do
    [[ "$v" == "FAIL" ]] && FAIL_COUNT=$((FAIL_COUNT + 1))
done
for smoke in "${REQUIRED_SMOKES[@]}"; do
    [[ "$(smoke_status_for "$smoke")" == "MISSING" ]] && FAIL_COUNT=$((FAIL_COUNT + 1))
done

BUILD_STATUS="$(status_for build)"
HV0_STATUS="$(smoke_status_for smoke/smoke-hv-status-v0.sh)"
HV1_STATUS="$(smoke_status_for smoke/smoke-hv-capability-v0.sh)"
OVERALL="PASS"
REASON="All required checks passed; optional missing items are reported without being counted as PASS."
if [[ "$(status_for check-zig-version)" != "PASS" ]]; then
    OVERALL="BLOCKED"
    REASON="Zig 0.14.x toolchain validation is blocked or failed; inspect the version-check log."
elif [[ "$BUILD_STATUS" != "PASS" ]]; then
    OVERALL="BLOCKED"
    REASON="The kernel build is blocked or failed; inspect the build log before trusting smoke results."
elif [[ $FAIL_COUNT -ne 0 ]]; then
    OVERALL="FAIL"
    REASON="One or more required checks or discovered smoke tests failed; inspect blockers and logs."
fi

NEXT_MILESTONE="Keep HV0/HV1 honest, then implement the next documented hypervisor milestone only after smoke evidence exists; do not claim Linux guest or guest execution support yet."

{
cat <<SUMMARY

==================================================
HYPER-ZIG MINIMUS-LOG FINAL SUMMARY
===================================
Repository: Hyper-Zig
Branch: $(branch_name)
Commit: $(short_commit)
Zig path: $(zig_path)
Zig version: $(zig_version)
Zig target: 0.14.x only
Build status: $BUILD_STATUS
HV0 smoke: $HV0_STATUS
HV1 smoke: $HV1_STATUS
Overall readiness: $OVERALL
Reason: $REASON

Command log: $COMMAND_LOG
Summary log: $SUMMARY_LOG
Run directory: $RUN_DIR
Newest logs directory: $ROOT/logs/latest

All check statuses:
SUMMARY
for ((i=0; i<${#STATUS_NAMES[@]}; i++)); do
    printf '  - %s: %s (exit=%s)\n' "${STATUS_NAMES[$i]}" "${STATUS_VALUES[$i]}" "${STATUS_CODES[$i]}"
done
printf '\nAll smoke statuses:\n'
for ((i=0; i<${#SMOKE_NAMES[@]}; i++)); do
    printf '  - %s: %s' "${SMOKE_NAMES[$i]}" "${SMOKE_VALUES[$i]}"
    [[ -n "${SMOKE_LOGS[$i]}" ]] && printf ' log=%s' "${SMOKE_LOGS[$i]}"
    [[ -n "${SMOKE_TRANSCRIPTS[$i]}" ]] && printf ' transcript=%s' "${SMOKE_TRANSCRIPTS[$i]}"
    printf '\n'
done
printf '\nTranscript paths:\n'
printf '  - HV0: %s\n' "$ROOT/smoke/transcripts/latest-hv-status-v0.txt"
printf '  - HV1: %s\n' "$ROOT/smoke/transcripts/latest-hv-capability-v0.txt"
printf '\nCompleted milestones/evidence:\n'
if [[ ${#COMPLETED[@]} -eq 0 ]]; then printf '  - none\n'; else printf '  - %s\n' "${COMPLETED[@]}"; fi
printf '\nMissing optional smoke tests (MISSING is not PASS):\n'
if [[ ${#MISSING_OPTIONAL[@]} -eq 0 ]]; then printf '  - none\n'; else printf '  - %s\n' "${MISSING_OPTIONAL[@]}"; fi
printf '\nMissing milestones / not claimed:\n'
printf '  - %s\n' "${MISSING_MILESTONES[@]}"
printf '\nCurrent blockers:\n'
if [[ ${#BLOCKERS[@]} -eq 0 ]]; then printf '  - none\n'; else printf '  - %s\n' "${BLOCKERS[@]}"; fi
printf '\nNext milestone:\n  - %s\n' "$NEXT_MILESTONE"
printf '\nMinimus-Log inspection:\n'
printf '  - tail -n 200 %q\n' "$COMMAND_LOG"
printf '  - tail -n 500 %q\n' "$COMMAND_LOG"
printf '===================================\n'
} | tee "$SUMMARY_LOG"

if [[ "$OVERALL" == "PASS" ]]; then
    exit 0
fi
exit 1
