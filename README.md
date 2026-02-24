# AI News Collection Agent for OpenClaw

AI 뉴스 수집 서브에이전트 - X/Twitter와 RSS를 수집하여 Obsidian에 저장

## 모델 설정

- **모델:** openai/gpt-4o
- **Thinking:** off

## 기능

- X/Twitter 계정에서 게시물 수집
- RSS 피드에서 뉴스 수집
- 중복 제거 (이미 저장한 건 건너뛰기)
- Obsidian에 일일 뉴스 노트로 저장

## 설치

```bash
# 의존성 설치
brew install curl jq

# 스크립트 실행 권한
chmod +x ai-news-agent.sh
```

## 사용법

```bash
# 뉴스 수집
./ai-news-agent.sh collect

# 상태 확인
./ai-news-agent.sh status

# Seen URL 초기화
./ai-news-agent.sh reset
```

## 설정

`config/sources.json`에서 소스 편집:

```json
{
  "twitter": ["sama", "elonmusk", "AndrewYNg", ...],
  "rss": [
    {"name": "Hacker News", "url": "https://news.ycombinator.com/rss"},
    {"name": "MIT Tech Review", "url": "https://www.technologyreview.com/feed/"},
    ...
  ]
}
```

**현재 설정:**
- Twitter/X 계정: 294개
- RSS 피드: 12개

## 출력

 Obsidian에 저장: `900-아카이브/960-AI뉴스브리핑/2026/YYYY-MM-DD.md`

## Cron으로 자동 실행

```bash
# 매시간 수집
0 * * * * /path/to/ai-news-agent.sh collect
```
