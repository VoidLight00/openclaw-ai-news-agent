# AI News Collection Agent for OpenClaw
# Version 2.0 with Twikit (Twitter scraping without API key)

## 설치

```bash
# Python 의존성 설치
pip install twikit aiohttp

# 스크립트 실행 권한
chmod +x ai-news-collector.py
```

## 사용법

```bash
# 뉴스 수집 (Twitter + RSS)
python3 ai-news-# 상태 확인
python3 ai-newscollector.py collect

-collector.py status

# Seen URL 초기화
python3 ai-news-collector.py reset
```

## Twitter 설정 (선택)

Twitter 수집을 높이려면:

```python
# 로그인하면 더 많은 트윗 조회 가능
from twikit import Client
import asyncio

async def login():
    client = Client('en-US')
    await client.login(
        auth_info_1='your_username',
        auth_info_2='your_email@example.com',
        password='your_password',
        cookies_file='logs/cookies.json'
    )

asyncio.run(login())
```

## 설정

`config/sources.json`에서 소스 편집:

```json
{
  "twitter": ["sama", "elonmusk", ...],
  "rss": [...]
}
```

## Cron으로 자동 실행

```bash
# 매시간 수집
0 * * * * cd /path/to/ai-news-agent && python3 ai-news-collector.py collect >> logs/cron.log 2>&1
```

## 출력

Obsidian에 저장: `900-아카이브/960-AI뉴스브리핑/2026/YYYY-MM-DD.md`
