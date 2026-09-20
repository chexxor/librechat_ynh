#!/bin/bash
# scripts/redact_pc_logs.sh
#
# Redact real secret values from archived package_check logs and assert the
# result is clean. Used to make the POLS-01 archive (Phase 6) safe to commit.
#
# Usage:
#   SECRETS_FILE=/path/secrets.txt bash scripts/redact_pc_logs.sh <input> [<output>]
#   SECRET_VALUES="val1 val2"      bash scripts/redact_pc_logs.sh <input> [<output>]
#   bash scripts/redact_pc_logs.sh --assert-only <input>
#
#   <input>   a log file OR a directory of log files
#   <output>  a file or directory (default: alongside input as <name>.redacted,
#             or <input>/redacted/ for a directory)
#
# Secrets are supplied as KEY=VALUE lines (SECRETS_FILE) or a space/comma
# separated list (SECRET_VALUES). Empty values are skipped. Secret values are
# never printed — only counts are reported.
#
# Exit codes: 0 = OK (no residual matches); 1 = residual matches remain; 2 = usage error.

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
ASSERT_ONLY=false
if [[ "${1:-}" == "--assert-only" ]]; then
    ASSERT_ONLY=true
    shift
fi

INPUT="${1:-}"
OUTPUT="${2:-}"

if [[ -z "${INPUT}" ]]; then
    echo "usage: SECRETS_FILE=... | SECRET_VALUES=... bash scripts/redact_pc_logs.sh [--assert-only] <input> [<output>]" >&2
    exit 2
fi
if [[ ! -e "${INPUT}" ]]; then
    echo "error: input not found: ${INPUT}" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Collect secret values (skip empty). Never print the values themselves.
# ---------------------------------------------------------------------------
SECRETS=()
if [[ -n "${SECRETS_FILE:-}" ]]; then
    if [[ ! -f "${SECRETS_FILE}" ]]; then
        echo "error: SECRETS_FILE not found: ${SECRETS_FILE}" >&2
        exit 2
    fi
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Strip optional KEY= prefix and CR
        line="${line%$'\r'}"
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        val="${line#*=}"
        [[ "${val}" == "${line}" ]] && val="${line}"   # no '=' -> whole line is the value
        [[ -n "${val}" ]] && SECRETS+=("${val}")
    done < "${SECRETS_FILE}"
fi
if [[ -n "${SECRET_VALUES:-}" ]]; then
    IFS=', ' read -r -a _vals <<< "${SECRET_VALUES}"
    for v in "${_vals[@]}"; do
        [[ -n "${v}" ]] && SECRETS+=("${v}")
    done
fi

if [[ ${#SECRETS[@]} -eq 0 ]]; then
    echo "warning: no secret values supplied (SECRETS_FILE / SECRET_VALUES empty) — nothing to redact" >&2
fi

# ---------------------------------------------------------------------------
# Escape a literal string for use in a sed BRE/ERE replacement/pattern.
# We use a fixed-string, global replacement via awk to avoid regex pitfalls:
# awk scans each line and does index-based literal replacement.
# ---------------------------------------------------------------------------
redact_file() {
    local src="$1" dst="$2"
    awk -v secrets_joined="$(printf '%s\x1f' "${SECRETS[@]}")" '
        BEGIN {
            n = split(secrets_joined, arr, "\x1f")
            # build list, drop trailing empty
            m = 0
            for (i = 1; i <= n; i++) if (arr[i] != "") { m++; sec[m] = arr[i] }
            # longest first to avoid partial overlaps
            for (i = 1; i <= m; i++) for (j = i+1; j <= m; j++)
                if (length(sec[j]) > length(sec[i])) { t=sec[i]; sec[i]=sec[j]; sec[j]=t }
        }
        {
            line = $0
            for (i = 1; i <= m; i++) {
                pat = sec[i]
                out = ""
                while ((p = index(line, pat)) > 0) {
                    out = out substr(line, 1, p-1) "***REDACTED***"
                    line = substr(line, p + length(pat))
                }
                line = out line
            }
            print line
        }
    ' "${src}" > "${dst}"
}

assert_file() {
    local f="$1" hits=0
    for s in "${SECRETS[@]}"; do
        if grep -qF -- "${s}" "${f}"; then
            hits=$((hits + 1))
        fi
    done
    echo "${hits}"
}

# ---------------------------------------------------------------------------
# Walk input(s)
# ---------------------------------------------------------------------------
targets=()
if [[ -d "${INPUT}" ]]; then
    while IFS= read -r -d '' f; do targets+=("${f}"); done < <(find "${INPUT}" -type f -print0)
else
    targets+=("${INPUT}")
fi

if [[ ${#targets[@]} -eq 0 ]]; then
    echo "error: no files found under ${INPUT}" >&2
    exit 2
fi

if [[ "${ASSERT_ONLY}" == true ]]; then
    total_hits=0
    for f in "${targets[@]}"; do
        h=$(assert_file "${f}")
        if [[ "${h}" -gt 0 ]]; then
            echo "RESIDUAL: ${f} (${h} secret pattern(s) present)"
            total_hits=$((total_hits + h))
        fi
    done
    if [[ "${total_hits}" -eq 0 ]]; then
        echo "REDACTION OK: 0 residual secret matches"
        exit 0
    else
        echo "REDACTION FAILED: ${total_hits} residual match(es)"
        exit 1
    fi
fi

# Redaction mode
if [[ -z "${OUTPUT}" ]]; then
    if [[ -d "${INPUT}" ]]; then
        OUTPUT="${INPUT%/}/redacted"
    else
        OUTPUT="${INPUT}.redacted"
    fi
fi

if [[ -d "${INPUT}" ]]; then
    mkdir -p "${OUTPUT}"
elif [[ -d "${OUTPUT}" ]]; then
    OUTPUT="${OUTPUT%/}/$(basename "${INPUT}")"
fi

total_hits=0
for f in "${targets[@]}"; do
    if [[ -d "${INPUT}" ]]; then
        rel="${f#"${INPUT%/}/"}"
        dst="${OUTPUT}/${rel}"
        mkdir -p "$(dirname "${dst}")"
    else
        dst="${OUTPUT}"
    fi
    redact_file "${f}" "${dst}"
    h=$(assert_file "${dst}")
    total_hits=$((total_hits + h))
done

if [[ "${total_hits}" -eq 0 ]]; then
    echo "REDACTION OK: 0 residual secret matches"
    exit 0
else
    echo "REDACTION FAILED: ${total_hits} residual match(es) after redaction"
    exit 1
fi
