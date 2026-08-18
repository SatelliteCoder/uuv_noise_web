# -*- coding: utf-8 -*-
from __future__ import annotations

import copy
import json
import mimetypes
import os
import re
import shutil
import subprocess
import threading
import time
import uuid
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


ROOT_DIR = Path(__file__).resolve().parents[1]
FRONTEND_DIR = ROOT_DIR / "frontend"
MODEL_DIR = ROOT_DIR / "matlab_model"
JOBS_DIR = ROOT_DIR / "jobs"
RUNTIME_DIR = ROOT_DIR / "runtime"
MATLAB_PREFDIR = RUNTIME_DIR / "matlab_pref"

SOURCE_TYPES = ("point", "line", "surface", "volume")
SOURCE_LABELS = {
    "point": "点源",
    "line": "线源",
    "surface": "面源",
    "volume": "体源",
    "all": "全部四类",
}


def now_iso() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def clamp_number(value, default: float, minimum: float, maximum: float) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        number = default
    if number != number:
        number = default
    return max(minimum, min(maximum, number))


def clamp_int(value, default: int, minimum: int, maximum: int) -> int:
    return int(round(clamp_number(value, default, minimum, maximum)))


def nested(data: dict, key: str) -> dict:
    value = data.get(key)
    return value if isinstance(value, dict) else {}


def normalize_config(data: dict) -> dict:
    raw_source_type = str(data.get("source_type", "point")).strip().lower()
    if raw_source_type not in (*SOURCE_TYPES, "all"):
        raw_source_type = "point"

    uuv = nested(data, "uuv")
    source = nested(data, "source")
    receiver = nested(data, "receiver")
    ambient = nested(data, "ambient")

    return {
        "source_type": raw_source_type,
        "fs": clamp_int(data.get("fs"), 24000, 8000, 96000),
        "duration_s": clamp_number(data.get("duration_s"), 4.0, 1.0, 60.0),
        "random_seed": clamp_int(data.get("random_seed"), 20260817, 1, 999999999),
        "uuv": {
            "length_m": clamp_number(uuv.get("length_m"), 3.2, 0.3, 30.0),
            "diameter_m": clamp_number(uuv.get("diameter_m"), 0.45, 0.05, 5.0),
            "depth_m": clamp_number(uuv.get("depth_m"), 50.0, 1.0, 1000.0),
            "speed_mps": clamp_number(uuv.get("speed_mps"), 3.0, 0.0, 25.0),
            "rpm": clamp_number(uuv.get("rpm"), 720.0, 10.0, 5000.0),
            "blade_count": clamp_int(uuv.get("blade_count"), 4, 2, 12),
            "propeller_diameter_m": clamp_number(
                uuv.get("propeller_diameter_m"), 0.24, 0.03, 5.0
            ),
        },
        "source": {
            "heading_deg": clamp_number(source.get("heading_deg"), 20.0, -180.0, 180.0),
            "line_elements": clamp_int(source.get("line_elements"), 21, 3, 81),
            "surface_axial_elements": clamp_int(
                source.get("surface_axial_elements"), 10, 3, 40
            ),
            "surface_circum_elements": clamp_int(
                source.get("surface_circum_elements"), 8, 4, 48
            ),
            "volume_axial_elements": clamp_int(
                source.get("volume_axial_elements"), 6, 3, 30
            ),
            "volume_radial_elements": clamp_int(
                source.get("volume_radial_elements"), 2, 1, 8
            ),
            "volume_circum_elements": clamp_int(
                source.get("volume_circum_elements"), 8, 4, 48
            ),
        },
        "receiver": {
            "x_m": clamp_number(receiver.get("x_m"), 600.0, -10000.0, 10000.0),
            "y_m": clamp_number(receiver.get("y_m"), 160.0, -10000.0, 10000.0),
            "z_m": clamp_number(receiver.get("z_m"), -45.0, -1000.0, 100.0),
        },
        "ambient": {
            "enabled": bool(ambient.get("enabled", True)),
            "rms_uPa": clamp_number(ambient.get("rms_uPa"), 800.0, 0.0, 100000.0),
            "slope_db_decade": clamp_number(
                ambient.get("slope_db_decade"), -17.0, -40.0, 10.0
            ),
        },
    }


