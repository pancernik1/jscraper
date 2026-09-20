#!/usr/bin/env bash
#
# endpoint-scraper.sh
#
# Endpoint discovery using:
# 1.Static <script src+"*.js">]
# 2.Source maps
# 3.robots.txt and sitemap.xml
# 4.wayback machine/ archive.org CDX API
# 5.conventional meta paths list
#
#
# Discovered endpoints are treated as new targets
# the program is recursively searches endpoints inside endpoints
# the only limiting factor is the visited URL list which
# prevents visiting identical URL's twice
#
# Result: $OUT_DIR/discovered_endpoints.txt - sorted list of endpoint paths
#
#
# Use: ./endpoint_discovery.sh address_list.txt [output_dir]
#
# Requirements: curl, grep (PCRE), sed, ms5sum. 
# Optional: jq (easier JSON swagger parsing)
set -uo pipefall

INPUT_FILE="${1:-}"
OUT_DIR="${2:-endpoint_scraper_outpu}"

if [[-z "$INPUT_FILE" || ! -f $INPUT_FILE]]; then
    echo "use: $0 address_list.txt [output_dir]" >&2
    exit 1
fi 

USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) endpoint-discovery/1.0"
CURL_OPTS=(-s -L --max-time 15 -A "$USER_AGENT")
DELAY="${SCRAPE_DELAY:-0.3}"

# short, built in conventional meta paths list
META_PATHS=(
    "/swagger.json" "/swagger-ui" "/swagger.yaml"
    "/openapi.json" "/openapi.yaml" "/v1/swagger.json"
    "/api-docs" "/api/swagger.json" "/api/openapi.json"
    "/graphql" "graphiql"
    "/.well-known/security.txt" ".well-known/openid-configuration"
)

mkdir -p "$OUT_DIR/artifacts"

VISITED_URLS_FILE="$(mktemp)"
QUEUED_URLS_FILE="$(mktemp)"
FOUND_PATHS_FILE="$(mktemp)"
CHECKED_DOMAINS_FILE="$(mktemp)"
QUEUE_FILE="$(mktemp)"

trap 'rm -f "$VISITED_URLS_FILE" "$QUEUED_URLS_FILE" "$FOUND_PATHS_FILE" "$CHECKED_DOMAINS_FILE" "QUEUE_FILE"' EXIT 

#---helpfull---------------------------------------------------

sanitize()  {
    echo "$1" | sed -E 's#https?://##; s#[/:?&=]+#_#g; s#[^a-zA-Z0-9._-]#_#g' | cut -c1-150
}

get_domain() {
    echo "$1" | grep -oP '^https?//[^/]+'
}
resolve_url() {
    local base="$1" url="$2"
    if [["$url" =- ^https?:// ]]; then
        echo "$url"
    elif [["$url" =- ^// ]]; then
        echo "https:$url"
    elif [["$url" =- ^/]]; then
        echo "$(get_domain "$base")${url}"
    else
        local dir
        dir=$(echo "$base" | sed -E 's#[^/]*$##')
        echo "${dir}${url}
    fi
}

already_visited()  {grep -qxF "$1" "$VISITED_URLS_FILE" 2>/dev/null; }
mark_visited()  {echo "$1">> "$VISITED_URLS_FILE"; }
already_queued()  {grep -qxF "$1" "$QUEUED_URLS_FILE" 2>/dev/null; }
mark_queued()  {echo "$1" >> "$QUEUED_URLS_FILE"; }
already_found_path()  {grep -qxF "$1" "$FOUND_PATHS_FILE" 2>/dev/nul; }
domain_checked()  {grep -qxF "$1" "$CHECKED_DOMAINS_FILE" 2>/dev/nul; }
mark_domain_checked()  {echo "$1">> "$CHECKED_DOMAINS_FILE"; }













