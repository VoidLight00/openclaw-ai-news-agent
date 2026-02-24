#!/bin/bash

# AI News Collection Agent for OpenClaw
# Collects X/Twitter posts and RSS feeds, saves to Obsidian
# Model: openai/gpt-4o (thinking: off)

set -e

# === CONFIG ===
AGENT_DIR="/Users/voidlight/.openclaw/workspace/ai-news-agent"
OBSIDIAN_PATH="/Users/voidlight/Documents/암흑물질"
NEWS_FOLDER="900-아카이브/960-AI뉴스브리핑/2026"
CONFIG_FILE="$AGENT_DIR/config/sources.json"
LOG_FILE="$AGENT_DIR/logs/collection.log"
SEEN_FILE="$AGENT_DIR/logs/seen_urls.txt"

# === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# === LOGGING ===
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

# === CHECK DEPENDENCIES ===
check_deps() {
    local missing=()
    
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v xq >/dev/null 2>&1 || missing+=("xmlq/yq")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "ERROR" "Missing dependencies: ${missing[*]}"
        echo "Install: brew install curl jq xmlq"
        exit 1
    fi
}

# === LOAD CONFIG ===
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "ERROR" "Config file not found: $CONFIG_FILE"
        exit 1
    fi
}

# === X/TWITTER COLLECTION ===
collect_twitter() {
    local account="$1"
    local output_file="$2"
    
    log "INFO" "Collecting Twitter: @${account}"
    
    # Check if we have Twitter API credentials
    if [ -z "$TWITTER_BEARER_TOKEN" ]; then
        # Fallback: Use web scraping
        local url="https://nitter.net/${account}"
        local content=$(curl -sL "$url" 2>/dev/null || echo "")
        
        if [ -n "$content" ]; then
            echo "$content" | grep -oE 'https://twitter.com/[a-zA-Z0-9_]+/status/[0-9]+' | sort -u >> "$output_file"
            log "INFO" "Collected from nitter: @${account}"
        else
            log "WARN" "Failed to collect from nitter: @${account}"
        fi
    else
        # Use Twitter API
        local tweets=$(curl -sL "https://api.twitter.com/2/users/by/username/${account}" \
            -H "Authorization: Bearer ${TWITTER_BEARER_TOKEN}" 2>/dev/null)
        
        if [ -n "$tweets" ]; then
            local user_id=$(echo "$tweets" | jq -r '.data.id // empty')
            if [ -n "$user_id" ]; then
                curl -sL "https://api.twitter.com/2/users/${user_id}/tweets?max_results=10" \
                    -H "Authorization: Bearer ${TWITTER_BEARER_TOKEN}" | \
                    jq -r '.data[]?.id' 2>/dev/null >> "$output_file"
                log "INFO" "Collected via API: @${account}"
            fi
        fi
    fi
}

# === RSS COLLECTION ===
collect_rss() {
    local feed_url="$1"
    local feed_name="$2"
    local output_file="$3"
    
    log "INFO" "Collecting RSS: ${feed_name}"
    
    local content=$(curl -sL "$feed_url" 2>/dev/null || echo "")
    
    if [ -n "$content" ]; then
        # Try to extract URLs
        echo "$content" | grep -oE '<link>[^<]+</link>' | \
            sed 's/<link>//g; s/<\/link>//g' | grep -v '^$' | sort -u >> "$output_file"
        log "INFO" "Collected RSS: ${feed_name}"
    else
        log "WARN" "Failed to collect RSS: ${feed_name}"
    fi
}

# === DEDUPLICATION ===
deduplicate() {
    local input_file="$1"
    local output_file="$2"
    
    # Create output file
    : > "$output_file"
    
    while IFS= read -r url; do
        # Skip empty lines
        [ -z "$url" ] && continue
        
        # Check if already seen
        if ! grep -q "^${url}$" "$SEEN_FILE" 2>/dev/null; then
            echo "$url" >> "$output_file"
            echo "$url" >> "$SEEN_FILE"
        fi
    done < "$input_file"
}

