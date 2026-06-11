#!/usr/bin/env bash
# Helpers for appending final validation report sections.
# The caller owns run execution; these helpers only inspect the final artifact
# state and print the compact navigation section required before MINIMUS LOG.

hyperzig_artifact_roots() {
    local root="$1"
    local run_dir="$2"

    printf '%s\n' "$run_dir"
    printf '%s\n' "$root/logs/latest"
    printf '%s\n' "$root/smoke/transcripts"
    printf '%s\n' "$root/zig-out"
}

hyperzig_collect_artifacts() {
    local root="$1"
    local run_dir="$2"
    local start_epoch="$3"
    local root_path

    hyperzig_artifact_roots "$root" "$run_dir" | while IFS= read -r root_path; do
        [[ -d "$root_path" ]] || continue
        find "$root_path" \
            \( -type f -o -type l \) \
            -newermt "@$start_epoch" \
            -print 2>/dev/null
    done | awk '!seen[$0]++' | LC_ALL=C sort
}

hyperzig_print_link_for_everything() {
    local root="$1"
    local run_dir="$2"
    local start_epoch="$3"
    local artifact

    printf 'A LINK FOR EVERYTHING\n\n'
    while IFS= read -r artifact; do
        [[ -n "$artifact" ]] || continue
        printf '%s\n\n' "$(basename "$artifact")"
        printf 'Full Address:\n'
        printf '%s\n\n' "$artifact"
    done < <(hyperzig_collect_artifacts "$root" "$run_dir" "$start_epoch")
}
