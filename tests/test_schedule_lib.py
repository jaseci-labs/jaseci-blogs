"""Unit tests for scripts/schedule_lib.py — the single writer of .schedule.yml.

These lock in the behaviours the release flow depends on: the draft-gate lint,
the un-draft guard primitive (check_draft), the schedule lifecycle (add ->
publish), date preservation on re-publish, takedown moves, and the bot-owned
header preservation.
"""

from __future__ import annotations

import datetime as dt

import pytest


# --------------------------------------------------------------------------- #
# check_draft  (backs the CI un-draft guard)
# --------------------------------------------------------------------------- #

def test_check_draft_true(sched, lib):
    p = sched.write_post("p.md", slug="p", draft=True)
    r = lib.check_draft(str(p))
    assert r == {"ok": True, "path": str(p), "exists": True, "is_post": True, "draft": True}


def test_check_draft_false(sched, lib):
    p = sched.write_post("p.md", slug="p", draft=False)
    assert lib.check_draft(str(p))["draft"] is False


def test_check_draft_no_draft_key(sched, lib):
    p = sched.write_post("p.md", slug="p", draft=None)
    r = lib.check_draft(str(p))
    assert r["is_post"] is True and r["draft"] is False


def test_check_draft_missing_file(sched, lib):
    r = lib.check_draft(str(sched.posts / "nope.md"))
    assert r["exists"] is False and r["is_post"] is False and r["draft"] is False


def test_check_draft_not_a_post(sched, lib, tmp_path):
    f = tmp_path / "plain.md"
    f.write_text("# no frontmatter here\n")
    r = lib.check_draft(str(f))
    assert r["is_post"] is False and r["draft"] is False


def test_undraft_guard_logic(sched, lib):
    """Base draft + head non-draft is the exact transition the CI guard blocks."""
    base = sched.write_post("base.md", slug="x", draft=True)
    head = sched.write_post("head.md", slug="x", draft=False)
    base_draft = lib.check_draft(str(base))["draft"]
    head_draft = lib.check_draft(str(head))["draft"]
    assert base_draft is True and head_draft is False  # -> guard should fail the PR


# --------------------------------------------------------------------------- #
# lint_new_posts  (the PR draft gate)
# --------------------------------------------------------------------------- #

def test_lint_passes_with_draft(sched, lib):
    p = sched.write_post("p.md", slug="p", draft=True)
    assert lib.lint_new_posts([str(p)])["ok"] is True


def test_lint_fails_without_draft(sched, lib):
    p = sched.write_post("p.md", slug="p", draft=False)
    r = lib.lint_new_posts([str(p)])
    assert r["ok"] is False and r["failures"][0]["path"] == str(p)


def test_lint_fails_no_frontmatter(sched, lib):
    p = sched.posts / "p.md"
    p.write_text("# just a heading\n")
    r = lib.lint_new_posts([str(p)])
    assert r["ok"] is False and "frontmatter" in r["failures"][0]["error"]


def test_lint_ignores_non_post_paths(sched, lib, tmp_path):
    outside = tmp_path / "README.md"
    outside.write_text("hi")
    r = lib.lint_new_posts([str(outside)])
    assert r["ok"] is True and r["checked"] == []


# --------------------------------------------------------------------------- #
# find_post  (slug-first, filename fallback)
# --------------------------------------------------------------------------- #

def test_find_post_by_slug(sched, lib):
    sched.write_post("file-name.md", slug="real-slug")
    assert lib.find_post("real-slug").meta["slug"] == "real-slug"


def test_find_post_filename_fallback(sched, lib):
    sched.write_post("stem.md", slug=None)
    assert lib.find_post("stem").path.name == "stem.md"


def test_find_post_missing_raises(sched, lib):
    with pytest.raises(lib.UserError):
        lib.find_post("ghost")


def test_find_post_duplicate_slug_raises(sched, lib):
    sched.write_post("a.md", slug="dup")
    sched.write_post("b.md", slug="dup")
    with pytest.raises(lib.UserError, match="Multiple posts"):
        lib.find_post("dup")


# --------------------------------------------------------------------------- #
# add / hold / cancel
# --------------------------------------------------------------------------- #

