"""Read README content from a public GitHub repository URL."""

from __future__ import annotations

import re
from time import perf_counter
from typing import Any
from urllib.parse import urlsplit

import httpx

from app.models.types import ToolDefinition, ToolPermission

from ..base import BaseTool

_GITHUB_REPO_RE = re.compile(r"^/([^/]+)/([^/#?]+)")
_README_CANDIDATES = (
    "README.md",
    "README.MD",
    "readme.md",
    "README",
)


class GitHubReadmeTool(BaseTool):
    """Fetch a repository README through GitHub's raw HEAD redirect."""

    def __init__(
        self,
        *,
        client: httpx.AsyncClient | None = None,
        max_response_bytes: int = 200_000,
    ) -> None:
        self._client = client
        self._max_response_bytes = max_response_bytes

    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="github_readme",
            description=(
                "Read the README from a public GitHub repository URL. "
                "Use this first when the user provides a github.com/owner/repo "
                "link and asks to read or summarize the repository. It follows "
                "GitHub's default branch via raw/HEAD and does not use search."
            ),
            parameters={
                "type": "object",
                "properties": {
                    "url": {
                        "type": "string",
                        "description": (
                            "GitHub repository URL, for example "
                            "https://github.com/owner/repo"
                        ),
                    },
                    "max_length": {
                        "type": "integer",
                        "description": "Maximum README characters to return.",
                        "minimum": 1000,
                        "maximum": 200000,
                        "default": 50000,
                    },
                },
                "required": ["url"],
                "additionalProperties": False,
            },
            strict=True,
            permission=ToolPermission.ALLOWED,
        )

    async def execute(self, arguments: dict[str, Any]) -> dict[str, Any]:
        url = arguments.get("url")
        if not isinstance(url, str) or not url.strip():
            raise ValueError("'url' must be a non-empty GitHub repository URL")
        owner, repo = _parse_github_repo(url)

        max_length = arguments.get("max_length", 50_000)
        if isinstance(max_length, bool) or not isinstance(max_length, int):
            raise ValueError("'max_length' must be an integer")
        max_length = max(1000, min(max_length, self._max_response_bytes))

        if self._client is not None:
            return await self._fetch(self._client, owner, repo, max_length)

        async with httpx.AsyncClient(follow_redirects=True, timeout=20.0) as client:
            return await self._fetch(client, owner, repo, max_length)

    async def _fetch(
        self,
        client: httpx.AsyncClient,
        owner: str,
        repo: str,
        max_length: int,
    ) -> dict[str, Any]:
        started_at = perf_counter()
        errors: list[str] = []
        for filename in _README_CANDIDATES:
            raw_url = f"https://github.com/{owner}/{repo}/raw/HEAD/{filename}"
            response = await client.get(raw_url)
            if response.status_code == 200 and response.text.strip():
                text = response.text
                truncated = len(text) > max_length
                return {
                    "url": f"https://github.com/{owner}/{repo}",
                    "raw_url": str(response.url),
                    "status_code": response.status_code,
                    "text": text[:max_length],
                    "truncated": truncated,
                    "elapsed_ms": round((perf_counter() - started_at) * 1000, 3),
                }
            errors.append(f"{filename}: HTTP {response.status_code}")
        raise RuntimeError(
            f"README not found for GitHub repository {owner}/{repo}. "
            f"Tried: {', '.join(errors)}"
        )


def _parse_github_repo(url: str) -> tuple[str, str]:
    parsed = urlsplit(url.strip())
    if parsed.scheme not in {"http", "https"} or parsed.hostname != "github.com":
        raise ValueError("'url' must be a public github.com repository URL")
    match = _GITHUB_REPO_RE.match(parsed.path.rstrip("/"))
    if match is None:
        raise ValueError("'url' must include GitHub owner and repository name")
    owner, repo = match.groups()
    repo = repo.removesuffix(".git")
    if not owner or not repo:
        raise ValueError("'url' must include GitHub owner and repository name")
    return owner, repo


__all__ = ["GitHubReadmeTool"]
