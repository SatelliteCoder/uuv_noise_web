# UUV Noise Web

UUV Noise Web is a local web prototype for semi-empirical UUV target radiated-noise simulation. It wraps a MATLAB noise-source model with a lightweight Python backend and a browser-based frontend.

> This project is a research and engineering prototype. The default parameters are illustrative and are not calibrated to a real UUV. Generated signals should not be treated as certified acoustic signatures of any specific vehicle.

## What It Does

- Runs point, line, surface, and volume equivalent-source UUV noise cases.
- Generates UUV target radiated-noise previews with machinery broadband noise, motor/shaft tonal lines, propeller blade-pass-frequency tonal lines, modulated propeller/cavitation broadband noise, DEMON preview, and hull-flow broadband noise.
- Produces PNG figures, WAV audio previews, CSV tables, MAT result files, and TXT descriptions.
- Provides a local web interface for parameter input, result display, WAV playback, and file download.

## Project Structure

```text
uuv_noise_web/
  backend/        Python local HTTP backend
  frontend/       HTML/CSS/JavaScript browser UI
  matlab_model/   MATLAB simulation kernel
  jobs/           Example and runtime simulation outputs
  README.md       Project introduction and usage
```

## Requirements

- Windows is recommended for the current local prototype.
- Python 3.10 or newer.
- MATLAB with Signal Processing Toolbox functions used by the plotting routines.
- The `matlab` command should be available in PowerShell/CMD PATH.

No Python web framework is required in this first version. The backend uses Python standard-library HTTP tools.

## Quick Start

In PowerShell:

```powershell
cd uuv_noise_web
python .\backend\server.py
```

Then open:

```text
http://127.0.0.1:8765
```

You can also double-click:

```text
start_local_web.bat
```

## Output Files

Each simulation creates a task folder under `jobs/<job_id>/`.

Typical output files:

- `uuv_source_signal.wav`: 1 m equivalent source-signal preview.
- `uuv_received_target.wav`: simplified propagated target-signal preview.
- `uuv_received_mix.wav`: target plus ambient-noise preview.
- `uuv_source_spectrum.png`: source-level spectrum.
- `uuv_waveforms.png`: waveform preview.
- `uuv_lofar.png`: LOFAR-style low-frequency display.
- `uuv_demon.png`: DEMON envelope-spectrum preview.
- `uuv_source_geometry_3d.png`: equivalent-source geometry.
- `uuv_source_spectrum.csv`: spectrum data table.
- `uuv_tonal_lines.csv`: tonal-line table.
- `uuv_source_geometry.csv`: source-element coordinates and weights.
- `uuv_source_model_result.mat`: full MATLAB result.
- `uuv_noise_description.txt`: readable description of the generated signal.

The repository includes one successful demo job in `jobs/20260818-091054-722e7c1b/`.

## Architecture

```text
Browser UI
  -> frontend/app.js sends JSON parameters
Python backend
  -> backend/server.py creates a job folder and calls MATLAB
MATLAB model
  -> matlab_model/web_run_case.m runs the source model
Job output
  -> PNG/WAV/CSV/MAT/TXT files are served back to the browser
```

## Notes

This version focuses on getting the full local workflow running. It is not yet a production web system. Future versions can replace the standard-library backend with FastAPI, add user accounts, add a real job queue, and connect the source model to Bellhop/RAM/Kraken propagation workflows.
