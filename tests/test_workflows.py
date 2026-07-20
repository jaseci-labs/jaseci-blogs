"""Structural tests for the GitHub Actions workflows.

These don't run the workflows (that needs GitHub) — they catch the failure modes
we *can* catch locally: malformed YAML, and syntax errors in the inline
`actions/github-script` blocks (which otherwise only surface at runtime).
"""

from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_DIR = REPO_ROOT / ".github" / "workflows"
WORKFLOWS = sorted(WORKFLOW_DIR.glob("*.yml"))

# GitHub substitutes ${{ ... }} before the JS runs; emulate that so node --check
# doesn't choke on the template-expression syntax inside JS strings.
EXPR_RE = re.compile(r"\$\{\{[^}]*\}\}")

# Stubs for the objects github-script injects, so the body parses/links cleanly.
JS_HARNESS = (
    "const github = new Proxy({}, { get: () => "
    "new Proxy(() => {}, { get: () => () => {} }) });\n"
    "github.paginate = async () => [];\n"
    "const context = { repo: { owner: 0, repo: 0 }, payload: {}, issue: {} };\n"
    "const core = { setOutput(){}, setFailed(){}, info(){}, error(){} };\n"
    "async function __main__() {\n"
)


def _iter_scripts(node):
    """Yield every inline github-script body in a parsed workflow."""
    if isinstance(node, dict):
        if isinstance(node.get("with"), dict):
            s = node["with"].get("script")
            if isinstance(s, str):
                yield node.get("name", "<unnamed step>"), s
        for v in node.values():
            yield from _iter_scripts(v)
    elif isinstance(node, list):
        for v in node:
            yield from _iter_scripts(v)


def test_workflows_exist():
    assert WORKFLOWS, "no workflow files found"


@pytest.mark.parametrize("wf", WORKFLOWS, ids=lambda p: p.name)
def test_workflow_yaml_parses(wf):
    yaml.safe_load(wf.read_text())


def _collect_scripts():
    out = []
    for wf in WORKFLOWS:
        for name, script in _iter_scripts(yaml.safe_load(wf.read_text())):
            out.append((wf.name, name, script))
    return out


SCRIPTS = _collect_scripts()


@pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")
@pytest.mark.parametrize(
    "wf_name,step_name,script",
    SCRIPTS,
    ids=[f"{w}::{s}" for w, s, _ in SCRIPTS],
)
def test_github_script_syntax(wf_name, step_name, script):
    body = JS_HARNESS + EXPR_RE.sub("EXPR", script) + "\n}\n"
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
        f.write(body)
        name = f.name
    proc = subprocess.run(["node", "--check", name], capture_output=True, text=True)
    assert proc.returncode == 0, f"{wf_name} :: {step_name}\n{proc.stderr}"
