#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./scripts/extract_unique_ips.sh [log_file_or_directory ...]

Examples:
  ./scripts/extract_unique_ips.sh /var/log/nginx/access.log
  ./scripts/extract_unique_ips.sh /var/log/nginx /var/log/apache2/error.log

If no path is provided, common Nginx/Apache log paths are used.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

collect_files=()

if [[ "$#" -eq 0 ]]; then
    defaults=(
        /var/log/nginx/access.log
        /var/log/nginx/error.log
        /var/log/apache2/access.log
        /var/log/apache2/error.log
    )
    for f in "${defaults[@]}"; do
        [[ -f "$f" ]] && collect_files+=("$f")
    done
else
    for input_path in "$@"; do
        if [[ -f "$input_path" ]]; then
            collect_files+=("$input_path")
        elif [[ -d "$input_path" ]]; then
            while IFS= read -r -d '' file; do
                collect_files+=("$file")
            done < <(find "$input_path" -type f \( -name "*.log" -o -name "*.log.*" \) -print0)
        fi
    done
fi

if [[ "${#collect_files[@]}" -eq 0 ]]; then
    echo "No log files found." >&2
    exit 1
fi

# Extract IPv4/IPv6 patterns, normalize, and print unique values.
grep -hEo '([0-9]{1,3}\.){3}[0-9]{1,3}|([A-Fa-f0-9]{1,4}:){2,7}[A-Fa-f0-9]{1,4}' "${collect_files[@]}" \
    | sed 's/\[//g; s/\]//g' \
    | sort -u
