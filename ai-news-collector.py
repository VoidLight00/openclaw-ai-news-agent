#!/usr/bin/env python3
"""
AI News Collection Agent for OpenClaw
Uses Twikit for Twitter scraping (no API key required)
Model: openai/gpt-4o (thinking: off)
"""

import asyncio
import json
import os
import sys
import logging
from datetime import datetime
from pathlib import Path

# === CONFIG ===
AGENT_DIR = Path("/Users/voidlight/.openclaw/workspace/ai-news-agent")
OBSIDIAN_PATH = Path("/Users/voidlight/Documents/암흑물질")
NEWS_FOLDER = Path("900-아카이브/960-AI뉴스브리핑/2026")
CONFIG_FILE = AGENT_DIR / "config" / "sources.json"
LOG_FILE = AGENT_DIR / "logs" / "collection.log"
SEEN_FILE = AGENT_DIR / "logs" / "seen_urls.txt"
COOKIES_FILE = AGENT_DIR / "logs" / "cookies.json"

# === LOGGING ===
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
log = logging.info

# === LOAD CONFIG ===
def load_config():
    if not CONFIG_FILE.exists():
        log(f"Config file not found: {CONFIG_FILE}")
        sys.exit(1)
    
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

# === LOAD SEEN URLs ===
def load_seen_urls():
    if SEEN_FILE.exists():
        with open(SEEN_FILE, 'r') as f:
            return set(line.strip() for line in f if line.strip())
    return set()

# === SAVE SEEN URL ===
def save_seen_url(url):
    with open(SEEN_FILE, 'a') as f:
        f.write(f"{url}\n")

# === TWITTER COLLECTION ===
async def collect_twitter(client, accounts):
    """Collect latest tweets from specified accounts"""
    all_tweets = []
    
    for account in accounts:
        try:
            log(f"Collecting tweets from @{account}")
            # Get user tweets
            user = await client.get_user_by_screen_name(account)
            if not user:
                log(f"User not found: {account}")
                continue
                
            tweets = await client.get_user_tweets(user.id, 'Tweets')
            
            for tweet in tweets[:10]:  # Latest 10 tweets
                tweet_url = f"https://twitter.com/{account}/status/{tweet.id}"
                all_tweets.append({
                    'url': tweet_url,
                    'text': tweet.text,
                    'author': account,
                    'created_at': str(tweet.created_at)
                })
                
            log(f"Collected {len(tweets[:10])} tweets from @{account}")
            
        except Exception as e:
            log(f"Error collecting from @{account}: {e}")
    
    return all_tweets

# === RSS COLLECTION ===
async def collect_rss(feeds):
    """Collect items from RSS feeds"""
    import urllib.request
    import xml.etree.ElementTree as ET
    
    all_items = []
    
    for feed in feeds:
        try:
            log(f"Collecting RSS: {feed['name']}")
            
            req = urllib.request.Request(feed['url'], headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                content = response.read().decode('utf-8')
            
            # Parse RSS
            root = ET.fromstring(content)
            
            for item in root.findall('.//item'):
                title = item.findtext('title', '')
                link = item.findtext('link', '')
                
                if link:
                    all_items.append({
                        'url': link,
                        'text': title,
                        'source': feed['name'],
                        'category': feed.get('category', 'tech')
                    })
            
            log(f"Collected from {feed['name']}")
            
        except Exception as e:
            log(f"Error collecting RSS {feed['name']}: {e}")
    
    return all_items

# === DEDUPLICATE ===
def deduplicate(items, seen_urls):
    """Remove already-seen URLs"""
    new_items = []
    
    for item in items:
        url = item['url']
        if url not in seen_urls:
            new_items.append(item)
            seen_urls.add(url)
            save_seen_url(url)
    
    return new_items

# === SAVE TO OBSIDIAN ===
def save_to_obsidian(items):
    """Save collected items to Obsidian"""
    today = datetime.now().strftime('%Y-%m-%d')
    news_path = OBSIDIAN_PATH / NEWS_FOLDER / f"{today}.md"
    
    # Create folder
    news_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Create or append
    is_new = not news_path.exists()
    
    with open(news_path, 'a', encoding='utf-8') as f:
        if is_new:
            f.write("---\n")
            f.write(f"date: {today}\n")
            f.write("tags: [ai-news, daily]\n")
            f.write("---\n\n")
            f.write(f"# AI News Briefing - {today}\n\n")
        
        f.write(f"## Collected: {datetime.now().strftime('%H:%M')}\n")
        
        for item in items:
            source = item.get('author') or item.get('source', 'Unknown')
            text = item.get('text', '')[:200]
            url = item['url']
            f.write(f"- [{text}]({url}) [{source}]\n")
        
        f.write("\n")
    
    log(f"Saved to Obsidian: {news_path}")
    return news_path

# === MAIN ===
async def main():
    log("=== Starting AI News Collection ===")
    
    # Load config
    config = load_config()
    
    # Load seen URLs
    seen_urls = load_seen_urls()
    log(f"Seen URLs: {len(seen_urls)}")
    
    all_items = []
    
    # Try Twitter collection
    twitter_accounts = config.get('twitter', [])
    if twitter_accounts:
        try:
            from twikit import Client
            
            # Initialize client (anonymous for now - can add login later)
            client = Client('en-US')
            
            # Try to load cookies if exists
            if COOKIES_FILE.exists():
                client.load_cookies(str(COOKIES_FILE))
            
            # Collect Twitter
            log(f"Collecting from {len(twitter_accounts)} Twitter accounts...")
            tweets = await collect_twitter(client, twitter_accounts[:50])  # Limit to 50 for now
            all_items.extend(tweets)
            
        except ImportError:
            log("Twikit not installed. Run: pip install twikit")
        except Exception as e:
            log(f"Twitter collection error: {e}")
    
    # RSS collection
    rss_feeds = config.get('rss', [])
    if rss_feeds:
        log(f"Collecting from {len(rss_feeds)} RSS feeds...")
        rss_items = await collect_rss(rss_feeds)
        all_items.extend(rss_items)
    
    # Deduplicate
    new_items = deduplicate(all_items, seen_urls)
    log(f"New items: {len(new_items)}")
    
    # Save to Obsidian
    if new_items:
        save_to_obsidian(new_items)
    else:
        log("No new items to save")
    
    log("=== Collection Complete ===")

# === CLI ===
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='AI News Collection Agent')
    parser.add_argument('command', nargs='?', default='collect', help='Command: collect, status, reset')
    args = parser.parse_args()
    
    if args.command == 'collect':
        asyncio.run(main())
    elif args.command == 'status':
        config = load_config()
        seen = load_seen_urls()
        print("=== AI News Agent Status ===")
        print(f"Twitter accounts: {len(config.get('twitter', []))}")
        print(f"RSS feeds: {len(config.get('rss', []))}")
        print(f"URLs seen: {len(seen)}")
    elif args.command == 'reset':
        with open(SEEN_FILE, 'w') as f:
            f.write('')
        print("Seen URLs cleared")
    else:
        print("Unknown command")
