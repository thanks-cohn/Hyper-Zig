#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

required=(
  docs/WHAT_IS_ZIGN01D.md
  docs/EDUCATIONAL_MISSION.md
  docs/COURSE_MAP.md
  docs/PROFESSOR_QUICKSTART.md
  docs/STUDENT_QUICKSTART.md
  docs/LAB_MANUAL.md
  docs/ASSIGNMENTS.md
  docs/GRADING_RUBRIC.md
  docs/PROOF_CONTRACT.md
  docs/COMMAND_REFERENCE.md
  docs/SOURCE_MAP.md
  docs/MILESTONE_INDEX.md
  docs/DOCUMENTATION_CONTRACT.md
  docs/AI_ASSISTANCE_POLICY.md
  docs/COMPARATIVE_KERNEL_VISION.md
  docs/README.md
  docs/MILESTONE_MEMORY_V0_USER_GUIDE.md
  docs/MEMORY_V0_SPEC.md
  docs/MEMORY_V0_AUDIT.md
  ROADMAP.md
)

for path in "${required[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "FAIL missing $path" >&2
    exit 1
  fi
done

echo "PASS ZIGN01D docs smoke"