def matlab_literal(path: Path) -> str:
    return str(path).replace("'", "''")


def add_urls_to_case(job_id: str, case_summary: dict, case_folder: str) -> dict:
    files = case_summary.get("files", {})
    if not isinstance(files, dict):
        files = {}
    prefix = f"/jobs/{job_id}/"
    if case_folder:
        prefix += f"{case_folder}/"
    case_summary["file_urls"] = {key: prefix + name for key, name in files.items()}
    return case_summary


def update_job(job_id: str, patch: dict) -> dict:
    path = JOBS_DIR / job_id / "job.json"
    job = read_json(path)
    job.update(patch)
    job["updated_at"] = now_iso()
    write_json(path, job)
    return job


def run_matlab_case(job_id: str, case_type: str, base_config: dict, case_output_dir: Path) -> dict:
    case_output_dir.mkdir(parents=True, exist_ok=True)
    config = copy.deepcopy(base_config)
    config["source_type"] = case_type
    config_path = case_output_dir / "input_config.json"
    write_json(config_path, config)

    log_path = case_output_dir / "matlab_stdout.log"
    batch_call = (
        "web_run_case("
        f"'{matlab_literal(config_path)}',"
        f"'{matlab_literal(case_output_dir)}'"
        ")"
    )

    env = os.environ.copy()
    MATLAB_PREFDIR.mkdir(parents=True, exist_ok=True)
    env["MATLAB_PREFDIR"] = str(MATLAB_PREFDIR)

    started = time.time()
    with log_path.open("w", encoding="utf-8", errors="replace") as log_file:
        process = subprocess.run(
            ["matlab", "-batch", batch_call],
            cwd=str(MODEL_DIR),
            stdout=log_file,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=1200,
            env=env,
        )

    if process.returncode != 0:
        tail = log_path.read_text(encoding="utf-8", errors="replace")[-4000:]
        raise RuntimeError(f"{case_type} MATLAB run failed, return code {process.returncode}\n{tail}")

    summary_path = case_output_dir / "web_result_summary.json"
    if not summary_path.exists():
        raise RuntimeError(f"{case_type} finished but web_result_summary.json was not produced.")

    summary = read_json(summary_path)
    summary["source_type_label"] = SOURCE_LABELS.get(case_type, case_type)
    summary["elapsed_s"] = round(time.time() - started, 2)
    summary["log_file"] = "matlab_stdout.log"
    case_folder = case_type if base_config["source_type"] == "all" else ""
    return add_urls_to_case(job_id, summary, case_folder)


def run_job(job_id: str) -> None:
    job_dir = JOBS_DIR / job_id
    try:
        config = read_json(job_dir / "input_config.json")
        update_job(job_id, {"status": "running", "started_at": now_iso(), "message": "MATLAB 正在计算"})

        if shutil.which("matlab") is None:
            raise RuntimeError("没有找到 matlab 命令，请确认 MATLAB 已加入系统 PATH。")

        requested = config["source_type"]
        case_types = SOURCE_TYPES if requested == "all" else (requested,)
        cases = []
        for index, case_type in enumerate(case_types, start=1):
            update_job(
                job_id,
                {
                    "message": f"正在运行 {SOURCE_LABELS[case_type]} ({index}/{len(case_types)})",
                    "current_case": case_type,
                },
            )
            case_output_dir = job_dir / case_type if requested == "all" else job_dir
            cases.append(run_matlab_case(job_id, case_type, config, case_output_dir))

        summary = {
            "job_id": job_id,
            "mode": requested,
            "mode_label": SOURCE_LABELS.get(requested, requested),
            "finished_at": now_iso(),
            "cases": cases,
        }
        write_json(job_dir / "web_job_summary.json", summary)
        update_job(
            job_id,
            {
                "status": "succeeded",
                "finished_at": now_iso(),
                "message": "仿真完成",
                "cases": cases,
            },
        )
    except subprocess.TimeoutExpired:
        update_job(
            job_id,
            {
                "status": "failed",
                "finished_at": now_iso(),
                "message": "MATLAB 运行超过 20 分钟，已停止等待",
            },
        )
    except Exception as exc:
        update_job(
            job_id,
            {
                "status": "failed",
                "finished_at": now_iso(),
                "message": str(exc),
            },
        )


