#!/usr/bin/env python3
"""
Test all streaming sources to verify they work before iOS integration.
Tests embed URLs, checks for valid responses, and validates player events.
"""

import asyncio
import aiohttp
import json
import time
from dataclasses import dataclass
from typing import Optional, Dict, List
from urllib.parse import urljoin, urlparse
import re

# Test IDs
TMDB_MOVIE_ID = 533535  # Deadpool & Wolverine
TMDB_TV_ID = 1399       # Game of Thrones
IMDB_MOVIE_ID = "tt6263850"  # Deadpool & Wolverine
IMDB_TV_ID = "tt0944947"     # Game of Thrones

# Source configurations
SOURCES = [
    {
        "id": "vidsrc.to",
        "name": "VidSrc.to",
        "movie_url": "https://vidsrc.to/embed/movie/{id}",
        "tv_url": "https://vidsrc.to/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vidsrc.to/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vidsrc.net",
        "name": "VidSrc.net",
        "movie_url": "https://vidsrc.net/embed/movie/{id}",
        "tv_url": "https://vidsrc.net/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vidsrc.net/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vidsrc.cc",
        "name": "VidSrc.cc",
        "movie_url": "https://vidsrc.cc/v3/embed/movie/{id}",
        "tv_url": "https://vidsrc.cc/v3/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vidsrc.cc/v3/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": True,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vidsrc.sh",
        "name": "VidSrc.sh",
        "movie_url": "https://vidsrc.sh/embed/movie/{id}",
        "tv_url": "https://vidsrc.sh/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vidsrc.sh/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vidsrc.io",
        "name": "VidSrc.io",
        "movie_url": "https://vidsrc.io/embed/movie/{id}",
        "tv_url": "https://vidsrc.io/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vidsrc.io/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vidsrc.me",
        "name": "VidSrc.me",
        "movie_url": "https://vidsrc.me/embed/movie/{id}",
        "tv_url": "https://vidsrc.me/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vidsrc.me/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vsembed.su",
        "name": "VSEmbed.su",
        "movie_url": "https://vsembed.su/embed/movie/{id}",
        "tv_url": "https://vsembed.su/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vsembed.su/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "embed.su",
        "name": "Embed.su",
        "movie_url": "https://embed.su/embed/movie/{id}",
        "tv_url": "https://embed.su/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://embed.su/embed/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "superembed.stream",
        "name": "SuperEmbed (watch.embed-api.stream)",
        "movie_url": "https://watch.embed-api.stream/embed/movie/{id}",
        "tv_url": "https://watch.embed-api.stream/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": None,
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vidcore.org",
        "name": "VidCore",
        "movie_url": "https://vidcore.org/embed/movie/{id}",
        "tv_url": "https://vidcore.org/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": None,
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": False,  # Only TMDB
    },
    {
        "id": "nhdapi.com",
        "name": "NHD Embed",
        "movie_url": "https://nhdapi.com/movie/{id}",
        "tv_url": "https://nhdapi.com/tv/{id}/{season}/{episode}",
        "tv_series_url": None,
        "anime_url": "https://nhdapi.com/anime/{id}/{episode}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": True,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "primesrc.me",
        "name": "PrimeSrc",
        "movie_url": "https://primesrc.me/movie-tv/primesrc/movie/{id}",
        "tv_url": "https://primesrc.me/movie-tv/primesrc/tv/{id}/{season}/{episode}",
        "tv_series_url": None,
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": False,  # API returns JSON, not embed
    },
    {
        "id": "ezvidapi.com",
        "name": "EZVidAPI",
        "movie_url": "https://ezvidapi.com/embed/movie/{id}",
        "tv_url": "https://ezvidapi.com/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": None,
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": True,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "watch.embed-api.stream",
        "name": "Embed API Stream",
        "movie_url": "https://watch.embed-api.stream/embed/movie/{id}",
        "tv_url": "https://watch.embed-api.stream/embed/tv/{id}/{season}/{episode}",
        "tv_series_url": None,
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
    {
        "id": "vidspark.to",
        "name": "VidSpark",
        "movie_url": "https://vidspark.to/movie/{id}",
        "tv_url": "https://vidspark.to/tv/{id}/{season}/{episode}",
        "tv_series_url": "https://vidspark.to/tv/{id}",
        "supports_movies": True,
        "supports_tv": True,
        "supports_anime": False,
        "accepts_tmdb": True,
        "accepts_imdb": True,
    },
]


@dataclass
class TestResult:
    source_id: str
    source_name: str
    test_type: str  # "movie_tmdb", "movie_imdb", "tv_tmdb", "tv_imdb", "tv_series"
    url: str
    status_code: Optional[int]
    response_time_ms: float
    has_player: bool
    has_video_element: bool
    error: Optional[str]
    content_length: int
    content_type: str


async def test_url(session: aiohttp.ClientSession, url: str, timeout: int = 15) -> TestResult:
    """Test a single URL and check for player elements."""
    start = time.time()
    headers = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
    
    try:
        async with session.get(url, headers=headers, timeout=aiohttp.ClientTimeout(total=timeout)) as resp:
            elapsed = (time.time() - start) * 1000
            content = await resp.text()
            content_type = resp.headers.get("Content-Type", "")
            
            # Check for player indicators
            has_player = any(keyword in content.lower() for keyword in [
                "video", "player", "iframe", "hls", "m3u8", "mp4", "stream",
                "jwplayer", "plyr", "videojs", "mediaelement", "clappr"
            ])
            
            has_video_element = "video" in content.lower() or "iframe" in content.lower()
            
            return TestResult(
                source_id="",
                source_name="",
                test_type="",
                url=url,
                status_code=resp.status,
                response_time_ms=elapsed,
                has_player=has_player,
                has_video_element=has_video_element,
                error=None if resp.status < 400 else f"HTTP {resp.status}",
                content_length=len(content),
                content_type=content_type,
            )
    except asyncio.TimeoutError:
        return TestResult(
            source_id="", source_name="", test_type="", url=url,
            status_code=None, response_time_ms=timeout * 1000,
            has_player=False, has_video_element=False,
            error=f"Timeout after {timeout}s",
            content_length=0, content_type=""
        )
    except Exception as e:
        return TestResult(
            source_id="", source_name="", test_type="", url=url,
            status_code=None, response_time_ms=(time.time() - start) * 1000,
            has_player=False, has_video_element=False,
            error=str(e),
            content_length=0, content_type=""
        )


def format_url(template: str, id_value: str, season: int = None, episode: int = None) -> str:
    """Format URL template with appropriate placeholders."""
    url = template
    # Replace all known placeholders
    url = url.replace("{id}", id_value)
    url = url.replace("{tmdb_id}", id_value)
    if season is not None:
        url = url.replace("{season}", str(season))
    if episode is not None:
        url = url.replace("{episode}", str(episode))
    # Check for any remaining unformatted placeholders
    if "{" in url and "}" in url:
        # Try to replace any remaining {xxx} with id_value
        import re
        url = re.sub(r'\{[^}]+\}', id_value, url)
    return url

async def test_source(session: aiohttp.ClientSession, source: dict) -> List[TestResult]:
    """Test all endpoints for a single source."""
    results = []
    
    # Test Movie with TMDB ID
    if source["supports_movies"] and source["accepts_tmdb"]:
        url = format_url(source["movie_url"], str(TMDB_MOVIE_ID))
        result = await test_url(session, url)
        result.source_id = source["id"]
        result.source_name = source["name"]
        result.test_type = "movie_tmdb"
        results.append(result)
    
    # Test Movie with IMDB ID
    if source["supports_movies"] and source["accepts_imdb"]:
        url = format_url(source["movie_url"], IMDB_MOVIE_ID)
        result = await test_url(session, url)
        result.source_id = source["id"]
        result.source_name = source["name"]
        result.test_type = "movie_imdb"
        results.append(result)
    
    # Test TV Episode with TMDB ID
    if source["supports_tv"] and source["accepts_tmdb"]:
        url = format_url(source["tv_url"], str(TMDB_TV_ID), season=1, episode=1)
        result = await test_url(session, url)
        result.source_id = source["id"]
        result.source_name = source["name"]
        result.test_type = "tv_tmdb"
        results.append(result)
    
    # Test TV Episode with IMDB ID
    if source["supports_tv"] and source["accepts_imdb"]:
        url = format_url(source["tv_url"], IMDB_TV_ID, season=1, episode=1)
        result = await test_url(session, url)
        result.source_id = source["id"]
        result.source_name = source["name"]
        result.test_type = "tv_imdb"
        results.append(result)
    
    # Test TV Series (full series picker)
    if source["supports_tv"] and source.get("tv_series_url") and source["accepts_tmdb"]:
        url = format_url(source["tv_series_url"], str(TMDB_TV_ID))
        result = await test_url(session, url)
        result.source_id = source["id"]
        result.source_name = source["name"]
        result.test_type = "tv_series"
        results.append(result)
    
    return results


def print_results(results: List[TestResult]):
    """Print formatted test results."""
    print("\n" + "=" * 120)
    print(f"{'SOURCE':<25} {'TEST':<15} {'STATUS':<8} {'TIME(ms)':<10} {'PLAYER':<8} {'VIDEO':<8} {'SIZE':<10} ERROR")
    print("=" * 120)
    
    for r in results:
        status = str(r.status_code) if r.status_code else "ERR"
        player = "✓" if r.has_player else "✗"
        video = "✓" if r.has_video_element else "✗"
        size = f"{r.content_length/1024:.1f}KB" if r.content_length else "0B"
        error = r.error[:50] if r.error else ""
        
        print(f"{r.source_name:<25} {r.test_type:<15} {status:<8} {r.response_time_ms:<10.0f} {player:<8} {video:<8} {size:<10} {error}")
    
    print("=" * 120)
    
    # Summary
    total = len(results)
    successful = sum(1 for r in results if r.status_code and 200 <= r.status_code < 400)
    with_player = sum(1 for r in results if r.has_player)
    
    print(f"\nSUMMARY: {successful}/{total} HTTP OK, {with_player}/{total} have player indicators")
    
    # Per-source summary
    print("\nPER-SOURCE SUMMARY:")
    by_source = {}
    for r in results:
        if r.source_id not in by_source:
            by_source[r.source_id] = {"name": r.source_name, "tests": [], "ok": 0, "player": 0}
        by_source[r.source_id]["tests"].append(r)
        if r.status_code and 200 <= r.status_code < 400:
            by_source[r.source_id]["ok"] += 1
        if r.has_player:
            by_source[r.source_id]["player"] += 1
    
    for source_id, data in by_source.items():
        tests = len(data["tests"])
        print(f"  {data['name']:<25} OK: {data['ok']}/{tests}  Player: {data['player']}/{tests}")


async def main():
    print("Testing all streaming sources...")
    print(f"Movie TMDB ID: {TMDB_MOVIE_ID} (Deadpool & Wolverine)")
    print(f"Movie IMDB ID: {IMDB_MOVIE_ID}")
    print(f"TV TMDB ID: {TMDB_TV_ID} (Game of Thrones)")
    print(f"TV IMDB ID: {IMDB_TV_ID}")
    
    connector = aiohttp.TCPConnector(limit=5, limit_per_host=2)
    timeout = aiohttp.ClientTimeout(total=20)
    
    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        all_results = []
        
        for source in SOURCES:
            print(f"\nTesting {source['name']}...")
            results = await test_source(session, source)
            all_results.extend(results)
            
            # Small delay between sources to be polite
            await asyncio.sleep(0.5)
        
        print_results(all_results)
        
        # Save detailed results to JSON
        output = []
        for r in all_results:
            output.append({
                "source_id": r.source_id,
                "source_name": r.source_name,
                "test_type": r.test_type,
                "url": r.url,
                "status_code": r.status_code,
                "response_time_ms": r.response_time_ms,
                "has_player": r.has_player,
                "has_video_element": r.has_video_element,
                "error": r.error,
                "content_length": r.content_length,
                "content_type": r.content_type,
            })
        
        with open("streaming_test_results.json", "w") as f:
            json.dump(output, f, indent=2)
        
        print("\nDetailed results saved to streaming_test_results.json")


if __name__ == "__main__":
    asyncio.run(main())