def _future():
    return (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")


def test_add_creates_scheduled_entry(sched, lib):
    sched.write_post("p.md", slug="p", draft=True)
    r = lib.add("p", _future(), actor="alice", notes="later")
    assert r["ok"] and r["entry"]["status"] == "scheduled"
    entry = sched.read_schedule()[0]
    assert entry["slug"] == "p" and entry["added_by"] == "alice" and entry["notes"] == "later"


def test_add_forces_draft_true(sched, lib):
    sched.write_post("p.md", slug="p", draft=False)
    lib.add("p", _future(), actor="a")
    assert lib.check_draft(str(sched.posts / "p.md"))["draft"] is True


def test_add_rejects_past(sched, lib):
    sched.write_post("p.md", slug="p")
    with pytest.raises(lib.UserError, match="not in the future"):
        lib.add("p", "2020-01-01T00:00:00Z", actor="a")


def test_add_rejects_duplicate(sched, lib):
    sched.write_post("p.md", slug="p")
    lib.add("p", _future(), actor="a")
    with pytest.raises(lib.UserError, match="already in the schedule"):
        lib.add("p", _future(), actor="a")


def test_cancel_then_reschedule(sched, lib):
    sched.write_post("p.md", slug="p")
    lib.add("p", _future(), actor="a")
    lib.cancel("p", actor="a")
    assert sched.read_schedule()[0]["status"] == "cancelled"
    # cancelling frees the slug for a fresh schedule
    lib.add("p", _future(), actor="a")
    assert sched.read_schedule()[-1]["status"] == "scheduled"


# --------------------------------------------------------------------------- #
# publish lifecycle + date preservation
# --------------------------------------------------------------------------- #

def test_publish_now_removes_draft_and_dates(sched, lib):
    sched.write_post("p.md", slug="p", draft=True, date=None)
    r = lib.publish_now("p", actor="ed")
    assert r["first_publish"] is True
    meta = lib.check_draft(str(sched.posts / "p.md"))
    assert meta["draft"] is False
    text = (sched.posts / "p.md").read_text()
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()
    assert today in text  # yaml may quote it (date: '2026-06-01'); just assert presence


def test_publish_due_only_publishes_past(sched, lib):
    sched.write_post("due.md", slug="due", draft=True)
    sched.write_post("later.md", slug="later", draft=True)
    lib.add("due", _future(), actor="a")
    lib.add("later", _future(), actor="a")
    # backdate the "due" entry directly via the schedule file
    data = lib.load_schedule()
    for e in data["schedule"]:
        if e["slug"] == "due":
            e["publish_at"] = "2020-01-01T00:00:00Z"
    lib.save_schedule(data)

    r = lib.publish_due(actor="auto")
    assert [p["slug"] for p in r["published"]] == ["due"]
    assert lib.check_draft(str(sched.posts / "due.md"))["draft"] is False
    assert lib.check_draft(str(sched.posts / "later.md"))["draft"] is True


def test_republish_preserves_original_date(sched, lib):
    sched.write_post("p.md", slug="p", draft=True, date=None)
    lib.publish_now("p", actor="ed")               # first publish -> dates to today
    first_date = (sched.posts / "p.md").read_text()
    # simulate a hide then re-publish
    lib.takedown("p", destination="draft", actor="ed")
    lib.publish_now("p", actor="ed")               # re-publish must NOT move the date
    assert (sched.posts / "p.md").read_text().count("date:") == 1
    # the date line is unchanged from the first publish
    import re
    d1 = re.search(r"date: (\S+)", first_date).group(1)
    d2 = re.search(r"date: (\S+)", (sched.posts / "p.md").read_text()).group(1)
    assert d1 == d2


# --------------------------------------------------------------------------- #
# takedown
# --------------------------------------------------------------------------- #

def test_takedown_draft_keeps_file(sched, lib):
    sched.write_post("p.md", slug="p", draft=False)
    r = lib.takedown("p", destination="draft", actor="ed", reason="oops")
    assert r["entry"]["status"] == "hidden"
    assert (sched.posts / "p.md").exists()
    assert lib.check_draft(str(sched.posts / "p.md"))["draft"] is True


def test_takedown_archive_moves_file(sched, lib):
    sched.write_post("p.md", slug="p", draft=False)
    lib.takedown("p", destination="archive", actor="ed")
    assert not (sched.posts / "p.md").exists()
    assert (sched.archived / "p.md").exists()


def test_takedown_unlist_moves_and_drafts(sched, lib):
    sched.write_post("p.md", slug="p", draft=False)
    lib.takedown("p", destination="unlist", actor="ed")
    moved = sched.unlisted / "p.md"
    assert moved.exists() and not (sched.posts / "p.md").exists()
    assert lib.check_draft(str(moved))["draft"] is True


# --------------------------------------------------------------------------- #
# the bot-owned header invariant
# --------------------------------------------------------------------------- #

def test_save_schedule_preserves_header(sched, lib):
    sched.write_post("p.md", slug="p")
    lib.add("p", _future(), actor="a")
    raw = sched.schedule.read_text()
    assert raw.startswith("# Bot-owned schedule file. Do not hand-edit.")
    assert "schedule:" in raw


# --------------------------------------------------------------------------- #
# parse_iso
# --------------------------------------------------------------------------- #

@pytest.mark.parametrize("value", ["2026-06-01T14:00:00Z", "2026-06-01T14:00:00+00:00"])
def test_parse_iso_accepts(value, lib):
    assert lib.parse_iso(value).tzinfo is not None


def test_parse_iso_rejects_garbage(lib):
    with pytest.raises(lib.UserError):
        lib.parse_iso("not-a-date")