# === SAVE TO OBSIDIAN ===
save_to_obsidian() {
    local news_file="$1"
    local news_items="$2"
    
    # Get today's date for the news file
    local today=$(date '+%Y-%m-%d')
    local news_path="${OBSIDIAN_PATH}/${NEWS_FOLDER}/${today}.md"
    
    # Create folder if needed
    mkdir -p "$(dirname "$news_path")"
    
    # Create or append to today's news file
    if [ ! -f "$news_path" ]; then
        echo "---" > "$news_path"
        echo "date: ${today}" >> "$news_path"
        echo "tags: [ai-news, daily]" >> "$news_path"
        echo "---" >> "$news_path"
        echo "" >> "$news_path"
        echo "# AI News Briefing - ${today}" >> "$news_path"
        echo "" >> "$news_path"
    fi
    
    # Add new items
    echo "## Collected: $(date '+%H:%M')" >> "$news_path"
    
    while IFS= read -r item; do
        [ -z "$item" ] && continue
        echo "- $item" >> "$news_path"
    done < "$news_items"
    
    echo "" >> "$news_path"
    
    log "INFO" "Saved to Obsidian: $news_path"
}

# === FETCH ARTICLE CONTENT ===
fetch_article() {
    local url="$1"
    local output_file="$2"
    
    # Simple fetch - just get the title
    local title=$(curl -sL "$url" 2>/dev/null | \
        grep -oE '<title>[^<]+</title>' | head -1 | \
        sed 's/<title>//g; s/<\/title>//g')
    
    if [ -n "$title" ]; then
        echo "$title | $url" >> "$output_file"
    fi
}

# === MAIN COLLECTION ===
collect_all() {
    log "INFO" "=== Starting AI News Collection ==="
    
    # Create temp files
    local temp_all=$(mktemp)
    local temp_new=$(mktemp)
    
    # Load and process each source
    if [ -f "$CONFIG_FILE" ]; then
        # Twitter accounts
        local twitter_accounts=$(jq -r '.twitter[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
        for account in $twitter_accounts; do
            collect_twitter "$account" "$temp_all"
        done
        
        # RSS feeds
        local rss_feeds=$(jq -r '.rss[] | "\(.url) \(.name)"' "$CONFIG_FILE" 2>/dev/null || echo "")
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local url=$(echo "$line" | cut -d' ' -f1)
            local name=$(echo "$line" | cut -d' ' -f2-)
            collect_rss "$url" "$name" "$temp_all"
        done <<< "$rss_feeds"
    else
        # Default sources if no config
        collect_rss "https://news.ycombinator.com/rss" "Hacker News" "$temp_all"
        collect_rss "https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml" "NYT Tech" "$temp_all"
    fi
    
    # Deduplicate
    deduplicate "$temp_all" "$temp_new"
    
    # Count new items
    local new_count=$(wc -l < "$temp_new")
    log "INFO" "New items collected: $new_count"
    
    # Save to Obsidian
    if [ "$new_count" -gt 0 ]; then
        save_to_obsidian "$NEWS_FOLDER" "$temp_new"
    else
        log "INFO" "No new items to save"
    fi
    
    # Cleanup
    rm -f "$temp_all" "$temp_new"
    
    log "INFO" "=== Collection Complete ==="
}

# === STATUS ===
status() {
    echo "=== AI News Agent Status ==="
    echo "Agent Dir: $AGENT_DIR"
    echo "Obsidian Path: $OBSIDIAN_PATH/$NEWS_FOLDER"
    echo ""
    echo "Sources configured: $(jq '.twitter | length + .rss | length' "$CONFIG_FILE" 2>/dev/null || echo "0")"
    echo "URLs seen: $(wc -l < "$SEEN_FILE" 2>/dev/null || echo "0")"
    echo ""
    echo "Recent news files:"
    ls -la "${OBSIDIAN_PATH}/${NEWS_FOLDER}/" 2>/dev/null | tail -5
}

# === HELP ===
help() {
    cat << 'EOF'
=== AI News Collection Agent ===

Usage:
  ./ai-news-agent.sh [command]

Commands:
  collect     - Collect all news sources and save to Obsidian
  status      - Show agent status
  reset       - Clear seen URLs (start fresh)
  help        - Show this help

Environment:
  TWITTER_BEARER_TOKEN  - Twitter API token (optional)

Config:
  config/sources.json   - News sources configuration

Examples:
  ./ai-news-agent.sh collect    # Collect all news
  ./ai-news-agent.sh status     # Check status
EOF
}

# === MAIN ===
case "$1" in
    collect)
        check_deps
        load_config
        collect_all
        ;;
    status)
        status
        ;;
    reset)
        : > "$SEEN_FILE"
        echo "Seen URLs cleared"
        ;;
    help|--help|-h)
        help
        ;;
    *)
        help
        ;;
esac
