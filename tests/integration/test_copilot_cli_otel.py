"""Exercise the installed Copilot CLI against a local OpenAI-compatible endpoint."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import threading
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from evaluator.backends.copilot import COPILOT_OTEL_FILENAME, CopilotBackend, parse_copilot_otel

REQUIRE_COPILOT_CLI = os.environ.get("TLAPS_BENCH_REQUIRE_COPILOT_CLI") == "1"


def _installed_copilot() -> str | None:
    binary = shutil.which("copilot")
    if binary is None:
        return None
    try:
        result = subprocess.run(
            [binary, "--help"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    help_text = f"{result.stdout}\n{result.stderr}"
    required_flags = ("--output-format", "--reasoning-effort", "--no-auto-update")
    return binary if result.returncode == 0 and all(flag in help_text for flag in required_flags) else None


COPILOT_BINARY = _installed_copilot()


@contextmanager
def _fake_openai_server():
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, _format, *_args):
            return

        def do_GET(self):
            payload = json.dumps({"data": []}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def do_POST(self):
            length = int(self.headers.get("Content-Length", "0"))
            self.rfile.read(length)
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            base = {
                "id": "chatcmpl-tlaps-bench-otel",
                "object": "chat.completion.chunk",
                "created": 1_784_443_000,
                "model": "gpt-4o",
            }
            events = [
                {
                    **base,
                    "choices": [
                        {
                            "index": 0,
                            "delta": {"role": "assistant", "content": "Done."},
                            "finish_reason": None,
                        }
                    ],
                },
                {
                    **base,
                    "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
                    "usage": {
                        "prompt_tokens": 123,
                        "completion_tokens": 7,
                        "total_tokens": 130,
                        "prompt_tokens_details": {"cached_tokens": 20},
                        "completion_tokens_details": {"reasoning_tokens": 2},
                    },
                },
            ]
            for event in events:
                self.wfile.write(f"data: {json.dumps(event)}\n\n".encode())
                self.wfile.flush()
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/v1"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def _tail(text: str, lines: int = 40) -> str:
    return "\n".join(line[:300] for line in text.splitlines()[-lines:]) or "<empty>"


def _listing(root: Path) -> str:
    files = [
        f"{path.relative_to(root)} ({path.stat().st_size} bytes)" for path in sorted(root.rglob("*")) if path.is_file()
    ]
    return "\n".join(files) or "<no files>"


def _run_for_report(args: list[str], **kwargs) -> str:
    try:
        run = subprocess.run(args, capture_output=True, text=True, timeout=45, **kwargs)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return f"<{type(exc).__name__}: {exc}>"
    return f"exit={run.returncode}\n--- stdout ---\n{_tail(run.stdout)}\n--- stderr ---\n{_tail(run.stderr)}"


def _missing_otel_report(binary, invocation, env, workspace, tmp_path, result) -> str:
    """Describe a successful Copilot run that wrote no OTel file, rerunning once with CLI logs enabled."""
    log_dir = tmp_path / "copilot-logs"
    debug_dir = tmp_path / "debug-results"
    debug_dir.mkdir()
    debug_invocation = list(invocation)
    level = debug_invocation.index("--log-level")
    debug_invocation[level + 1] = "all"
    debug_invocation[level:level] = ["--log-dir", str(log_dir)]
    debug_env = {**env, "COPILOT_OTEL_FILE_EXPORTER_PATH": str(debug_dir / COPILOT_OTEL_FILENAME)}
    debug_run = _run_for_report(debug_invocation, cwd=workspace, env=debug_env)
    logs = (
        "\n".join(path.read_text(errors="replace") for path in sorted(log_dir.rglob("*")) if path.is_file())
        if log_dir.is_dir()
        else ""
    )
    otel_lines = "\n".join(
        line
        for line in logs.splitlines()
        if re.search(r"otel|opentelemetry|exporter|span", line, re.I)
        and not re.search(r"github_telemetry|sdk_diagnostics", line)
    )
    otel_env = {key: value for key, value in env.items() if key.startswith(("COPILOT_OTEL", "OTEL_"))}
    host_keys = sorted(key for key in os.environ if key.startswith(("COPILOT", "OTEL", "GH_", "GITHUB_")))
    return "\n".join(
        [
            "Copilot CLI exited 0 but wrote no OTel file.",
            f"version: {_run_for_report([binary, '--version'], env=env)}",
            f"OTel env: {otel_env}",
            f"host env keys: {host_keys}",
            f"--- first run stdout ---\n{_tail(result.stdout)}",
            f"--- first run stderr ---\n{_tail(result.stderr)}",
            f"--- result dir ---\n{_listing(tmp_path / 'results')}",
            f"--- copilot home ---\n{_listing(tmp_path / 'copilot-home')}",
            f"--- debug rerun ---\n{debug_run}",
            f"--- debug result dir ---\n{_listing(debug_dir)}",
            f"--- debug log OTel lines ---\n{_tail(otel_lines, 80)}",
            f"--- debug log tail ---\n{_tail(logs, 60)}",
        ]
    )


@pytest.mark.skipif(
    COPILOT_BINARY is None and not REQUIRE_COPILOT_CLI,
    reason="installed Copilot CLI lacks the current benchmark interface",
)
def test_real_copilot_cli_writes_isolated_otel_with_prompt_flag(tmp_path):
    binary = COPILOT_BINARY
    assert binary is not None, "Copilot CLI is required"
    workspace = tmp_path / "workspace"
    result_dir = tmp_path / "results"
    copilot_home = tmp_path / "copilot-home"
    workspace.mkdir()
    result_dir.mkdir()
    copilot_home.mkdir()
    backend = CopilotBackend(model="gpt-4o")
    prompt = "Reply exactly Done. Do not use tools."

    with _fake_openai_server() as base_url:
        env = dict(os.environ)
        for key in ("COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"):
            env.pop(key, None)
        env.update(
            {
                "COPILOT_HOME": str(copilot_home),
                "COPILOT_PROVIDER_TYPE": "openai",
                "COPILOT_PROVIDER_BASE_URL": base_url,
                "COPILOT_PROVIDER_API_KEY": "test-key",
                "COPILOT_MODEL": "gpt-4o",
                "NO_PROXY": "127.0.0.1,localhost",
                # Simulate a hostile host configuration. Backend settings must
                # override both values and still produce the per-task file.
                "COPILOT_OTEL_ENABLED": "false",
                "COPILOT_OTEL_EXPORTER_TYPE": "otlp-http",
            }
        )
        env.update(backend.execution_environment(str(result_dir)))
        command = backend.build_command(str(workspace), str(result_dir))
        command[0] = binary
        invocation, stdin_data = backend.prepare_invocation(command, prompt)
        result = subprocess.run(
            invocation,
            input=stdin_data,
            capture_output=True,
            text=True,
            timeout=45,
            cwd=workspace,
            env=env,
        )
        otel_path = result_dir / COPILOT_OTEL_FILENAME
        if result.returncode == 0 and not (otel_path.is_file() and otel_path.stat().st_size > 0):
            pytest.fail(_missing_otel_report(binary, invocation, env, workspace, tmp_path, result))

    assert result.returncode == 0, result.stderr or result.stdout
    assert stdin_data is None
    assert invocation[-2:] == ["-p", prompt]

    raw_events = [json.loads(line) for line in otel_path.read_text().splitlines()]
    operations = {
        event.get("attributes", {}).get("gen_ai.operation.name")
        for event in raw_events
        if event.get("type") == "span" and isinstance(event.get("attributes"), dict)
    }
    assert {"chat", "invoke_agent"} <= operations
    assert prompt not in otel_path.read_text()

    usage = parse_copilot_otel(str(otel_path))
    assert usage is not None
    assert (usage.input_tokens, usage.output_tokens) == (123, 7)
    assert usage.model_requests == 1
