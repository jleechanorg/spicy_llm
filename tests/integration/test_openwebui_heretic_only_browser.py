#!/usr/bin/env python3
"""Browser integration proof for the live spicy OpenWebUI model picker.

This test follows the same evidence shape as the WorldArchitect testing_ui
browser tests: Playwright drives a real browser, records .webm video, writes a
.vtt caption track, captures screenshots, and emits a manifest with checks.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from playwright.sync_api import expect, sync_playwright


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OPENWEBUI_URL = "https://spicy-openwebui-elhm2qjlta-uc.a.run.app/"
DEFAULT_BACKEND_URL = "https://spicy-llm-backend-elhm2qjlta-uc.a.run.app/"
EXPECTED_MODEL = "spicy-heretic:latest"


class CaptionTrack:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.start_time = time.monotonic()
        self.cues: list[tuple[float, float, str]] = []

    def add(self, text: str, duration: float = 2.0) -> None:
        start = max(0.0, time.monotonic() - self.start_time)
        end = start + duration
        self.cues.append((start, end, text))

    def write(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        lines = ["WEBVTT", ""]
        for index, (start, end, text) in enumerate(self.cues, start=1):
            lines.extend(
                [
                    str(index),
                    f"{_format_vtt_time(start)} --> {_format_vtt_time(end)}",
                    text,
                    "",
                ]
            )
        self.path.write_text("\n".join(lines), encoding="utf-8")


def _format_vtt_time(seconds: float) -> str:
    millis = int(round(seconds * 1000))
    hours, rem = divmod(millis, 3_600_000)
    minutes, rem = divmod(rem, 60_000)
    secs, ms = divmod(rem, 1000)
    return f"{hours:02}:{minutes:02}:{secs:02}.{ms:03}"


def _iso_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _json_get(url: str, timeout_s: int = 180) -> dict[str, Any]:
    import urllib.request

    with urllib.request.urlopen(url, timeout=timeout_s) as response:
        return json.loads(response.read().decode("utf-8"))


def _model_names_from_tags(tags: dict[str, Any]) -> list[str]:
    return sorted(
        model.get("name") or model.get("model")
        for model in tags.get("models", [])
        if model.get("name") or model.get("model")
    )


def _wait_for_backend_model(backend_url: str, expected_model: str, timeout_s: int = 480) -> tuple[list[str], list[dict[str, Any]]]:
    """Poll Ollama tags because Cloud Run backend filesystems are ephemeral."""
    deadline = time.monotonic() + timeout_s
    attempts: list[dict[str, Any]] = []
    last_names: list[str] = []
    attempt = 0
    while time.monotonic() < deadline:
        attempt += 1
        try:
            tags = _json_get(f"{backend_url}api/tags", timeout_s=120)
            last_names = _model_names_from_tags(tags)
            attempts.append(
                {
                    "attempt": attempt,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "models": last_names,
                }
            )
            if expected_model in last_names:
                return last_names, attempts
        except Exception as exc:  # pragma: no cover - recorded for live diagnostics
            attempts.append(
                {
                    "attempt": attempt,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "error": repr(exc),
                }
            )
        time.sleep(15)
    return last_names, attempts


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")


def _env_first(*names: str) -> str | None:
    for name in names:
        value = os.getenv(name)
        if value:
            return value
    return None


def _login_if_needed(page: Any, captions: CaptionTrack, screenshots_dir: Path, result: dict[str, Any]) -> None:
    password_inputs = page.locator("input[type='password']").count()
    signin_text = page.get_by_text("Sign in to Open WebUI").count()
    if password_inputs == 0 and signin_text == 0:
        result["auth"] = {"required": False}
        return

    email = _env_first("SPICY_OPENWEBUI_EMAIL", "OPENWEBUI_EMAIL", "OPEN_WEBUI_EMAIL")
    password = _env_first("SPICY_OPENWEBUI_PASSWORD", "OPENWEBUI_PASSWORD", "OPEN_WEBUI_PASSWORD")
    result["auth"] = {
        "required": True,
        "mode": "env_credentials" if email and password else "missing_env_credentials",
        "email_env_set": bool(email),
        "password_env_set": bool(password),
    }
    page.screenshot(path=str(screenshots_dir / "00_login_required.png"), full_page=True)
    if not email or not password:
        raise RuntimeError(
            "OpenWebUI requires login for this browser test. Set "
            "SPICY_OPENWEBUI_EMAIL and SPICY_OPENWEBUI_PASSWORD, or set "
            "SPICY_OPENWEBUI_STORAGE_STATE to a Playwright storage_state JSON file."
        )

    captions.add("Authenticate to OpenWebUI using test credentials from environment variables.")
    email_input = page.locator("input[type='email'], input[placeholder='Enter Your Email']").first
    password_input = page.locator("input[type='password'], input[placeholder='Enter Your Password']").first
    email_input.fill(email)
    password_input.fill(password)
    page.get_by_role("button", name="Sign in").click()
    page.wait_for_load_state("networkidle", timeout=60_000)
    expect(page.locator("input[type='password']")).to_have_count(0, timeout=60_000)
    captions.add("Authenticated session reached the chat UI.")


def _openwebui_model_snapshot(page: Any) -> dict[str, Any]:
    return page.evaluate(
        """async () => {
            const modelsResponse = await fetch('/api/models?refresh=true', {credentials: 'include'});
            const modelsBody = await modelsResponse.json();
            const tagsResponse = await fetch('/ollama/api/tags', {credentials: 'include'});
            const tagsBody = await tagsResponse.json();
            return {
                apiModels: (modelsBody.data || []).map((m) => ({
                    id: m.id,
                    name: m.name,
                    owned_by: m.owned_by,
                    arena: Boolean(m.arena)
                })),
                proxiedTags: (tagsBody.models || []).map((m) => m.name || m.model).sort()
            };
        }"""
    )


def _wait_for_openwebui_model(page: Any, expected_model: str, timeout_s: int = 180) -> tuple[list[dict[str, Any]], list[str], list[dict[str, Any]]]:
    deadline = time.monotonic() + timeout_s
    attempts: list[dict[str, Any]] = []
    last_models: list[dict[str, Any]] = []
    last_tags: list[str] = []
    attempt = 0

    while time.monotonic() < deadline:
        attempt += 1
        snapshot = _openwebui_model_snapshot(page)
        last_models = snapshot["apiModels"]
        last_tags = snapshot["proxiedTags"]
        api_model_ids = sorted(model["id"] for model in last_models)
        attempts.append(
            {
                "attempt": attempt,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "api_model_ids": api_model_ids,
                "proxied_tags": last_tags,
            }
        )
        if api_model_ids == [expected_model] and last_tags == [expected_model]:
            return last_models, last_tags, attempts
        if attempt % 2 == 0:
            page.reload(wait_until="domcontentloaded")
        time.sleep(10)

    return last_models, last_tags, attempts


def _try_make_captioned_mp4(webm_path: Path, vtt_path: Path, mp4_path: Path) -> str | None:
    if not shutil.which("ffmpeg"):
        return "ffmpeg not found"
    if not webm_path.exists() or not vtt_path.exists():
        return "missing webm or vtt input"

    command = [
        "ffmpeg",
        "-y",
        "-i",
        str(webm_path),
        "-vf",
        f"subtitles={vtt_path}",
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(mp4_path),
    ]
    completed = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if completed.returncode != 0:
        return completed.stderr[-1000:]
    return None


def run_openwebui_heretic_only_browser_test(
    openwebui_url: str | None = None,
    backend_url: str | None = None,
    evidence_root: Path | None = None,
) -> dict[str, Any]:
    openwebui_url = (openwebui_url or os.getenv("SPICY_OPENWEBUI_URL") or DEFAULT_OPENWEBUI_URL).rstrip("/") + "/"
    backend_url = (backend_url or os.getenv("SPICY_BACKEND_URL") or DEFAULT_BACKEND_URL).rstrip("/") + "/"
    run_id = _iso_run_id()
    evidence_dir = evidence_root or REPO_ROOT / "results" / "openwebui-heretic-only-browser" / run_id
    video_dir = evidence_dir / "videos"
    screenshots_dir = evidence_dir / "screenshots"
    captions_path = video_dir / "openwebui_heretic_only.vtt"
    manifest_path = evidence_dir / "manifest.json"
    captions = CaptionTrack(captions_path)

    result: dict[str, Any] = {
        "run_id": run_id,
        "openwebui_url": openwebui_url,
        "backend_url": backend_url,
        "expected_model": EXPECTED_MODEL,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "checks": [],
        "artifacts": {},
    }

    captions.add("Wait for the Ollama backend to expose the tuned Heretic alias.")
    screenshots_dir.mkdir(parents=True, exist_ok=True)
    video_dir.mkdir(parents=True, exist_ok=True)

    backend_model_names, backend_poll_attempts = _wait_for_backend_model(backend_url, EXPECTED_MODEL)
    result["backend_model_names"] = backend_model_names
    result["backend_poll_attempts"] = backend_poll_attempts
    backend_has_expected = EXPECTED_MODEL in backend_model_names
    result["checks"].append({"name": "backend_has_expected_model", "passed": backend_has_expected})
    _write_json(manifest_path, result)
    assert backend_has_expected, f"Backend tags missing {EXPECTED_MODEL}: {backend_model_names}"
    captions.add("Open the live OpenWebUI deployment.")

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"])
        storage_state = os.getenv("SPICY_OPENWEBUI_STORAGE_STATE")
        if storage_state:
            result["auth"] = {"required": "unknown", "mode": "storage_state", "storage_state_path": storage_state}
        context = browser.new_context(
            viewport={"width": 1280, "height": 900},
            record_video_dir=str(video_dir),
            record_video_size={"width": 1280, "height": 900},
            storage_state=storage_state or None,
        )
        page = context.new_page()
        page.set_default_timeout(60_000)
        page.set_default_navigation_timeout(60_000)

        try:
            page.goto(f"{openwebui_url}?integration=heretic-only-{run_id}", wait_until="domcontentloaded")
            page.wait_for_load_state("networkidle", timeout=60_000)
            _login_if_needed(page, captions, screenshots_dir, result)
            captions.add("The chat page loads with the Heretic alias selected.")
            page.screenshot(path=str(screenshots_dir / "01_loaded.png"), full_page=True)

            captions.add("Refresh OpenWebUI's model cache until the Heretic alias is visible.")
            api_models, proxied_tags, openwebui_poll_attempts = _wait_for_openwebui_model(page, EXPECTED_MODEL)
            result["api_models"] = api_models
            result["proxied_ollama_tags"] = proxied_tags
            result["openwebui_poll_attempts"] = openwebui_poll_attempts

            api_model_ids = sorted(model["id"] for model in api_models)
            result["checks"].append(
                {"name": "api_models_only_expected", "passed": api_model_ids == [EXPECTED_MODEL], "actual": api_model_ids}
            )
            result["checks"].append(
                {
                    "name": "proxied_tags_only_expected",
                    "passed": proxied_tags == [EXPECTED_MODEL],
                    "actual": proxied_tags,
                }
            )
            assert api_model_ids == [EXPECTED_MODEL], f"OpenWebUI /api/models returned {api_model_ids}"
            assert proxied_tags == [EXPECTED_MODEL], f"OpenWebUI /ollama/api/tags returned {proxied_tags}"

            selector = page.locator(f"button[aria-label='Selected model: {EXPECTED_MODEL}']")
            expect(selector).to_be_visible()
            captions.add("The visible selector names only spicy-heretic:latest.")
            selector.click()
            page.screenshot(path=str(screenshots_dir / "02_picker_open.png"), full_page=True)

            options = page.locator('[role="option"]').all_inner_texts()
            normalized_options = [" ".join(option.split()) for option in options]
            result["picker_options"] = normalized_options
            result["checks"].append(
                {
                    "name": "picker_only_expected_model",
                    "passed": normalized_options == [f"{EXPECTED_MODEL} 20.9B"],
                    "actual": normalized_options,
                }
            )
            assert normalized_options == [f"{EXPECTED_MODEL} 20.9B"], normalized_options
            captions.add("The dropdown contains one available model and no Arena option.")

        except Exception as exc:
            result["passed"] = False
            result["error"] = repr(exc)
            captions.add("The browser proof failed before all assertions passed.", duration=2.0)
            raise
        finally:
            context.close()
            browser.close()
            captions.write()
            webm_files = sorted(video_dir.glob("*.webm"))
            mp4_path = video_dir / "openwebui_heretic_only_captioned.mp4"
            ffmpeg_error = _try_make_captioned_mp4(webm_files[0], captions_path, mp4_path) if webm_files else "no webm input"
            result["artifacts"]["videos"] = [str(path) for path in webm_files]
            result["artifacts"]["captions"] = [str(captions_path)]
            result["artifacts"]["screenshots"] = [str(path) for path in sorted(screenshots_dir.glob("*.png"))]
            if mp4_path.exists():
                result["artifacts"]["captioned_mp4"] = str(mp4_path)
            else:
                result["artifacts"]["captioned_mp4_error"] = ffmpeg_error
            result["finished_at"] = datetime.now(timezone.utc).isoformat()
            _write_json(manifest_path, result)

    captions.add("Test completed and artifacts were written.", duration=1.5)
    captions.write()

    webm_files = sorted(video_dir.glob("*.webm"))
    result["artifacts"]["videos"] = [str(path) for path in webm_files]
    result["artifacts"]["captions"] = [str(captions_path)]
    result["artifacts"]["screenshots"] = [str(path) for path in sorted(screenshots_dir.glob("*.png"))]
    assert webm_files, f"No Playwright video was recorded in {video_dir}"
    assert captions_path.exists(), f"No caption track was written at {captions_path}"

    mp4_path = video_dir / "openwebui_heretic_only_captioned.mp4"
    ffmpeg_error = _try_make_captioned_mp4(webm_files[0], captions_path, mp4_path)
    if mp4_path.exists():
        result["artifacts"]["captioned_mp4"] = str(mp4_path)
    else:
        result["artifacts"]["captioned_mp4_error"] = ffmpeg_error

    result["finished_at"] = datetime.now(timezone.utc).isoformat()
    result["passed"] = all(check["passed"] for check in result["checks"])
    _write_json(manifest_path, result)
    result["artifacts"]["manifest"] = str(manifest_path)

    assert result["passed"], result
    return result


def test_live_openwebui_exposes_only_spicy_heretic() -> None:
    run_openwebui_heretic_only_browser_test()


if __name__ == "__main__":
    manifest = run_openwebui_heretic_only_browser_test()
    print(json.dumps(manifest, indent=2, sort_keys=True))
