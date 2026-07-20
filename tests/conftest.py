"""Shared fixtures for the editorial-tooling test suite.

The scheduler reads/writes real paths derived from its module location, so the
`sched` fixture redirects every one of those constants at an isolated tmp repo
and seeds a `.schedule.yml` with the same header-comment shape the real file has
(so the bot-owned header-preservation invariant is exercised).
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import schedule_lib  # noqa: E402


SCHEDULE_HEADER = "# Bot-owned schedule file. Do not hand-edit.\n#\n"


class SchedEnv:
    """Handle to an isolated scheduler sandbox."""

    def __init__(self, root: Path):
        self.root = root
        self.posts = root / "docs" / "blog" / "posts"
        self.archived = root / "docs" / "blog" / "archived_posts"
        self.unlisted = root / "docs" / "blog" / "unlisted"
        self.schedule = root / "docs" / "blog" / ".schedule.yml"

    def write_post(
        self,
        filename: str,
        *,
        slug: str | None = None,
        draft: bool | None = True,
        date: str | None = "2026-01-01",
        title: str = "A Test Post",
        body: str = "# A Test Post\n\nHello.\n",
    ) -> Path:
        lines = ["---"]
        if date is not None:
            lines.append(f"date: {date}")
        if slug is not None:
            lines.append(f"slug: {slug}")
        lines.append(f"title: {title}")
        if draft is not None:
            lines.append(f"draft: {'true' if draft else 'false'}")
        lines.append("---")
        path = self.posts / filename
        path.write_text("\n".join(lines) + "\n" + body)
        return path

    def read_schedule(self) -> list[dict]:
        return schedule_lib.load_schedule()["schedule"]


@pytest.fixture
def sched(tmp_path, monkeypatch) -> SchedEnv:
    env = SchedEnv(tmp_path)
    env.posts.mkdir(parents=True)
    env.archived.mkdir(parents=True)
    env.unlisted.mkdir(parents=True)
    env.schedule.write_text(SCHEDULE_HEADER + "schedule: []\n")

    monkeypatch.setattr(schedule_lib, "REPO_ROOT", env.root)
    monkeypatch.setattr(schedule_lib, "POSTS_DIR", env.posts)
    monkeypatch.setattr(schedule_lib, "ARCHIVED_DIR", env.archived)
    monkeypatch.setattr(schedule_lib, "UNLISTED_DIR", env.unlisted)
    monkeypatch.setattr(schedule_lib, "SCHEDULE_PATH", env.schedule)
    # TAKEDOWN_DESTINATIONS captured the original Path objects at import time —
    # rebuild it so takedown writes into the sandbox.
    monkeypatch.setattr(
        schedule_lib,
        "TAKEDOWN_DESTINATIONS",
        {"archive": env.archived, "unlist": env.unlisted, "draft": None},
    )
    return env


@pytest.fixture
def lib():
    return schedule_lib
