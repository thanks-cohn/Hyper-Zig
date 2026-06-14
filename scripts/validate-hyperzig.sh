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
    "smoke/smoke-hv-vm-vcpu-v0.sh"
    "smoke/smoke-hv-vcpu-lifecycle-v0.sh"
    "smoke/smoke-hv-guest-memory-v0.sh"
    "smoke/smoke-hv-address-space-v0.sh"
    "smoke/smoke-hv-guest-image-v0.sh"
    "smoke/smoke-hv-guest-entry-v0.sh"
    "smoke/smoke-hv-guest-exit-v0.sh"
    "smoke/smoke-hv-guest-run-attempt-v0.sh"
    "smoke/smoke-hv-guest-execution-v0.sh"
    "smoke/smoke-hv-second-stage-v0.sh"
    "smoke/smoke-hv-stage2-table-v0.sh"
    "smoke/smoke-hv-boot-package-v0.sh"
    "smoke/smoke-hv-dtb-contract-v0.sh"
    "smoke/smoke-hv-sbi-foundation-v0.sh"
    "smoke/smoke-hv-virtual-timer-v0.sh"
    "smoke/smoke-hv-binary-fdt-v0.sh"
    "smoke/smoke-hv-linux-handoff-v0.sh"
    "smoke/smoke-hv-sbi-console-v0.sh"
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
        smoke-hv-vm-vcpu-v0) transcript="$ROOT/smoke/transcripts/latest-hv-vm-vcpu-v0.txt" ;;
        smoke-hv-vcpu-lifecycle-v0) transcript="$ROOT/smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt" ;;
        smoke-hv-guest-memory-v0) transcript="$ROOT/smoke/transcripts/latest-hv-guest-memory-v0.txt" ;;
        smoke-hv-address-space-v0) transcript="$ROOT/smoke/transcripts/latest-hv-address-space-v0.txt" ;;
        smoke-hv-guest-image-v0) transcript="$ROOT/smoke/transcripts/latest-hv-guest-image-v0.txt" ;;
        smoke-hv-guest-entry-v0) transcript="$ROOT/smoke/transcripts/latest-hv-guest-entry-v0.txt" ;;
        smoke-hv-guest-exit-v0) transcript="$ROOT/smoke/transcripts/latest-hv-guest-exit-v0.txt" ;;
        smoke-hv-guest-run-attempt-v0) transcript="$ROOT/smoke/transcripts/latest-hv-guest-run-attempt-v0.txt" ;;
        smoke-hv-guest-execution-v0) transcript="$ROOT/smoke/transcripts/latest-hv-guest-execution-v0.txt" ;;
        smoke-hv-second-stage-v0) transcript="$ROOT/smoke/transcripts/latest-hv-second-stage-v0.txt" ;;
        smoke-hv-stage2-table-v0) transcript="$ROOT/smoke/transcripts/latest-hv-stage2-table-v0.txt" ;;
        smoke-hv-boot-package-v0) transcript="$ROOT/smoke/transcripts/latest-hv-boot-package-v0.txt" ;;
        smoke-hv-dtb-contract-v0) transcript="$ROOT/smoke/transcripts/latest-hv-dtb-contract-v0.txt" ;;
        smoke-hv-sbi-foundation-v0) transcript="$ROOT/smoke/transcripts/latest-hv-sbi-foundation-v0.txt" ;;
        smoke-hv-virtual-timer-v0) transcript="$ROOT/smoke/transcripts/latest-hv-virtual-timer-v0.txt" ;;
        smoke-hv-binary-fdt-v0) transcript="$ROOT/smoke/transcripts/latest-hv-binary-fdt-v0.txt" ;;
        smoke-hv-linux-handoff-v0) transcript="$ROOT/smoke/transcripts/latest-hv-linux-handoff-v0.txt" ;;
        smoke-hv-sbi-console-v0) transcript="$ROOT/smoke/transcripts/latest-hv-sbi-console-v0.txt" ;;
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
    "guest instruction execution beyond HV10 hardware-gated preparation (not implemented; do not claim)"
    "hardware second-stage translation (not active; HV11 metadata and HV12 software table only; do not claim active translation)"
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
HV2_STATUS="$(smoke_status_for smoke/smoke-hv-vm-vcpu-v0.sh)"
HV3_STATUS="$(smoke_status_for smoke/smoke-hv-vcpu-lifecycle-v0.sh)"
HV4_STATUS="$(smoke_status_for smoke/smoke-hv-guest-memory-v0.sh)"
HV5_STATUS="$(smoke_status_for smoke/smoke-hv-address-space-v0.sh)"
HV6_STATUS="$(smoke_status_for smoke/smoke-hv-guest-image-v0.sh)"
HV7_STATUS="$(smoke_status_for smoke/smoke-hv-guest-entry-v0.sh)"
HV8_STATUS="$(smoke_status_for smoke/smoke-hv-guest-exit-v0.sh)"
HV9_STATUS="$(smoke_status_for smoke/smoke-hv-guest-run-attempt-v0.sh)"
HV10_STATUS="$(smoke_status_for smoke/smoke-hv-guest-execution-v0.sh)"
HV11_STATUS="$(smoke_status_for smoke/smoke-hv-second-stage-v0.sh)"
HV12_STATUS="$(smoke_status_for smoke/smoke-hv-stage2-table-v0.sh)"
HV13_STATUS="$(smoke_status_for smoke/smoke-hv-boot-package-v0.sh)"
HV14_STATUS="$(smoke_status_for smoke/smoke-hv-dtb-contract-v0.sh)"
HV15_STATUS="$(smoke_status_for smoke/smoke-hv-sbi-foundation-v0.sh)"
HV16_STATUS="$(smoke_status_for smoke/smoke-hv-virtual-timer-v0.sh)"
HV17_STATUS="$(smoke_status_for smoke/smoke-hv-binary-fdt-v0.sh)"
HV18_STATUS="$(smoke_status_for smoke/smoke-hv-linux-handoff-v0.sh)"
HV19_STATUS="$(smoke_status_for smoke/smoke-hv-sbi-console-v0.sh)"
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

