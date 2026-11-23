"""Lock ZooKeeper LocalPrimaryOrder to the intended broadcast-order property.

The Remix/Zab comment is: if a primary broadcasts a before b, a follower that
delivers b also delivers a before b. Two encodings fail that:

- ``\\E txn1, txn2 \\in txn_set`` plus reflexive TxnEqual is true as soon as
  the set is nonempty.
- ``lastCommitted[j].index >= 2`` in the implication skips a follower whose
  log is only ``<<b>>``.

The shipped formula must quantify over every pair, treat delivery of b as
the antecedent, and parenthesize that ``\\E`` so it does not swallow ``=>``.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]

LOW_LEVEL_SOURCE = REPO_ROOT / "source" / "ZooKeeper_LowLevel" / "ZkV3_7_0.tla"
LPO_FILES = (
    REPO_ROOT / "source" / "ZooKeeper" / "Zab.tla",
    LOW_LEVEL_SOURCE,
    REPO_ROOT / "benchmark" / "proof-from-scratch" / "ZooKeeper" / "Zab_LocalPrimaryOrderDefs.tla",
    REPO_ROOT / "benchmark" / "proof-from-scratch" / "ZooKeeper_LowLevel" / "ZkV3_7_0_LocalPrimaryOrderDefs.tla",
)

EXISTS_PAIR = r"\E txn1, txn2 \in txn_set"
FORALL_PAIR = r"\A txn1, txn2 \in txn_set"

TLC_MODULE = REPO_ROOT / "tests" / "dataset" / "LPOQuantifierCheck.tla"
TLC_CONFIG = REPO_ROOT / "tests" / "dataset" / "LPOQuantifierCheck.cfg"
TLA2TOOLS = REPO_ROOT / "lib" / "tla2tools.jar"


def _local_primary_order_body(text: str) -> str:
    start = text.index("LocalPrimaryOrder ==")
    rest = text[start:]
    ends = []
    for marker in ("\nTHEOREM ", "\n===="):
        idx = rest.find(marker)
        if idx != -1:
            ends.append(idx)
    return rest[: min(ends)] if ends else rest


def test_local_primary_order_quantifies_over_every_broadcast_pair():
    for path in LPO_FILES:
        body = _local_primary_order_body(path.read_text(encoding="utf-8"))
        assert EXISTS_PAIR not in body, f"{path} still uses existential pair quantification"
        assert FORALL_PAIR in body, f"{path} is missing forall-pairs LocalPrimaryOrder"
        bound = "Len(confirmedHistory[j])" if path == LOW_LEVEL_SOURCE else "lastCommitted[j].index"
        assert f"{bound} >= 2" not in body, f"{path} still skips followers with just one delivery"
        assert rf"(\E idx \in 1..{bound}" in body, (
            f"{path} must parenthesize the delivery check so \\E does not bind =>"
        )


def test_local_primary_order_fails_when_follower_delivered_only_b():
    java = shutil.which("java")
    if java is None:
        pytest.skip("java is required to evaluate the LocalPrimaryOrder TLC fixture")
    if not TLA2TOOLS.is_file():
        pytest.skip(f"missing {TLA2TOOLS}")

    result = subprocess.run(
        [
            java,
            "-XX:+UseParallelGC",
            "-cp",
            str(TLA2TOOLS),
            "tlc2.TLC",
            "-deadlock",
            "-nowarning",
            "-config",
            str(TLC_CONFIG),
            str(TLC_MODULE),
        ],
        check=False,
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
        env={**os.environ, "JAVA_TOOL_OPTIONS": ""},
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0, output
    assert "No error has been found" in output
    assert "Assumption" not in output