def safe_job_id(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9]{8}-[0-9]{6}-[0-9a-f]{8}", value))


class AppHandler(BaseHTTPRequestHandler):
    server_version = "UUVNoiseLocal/0.1"

    def log_message(self, format, *args):
        print(f"[{now_iso()}] {self.address_string()} {format % args}")

    def send_json(self, data: dict, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, text: str, status: int = 200) -> None:
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def serve_file(self, path: Path, base_dir: Path) -> None:
        try:
            resolved = path.resolve()
            base = base_dir.resolve()
            if not resolved.is_file() or not resolved.is_relative_to(base):
                self.send_error(HTTPStatus.NOT_FOUND)
                return
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        content_type = mimetypes.guess_type(str(resolved))[0] or "application/octet-stream"
        body = resolved.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = unquote(parsed.path)

        if path == "/api/health":
            self.send_json(
                {
                    "ok": True,
                    "root_dir": str(ROOT_DIR),
                    "matlab_found": shutil.which("matlab") is not None,
                }
            )
            return

        if path.startswith("/api/jobs/"):
            job_id = path.rsplit("/", 1)[-1]
            if not safe_job_id(job_id):
                self.send_json({"error": "bad job id"}, 400)
                return
            job_path = JOBS_DIR / job_id / "job.json"
            if not job_path.exists():
                self.send_json({"error": "job not found"}, 404)
                return
            self.send_json(read_json(job_path))
            return

        if path.startswith("/jobs/"):
            parts = path.split("/", 3)
            if len(parts) < 4 or not safe_job_id(parts[2]):
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            target = JOBS_DIR / parts[2] / parts[3]
            self.serve_file(target, JOBS_DIR / parts[2])
            return

        if path in ("/", "/index.html"):
            self.serve_file(FRONTEND_DIR / "index.html", FRONTEND_DIR)
            return

        target = FRONTEND_DIR / path.lstrip("/")
        self.serve_file(target, FRONTEND_DIR)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/api/jobs":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        length = int(self.headers.get("Content-Length", "0"))
        if length > 200000:
            self.send_json({"error": "request too large"}, 413)
            return

        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except json.JSONDecodeError:
            self.send_json({"error": "bad json"}, 400)
            return

        config = normalize_config(payload if isinstance(payload, dict) else {})
        job_id = datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
        job_dir = JOBS_DIR / job_id
        job_dir.mkdir(parents=True, exist_ok=True)
        write_json(job_dir / "input_config.json", config)

        job = {
            "job_id": job_id,
            "status": "queued",
            "message": "等待运行",
            "created_at": now_iso(),
            "updated_at": now_iso(),
            "config": config,
            "cases": [],
        }
        write_json(job_dir / "job.json", job)

        thread = threading.Thread(target=run_job, args=(job_id,), daemon=True)
        thread.start()
        self.send_json(job, 202)


def main() -> None:
    port = int(os.environ.get("UUV_WEB_PORT", "8765"))
    JOBS_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    mimetypes.add_type("audio/wav", ".wav")
    mimetypes.add_type("text/csv", ".csv")

    if not (MODEL_DIR / "run_uuv_source_case.m").exists():
        raise SystemExit(f"MATLAB model files were not found in {MODEL_DIR}")

    server = ThreadingHTTPServer(("127.0.0.1", port), AppHandler)
    print(f"UUV noise local web system: http://127.0.0.1:{port}")
    print(f"Local root: {ROOT_DIR}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
