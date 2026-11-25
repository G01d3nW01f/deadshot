#!/usr/bin/env bash

# ==========================================================
# DeadShot - Internal Domain Intelligence Tool
# Usage: ./deadshot.sh <targetdomain>
# Scope: Authorized domains only
# ==========================================================

set -Eeuo pipefail
umask 077

readonly TOOL_NAME="DeadShot"
readonly BASE_DIR="./deadshot_results"

usage() {
    echo "Usage: $0 <targetdomain>"
    echo "Example: $0 example.co.jp"
}

log() {
    printf '[%s] %s\n' "$TOOL_NAME" "$*"
}

die() {
    printf '[%s] ERROR: %s\n' "$TOOL_NAME" "$*" >&2
    exit 1
}

# ----------------------------------------------------------
# 1. Argument validation
# ----------------------------------------------------------

[[ $# -eq 1 ]] || {
    usage >&2
    exit 1
}

domain="${1,,}"

# FQDN validation
if [[ ! "$domain" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]]; then
    die "Invalid domain: $domain"
fi

# ----------------------------------------------------------
# 2. Dependency check
# ----------------------------------------------------------

for cmd in subfinder dnsx sort awk comm date mkdir mktemp cp; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command not found: $cmd"
done

# ----------------------------------------------------------
# 3. Output directory and filenames
# ----------------------------------------------------------

timestamp="$(date '+%Y%m%d_%H%M%S')"
run_id="${timestamp}_$$"

outdir="${BASE_DIR}/${domain}"

mkdir -p "$outdir"

scan_file="${outdir}/domain_scan_${run_id}.txt"
dns_file="${outdir}/dns_records_${run_id}.txt"
alive_file="${outdir}/alive_list_${run_id}.txt"
new_file="${outdir}/new_hosts_${run_id}.txt"
gone_file="${outdir}/disappeared_hosts_${run_id}.txt"
http_file="${outdir}/http_list_${run_id}.txt"


# Persistent snapshot used for the next comparison
latest_file="${outdir}/latest_alive_list.txt"

tmpdir="$(mktemp -d)"
trap 'rm -rf -- "$tmpdir"' EXIT

# ----------------------------------------------------------
# 4. Discover subdomains (passive enumeration)
# ----------------------------------------------------------

log "Starting subdomain enumeration: $domain"

if ! subfinder -d "$domain" -silent -o "$tmpdir/subfinder.txt"; then
    die "subfinder failed"
fi

# Include the root domain as well
printf '%s\n' "$domain" >> "$tmpdir/subfinder.txt"

# Normalize and deduplicate
sort -u "$tmpdir/subfinder.txt" > "$tmpdir/candidates.txt"

# Retain only the target domain and its subdomains
# This prevents unrelated names from entering the scan.
awk -v d="$domain" '
    $0 == d || (length($0) > length(d) &&
                substr($0, length($0) - length(d), length(d) + 1) == "." d) {
        print
    }
' "$tmpdir/candidates.txt" > "$scan_file"

[[ -s "$scan_file" ]] || die "No candidate domains found"

log "Candidates: $(wc -l < "$scan_file" | tr -d ' ')"

# ----------------------------------------------------------
# 5. DNS resolution and wildcard filtering
# ----------------------------------------------------------

log "Resolving A / AAAA records with dnsx"

# The output format is: hostname IP1,IP2,...
# -auto-wildcard attempts to detect wildcard DNS.
if ! dnsx \
    -l "$scan_file" \
    -silent \
    -a \
    -aaaa \
    -auto-wildcard \
    -ot '{{host}} {{ip}}' \
    -o "$dns_file"; then
    die "dnsx failed; previous snapshot was not updated"
fi

# Extract unique hostnames with DNS responses
awk 'NF >= 2 { print $1 }' "$dns_file" |
    sort -u > "$alive_file"

# Ensure output files exist even when no hosts resolve
: > "$new_file"
: > "$gone_file"



# ----------------------------------------------------------
# 5.5 HTTP / HTTPS probing
# ----------------------------------------------------------

log "Checking HTTP / HTTPS services with httpx"

# Create both HTTP and HTTPS candidates from DNS-resolved hosts.
# Only hosts in alive_file are checked.
: > "$tmpdir/http_candidates.txt"

while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    printf 'http://%s\nhttps://%s\n' "$host" \
        >> "$tmpdir/http_candidates.txt"
done < "$alive_file"

# Ensure the output file exists even when no hosts resolve.
: > "$http_file"


HTTPX_BIN="$(go env GOPATH)/bin/httpx"

[[ -x "$HTTPX_BIN" ]] ||
    die "ProjectDiscovery httpx not found: $HTTPX_BIN"

if [[ -s "$tmpdir/http_candidates.txt" ]]; then
    if ! "$HTTPX_BIN" \
        -l "$tmpdir/http_candidates.txt" \
        -silent \
        -no-color \
        -no-fallback \
        -o "$http_file"; then
        die "httpx failed; previous snapshot was not updated"
    fi
fi

# Remove duplicate URLs and sort the results.
sort -u "$http_file" > "$tmpdir/http_list.tmp"
mv "$tmpdir/http_list.tmp" "$http_file"

log "HTTP / HTTPS endpoints: $(wc -l < "$http_file" | tr -d ' ')"



# ----------------------------------------------------------
# 6. Compare with the previous snapshot
# ----------------------------------------------------------

if [[ -f "$latest_file" ]]; then
    log "Comparing with previous snapshot"

    sort -u "$latest_file" > "$tmpdir/previous.txt"
    sort -u "$alive_file" > "$tmpdir/current.txt"

    # Hosts present now but absent from the previous snapshot
    comm -13 "$tmpdir/previous.txt" "$tmpdir/current.txt" \
        > "$new_file"

    # Hosts present previously but absent now
    comm -23 "$tmpdir/previous.txt" "$tmpdir/current.txt" \
        > "$gone_file"
else
    log "No previous snapshot; recording initial baseline"
    cp "$alive_file" "$new_file"
fi

# ----------------------------------------------------------
# 7. Update the persistent snapshot
# ----------------------------------------------------------

cp "$alive_file" "$tmpdir/latest.tmp"
mv "$tmpdir/latest.tmp" "$latest_file"

# ----------------------------------------------------------
# 8. Summary
# ----------------------------------------------------------

candidate_count="$(wc -l < "$scan_file" | tr -d ' ')"
resolved_count="$(wc -l < "$alive_file" | tr -d ' ')"
new_count="$(wc -l < "$new_file" | tr -d ' ')"
gone_count="$(wc -l < "$gone_file" | tr -d ' ')"

echo
log "Scan completed"
echo "------------------------------------------"
echo "Target domain : $domain"
echo "Candidates    : $candidate_count"
echo "DNS resolved  : $resolved_count"
echo "New hosts     : $new_count"
echo "Disappeared   : $gone_count"
echo "------------------------------------------"
echo "Subdomains    : $scan_file"
echo "DNS records   : $dns_file"
echo "Alive list    : $alive_file"
echo "New hosts     : $new_file"
echo "Disappeared   : $gone_file"
echo "Latest state  : $latest_file"