CURRENT_MILESTONE="HV19 SBI Console Mediation Foundation proven when required smoke passes; no Linux boot, no guest execution, no active second-stage translation, no printk claim"
NEXT_MILESTONE="controlled active guest-entry prerequisites, SBI dispatch integration, or first guest instruction infrastructure without Linux support claim"

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
HV2 smoke: $HV2_STATUS
HV3 vCPU lifecycle smoke: $HV3_STATUS
HV4 guest memory smoke: $HV4_STATUS
HV5 guest address space smoke: $HV5_STATUS
HV6 guest image loader smoke: $HV6_STATUS
HV7 guest entry preparation smoke: $HV7_STATUS
HV8 guest trap/exit smoke: $HV8_STATUS
HV9 guest run-attempt smoke: $HV9_STATUS
HV10 guest execution preparation smoke: $HV10_STATUS
HV11 second-stage metadata smoke: $HV11_STATUS
HV12 stage2 software table smoke: $HV12_STATUS
HV13 guest boot package smoke: $HV13_STATUS
HV14 DTB contract smoke: $HV14_STATUS
HV15 SBI foundation smoke: $HV15_STATUS
HV16 virtual timer smoke: $HV16_STATUS
HV17 binary FDT smoke: $HV17_STATUS
HV18 Linux handoff smoke: $HV18_STATUS
HV19 SBI console mediation smoke: $HV19_STATUS
HV0 PASS: $HV0_STATUS
HV1 PASS: $HV1_STATUS
HV2 PASS: $HV2_STATUS
HV3 vCPU lifecycle PASS: $HV3_STATUS
HV4 guest memory PASS: $HV4_STATUS
HV5 guest address space PASS: $HV5_STATUS
HV6 guest image loader PASS: $HV6_STATUS
HV7 guest entry preparation PASS: $HV7_STATUS
HV8 guest trap/exit PASS: $HV8_STATUS
HV9 guest run-attempt PASS: $HV9_STATUS
HV10 guest execution preparation PASS: $HV10_STATUS
HV11 second-stage metadata PASS: $HV11_STATUS
HV12 stage2 software table PASS: $HV12_STATUS
HV13 guest boot package PASS: $HV13_STATUS
HV14 DTB contract PASS: $HV14_STATUS
HV15 SBI foundation PASS: $HV15_STATUS
HV16 virtual timer PASS: $HV16_STATUS
HV17 binary FDT PASS: $HV17_STATUS
HV18 Linux handoff PASS: $HV18_STATUS
HV19 SBI console mediation PASS: $HV19_STATUS
VM/vCPU model implemented
vCPU lifecycle implemented only if smoke passes: $HV3_STATUS
guest memory object implemented only if smoke passes: $HV4_STATUS
guest address space metadata implemented only if smoke passes: $HV5_STATUS
guest image loader implemented only if smoke passes: $HV6_STATUS
guest entry preparation implemented only if smoke passes: $HV7_STATUS
guest trap/exit metadata implemented only if smoke passes: $HV8_STATUS
guest run-attempt safety gate implemented only if smoke passes: $HV9_STATUS
guest execution preparation gate implemented only if smoke passes: $HV10_STATUS
second-stage translation metadata implemented only if smoke passes: $HV11_STATUS
stage2 software table implemented only if smoke passes: $HV12_STATUS
guest image format: tiny-flat-v0
guest memory backing: pmm-bitmap-v0
guest execution still not supported
Linux guest still not supported
current milestone: HV19 SBI Console Mediation Foundation
next milestone: controlled active guest-entry prerequisites, SBI dispatch integration, or first guest instruction infrastructure
Overall readiness: $OVERALL
Reason: $REASON

First-run developer guidance:
  - git clone git@github.com:thanks-cohn/Hyper-Zig.git
  - cd Hyper-Zig
  - export ZIG=/path/to/zig-0.14.x/zig
  - zig build
  - zig build validate-hyperzig
  - ./scripts/validate-hyperzig.sh
  - tail -n 200 logs/latest/validate-hyperzig.log

