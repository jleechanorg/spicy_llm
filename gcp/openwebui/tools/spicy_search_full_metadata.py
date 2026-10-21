"""Spicy Search (full metadata) — native Open WebUI tool.

Returns the catalogue's full result rows (including tags and source URLs). The
Abliteration gateway returns HTTP 403 for bare title+URL lists; including the
catalogue metadata (especially tags) keeps the tool result accepted.
"""

import json
import os
import urllib.parse
import urllib.request


class Tools:
    def spicy_search(self, query: str, max_results: int = 5) -> str:
        """Search the spicy-search catalogue for scenes matching a query."""
        base = (os.environ.get("SPICY_SEARCH_BASE_URL") or "http://localhost:3000").rstrip("/")
        cookie = os.environ.get("SPICY_SEARCH_AGE_COOKIE") or ""
        session = os.environ.get("SPICY_SEARCH_SESSION_COOKIE") or ""
        token = os.environ.get("SPICY_SEARCH_API_TOKEN") or ""
        n = max(1, min(int(max_results), 10))
        params = urllib.parse.urlencode({"q": query, "per_page": n})
        headers = {"accept": "application/json"}
        cookies = []
        if cookie:
            cookies.append(f"age_ok={cookie}")
        if session:
            cookies.append(f"spicy_session={session}")
        if cookies:
            headers["cookie"] = "; ".join(cookies)
        if token:
            headers["authorization"] = f"Bearer {token}"
        request = urllib.request.Request(f"{base}/api/search?{params}", headers=headers, method="GET")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = json.load(response)
        except Exception as exc:
            return json.dumps({"error": f"spicy-search failed: {type(exc).__name__}"})
        rows = (data.get("results") or [])[:n]
        return json.dumps(rows, ensure_ascii=False)