Current milestone: $CURRENT_MILESTONE
Next coding target: controlled active guest-entry prerequisites, SBI dispatch integration, or first guest instruction infrastructure
HV2/HV3/HV4/HV5 file map:
  - kernel/hypervisor/vm.zig
  - kernel/hypervisor/vcpu.zig
  - kernel/hypervisor/guest_memory.zig
  - kernel/hypervisor/guest_address_space.zig
  - smoke/smoke-hv-vm-vcpu-v0.sh
  - smoke/smoke-hv-vcpu-lifecycle-v0.sh
  - smoke/smoke-hv-guest-memory-v0.sh
  - smoke/smoke-hv-address-space-v0.sh
  - smoke/smoke-hv-guest-image-v0.sh
  - smoke/smoke-hv-guest-entry-v0.sh
  - smoke/smoke-hv-guest-exit-v0.sh
  - smoke/smoke-hv-guest-run-attempt-v0.sh
  - smoke/smoke-hv-guest-execution-v0.sh
  - smoke/smoke-hv-second-stage-v0.sh
  - smoke/smoke-hv-stage2-table-v0.sh
  - smoke/smoke-hv-boot-package-v0.sh
  - smoke/smoke-hv-dtb-contract-v0.sh
  - docs/hypervisor/HV2_VM_VCPU_MODEL.md
Exact command to rerun validation:
  - ./scripts/validate-hyperzig.sh
Developer map:
  - docs/hypervisor/DEVELOPER_START_HERE.md
HV2 implementation map:
  - docs/hypervisor/HV2_IMPLEMENTATION_MAP.md
Non-claims:
  - no Linux guest support yet
  - no guest execution yet
  - VM/vCPU object model is smoke-proven in HV2
  - vCPU lifecycle is smoke-proven only when HV3 smoke passes
  - guest memory object is smoke-proven only when HV4 smoke passes
  - guest address space metadata is smoke-proven only when HV5 smoke passes
  - guest image loading and readback verification are smoke-proven only when HV6 smoke passes
  - guest entry preparation metadata is smoke-proven only when HV7 smoke passes
  - guest trap/exit metadata is smoke-proven only when HV8 smoke passes
  - guest run-attempt no-execute safety gate is smoke-proven only when HV9 smoke passes
  - guest execution preparation and hardware gate logic are smoke-proven only when HV10 smoke passes
  - second-stage translation metadata is smoke-proven only when HV11 smoke passes; HV12 software table is smoke-proven only when HV12 smoke passes; hardware translation remains missing
  - no guest execution or Linux guest support yet

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
printf '  - HV2: %s\n' "$ROOT/smoke/transcripts/latest-hv-vm-vcpu-v0.txt"
printf '  - HV3 vCPU lifecycle: %s\n' "$ROOT/smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt"
printf '  - HV4 guest memory: %s\n' "$ROOT/smoke/transcripts/latest-hv-guest-memory-v0.txt"
printf '  - HV5 guest address space: %s\n' "$ROOT/smoke/transcripts/latest-hv-address-space-v0.txt"
printf '  - HV6 guest image loader: %s\n' "$ROOT/smoke/transcripts/latest-hv-guest-image-v0.txt"
printf '  - HV7 guest entry preparation: %s\n' "$ROOT/smoke/transcripts/latest-hv-guest-entry-v0.txt"
printf '  - HV8 guest trap/exit: %s\n' "$ROOT/smoke/transcripts/latest-hv-guest-exit-v0.txt"
printf '  - HV9 guest run-attempt: %s\n' "$ROOT/smoke/transcripts/latest-hv-guest-run-attempt-v0.txt"
printf '  - HV10 guest execution preparation: %s\n' "$ROOT/smoke/transcripts/latest-hv-guest-execution-v0.txt"
printf '  - HV11 second-stage metadata: %s\n' "$ROOT/smoke/transcripts/latest-hv-second-stage-v0.txt"
printf '  - HV12 stage2 software table: %s\n' "$ROOT/smoke/transcripts/latest-hv-stage2-table-v0.txt"
printf '  - HV13 guest boot package: %s\n' "$ROOT/smoke/transcripts/latest-hv-boot-package-v0.txt"
printf '  - HV14 DTB contract: %s\n' "$ROOT/smoke/transcripts/latest-hv-dtb-contract-v0.txt"
printf '  - HV15 SBI foundation: %s\n' "$ROOT/smoke/transcripts/latest-hv-sbi-foundation-v0.txt"
printf '  - HV16 virtual timer: %s\n' "$ROOT/smoke/transcripts/latest-hv-virtual-timer-v0.txt"
printf '  - HV17 binary FDT: %s\n' "$ROOT/smoke/transcripts/latest-hv-binary-fdt-v0.txt"
printf '  - HV18 Linux handoff: %s\n' "$ROOT/smoke/transcripts/latest-hv-linux-handoff-v0.txt"
printf '  - HV19 SBI console mediation: %s\n' "$ROOT/smoke/transcripts/latest-hv-sbi-console-v0.txt"
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
