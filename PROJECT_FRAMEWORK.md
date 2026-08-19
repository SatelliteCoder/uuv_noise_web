# UUV/Ship Underwater Noise Source Simulation Project Framework

## 1. Project Positioning

This project should be designed as a modular underwater acoustic noise-source simulator, not as a propagation solver.

Core scope:

- Generate underwater acoustic source spectra and time-domain pressure signals.
- Support UUV and ship-like target radiated-noise components.
- Support equivalent point, line, surface, and volume source geometry.
- Generate analysis products such as PSD, LOFAR, DEMON, one-third-octave spectra, and source geometry plots.
- Export clean interfaces for propagation engines such as Bellhop, Kraken, RAM, Acoustics Toolbox, or custom 3D sound-field solvers.

Out of scope for the source model core:

- Full 3D acoustic propagation.
- Tactical detection/recognition decision logic.
- Claims of real UUV acoustic signature fidelity without calibration data.

Engineering principle:

The source generator outputs source-level spectra and pressure waveforms. Propagation modules consume these outputs and compute received levels or received waveforms.

## 2. Recommended Repository Structure

```text
uuv-noise-source-sim/
  README.md
  LICENSE
  CITATION.cff
  pyproject.toml or matlab_project.prj
  config/
    examples/
      background_wenz.yaml
      uuv_point_all_components.yaml
      uuv_point_lofar_only.yaml
      uuv_point_demon_only.yaml
      uuv_line_propeller_array.yaml
      uuv_surface_hull_panel.yaml
      uuv_volume_cavitation_cloud.yaml
  src/
    matlab/
      +uuvnoise/
        run_case.m
        load_config.m
        validate_config.m
        models/
          ambient_wenz.m
          ambient_knudsen.m
          ambient_thermal.m
          ambient_shipping_empirical.m
          source_machinery_tonal.m
          source_machinery_broadband.m
          source_propeller_tonal.m
          source_propeller_cavitation.m
          source_flow_broadband.m
          source_empirical_ship.m
          source_uuv_semempirical.m
        geometry/
          point_source.m
          line_source.m
          surface_source.m
          volume_source.m
          directivity_pattern.m
        synth/
          spectrum_to_timeseries.m
          tonal_synthesis.m
          colored_noise_synthesis.m
          demon_modulation.m
          calibrate_level.m
        analysis/
          compute_psd.m
          compute_lofar.m
          compute_demon.m
          compute_octave_band.m
          contribution_plot.m
        io/
          write_wav.m
          write_csv_spectrum.m
          write_mat_result.m
          write_manifest_json.m
        propagation_adapters/
          export_bellhop_source.m
          export_acoustics_toolbox_env.m
          apply_transfer_loss_table.m
    python_optional/
      wrappers/
      validation/
  docs/
    theory/
      source_level_definitions.md
      ambient_noise_models.md
      uuv_radiated_noise_model.md
      lofar_demon_methods.md
      geometry_models.md
      validation_and_limits.md
    api/
      config_schema.md
      matlab_api.md
      output_formats.md
    references.bib
  tests/
    matlab/
      test_config_validation.m
      test_level_summation.m
      test_tonal_frequencies.m
      test_output_schema.m
  examples/
    run_background_only.m
    run_uuv_point_selective.m
    run_uuv_all_geometries.m
  output/
    .gitkeep
```

## 3. Model Layer Design

### 3.1 Ambient Background Noise

Purpose:

Generate environmental ocean noise independent of a target.

Recommended components:

- Wind-driven sea-surface noise.
- Shipping/background traffic noise.
- Thermal noise at high frequency.
- Optional biological, rain, and impulsive noise as extension modules.

Candidate model basis:

- Wenz ambient-noise curves.
- Knudsen sea-state curves.
- RANDI-style empirical ambient shipping/wind formulation if license and implementation route are acceptable.
- uwa-channels `noisegen` may be used as a MATLAB/Octave reference or optional backend.

Outputs:

- Ambient noise PSD in dB re 1 uPa^2/Hz.
- Time-domain background pressure waveform.
- Optional one-third-octave band levels.

### 3.2 UUV/Target Radiated Noise

Purpose:

Generate target-radiated source signatures before propagation.

Recommended components:

- Machinery tonal lines: motor, pump, bearings, gear-like harmonics if applicable.
- Machinery broadband noise.
- Shaft-rate tonal lines.
- Propeller blade-pass frequency lines.
- Propeller cavitation or propulsor broadband noise.
- DEMON envelope modulation of cavitation broadband.
- Hull/flow broadband noise due to turbulent boundary layer and appendages.

Minimum defensible formulation:

```text
f_shaft = RPM / 60
f_BPF = blade_count * f_shaft

p_tonal(t) = sum_k A_k cos(2*pi*f_k*t + phi_k)

p_cav(t) = [1 + m(t)] * n_cav(t)
m(t) = sum_q m_q cos(2*pi*q*f_BPF*t + psi_q)

SL_total(f) = 10*log10( sum_i 10^(SL_i(f)/10) )
```

Where:

- `SL_i(f)` is the component source level spectrum.
- Energy summation is performed in linear power, not by directly adding dB.
- Default parameters are engineering placeholders until calibrated.

### 3.3 Empirical Ship/Vehicle Source Models

Purpose:

Provide validated or semi-validated reference families for non-UUV or ship-like targets.

Recommended options:

- JOMOPANS-ECHO / MacGillivray and de Jong style vessel source-level model.
- Wales-Heitmeyer empirical merchant ship source spectra.
- Wittekind-style decomposition into machinery, cavitation, and other components.
- RANDI source/traffic model where appropriate.

Project policy:

- Prefer reimplementation from published formulas with citations, or optional wrappers to open-source packages.
- Do not copy third-party code into the repository unless the license is verified and attribution is complete.

### 3.4 High-Fidelity Offline Calibration

Purpose:

Provide a route for physics-based calibration, not online real-time simulation.

Recommended route:

- OpenFOAM for propeller/hull flow field.
- FW-H acoustic analogy implementation, for example via libAcoustics or equivalent open-source tooling.
- Use CFD/FW-H results to fit semi-empirical model parameters.

Project policy:

- CFD is an offline calibration backend.
- The runtime UUV model remains semi-empirical and fast.

## 4. Geometry Model

Geometry describes how one or more elementary sources are spatially distributed. It is independent from the noise component.

### 4.1 Point Source

Use when UUV size is small relative to wavelength or receiver range.

Output:

- One equivalent monopole source.
- Optional directivity pattern.
- Best for early-stage source-to-propagation coupling.

### 4.2 Line Source

Use for distributed propulsor/shaft/hull sources along a longitudinal axis.

Output:

- A set of weighted point sources along a line.
- Optional phase or coherence model.
- Approximate directional radiation in the long-axis direction.

### 4.3 Surface Source

Use for vibrating hull panels or shell-surface radiation.

Output:

- Surface mesh or panel centers with source weights.
- Panel normal vectors and optional directivity.
- Supports structural vibration or hull-flow coupling later.

### 4.4 Volume Source

Use for cavitation cloud, turbulent wake, distributed machinery compartments, or volumetric background sources.

Output:

- Cloud of elementary monopoles or cells.
- Spatial density, coherence length, and random phase model.

## 5. Public MATLAB API

Recommended user-facing functions:

```matlab
result = uuvnoise.run_case("config/examples/uuv_point_all_components.yaml");

result = uuvnoise.run_case( ...
    "config/examples/uuv_point_all_components.yaml", ...
    "components", ["machinery", "propeller_tonal", "cavitation"], ...
    "products", ["wav", "psd", "lofar", "demon"], ...
    "geometry", "point");

result = uuvnoise.generate_background( ...
    "model", "wenz", ...
    "sea_state", 3, ...
    "wind_speed_mps", 8, ...
    "duration_s", 60, ...
    "fs_hz", 48000);

result = uuvnoise.generate_target( ...
    "platform", platform, ...
    "propulsor", propulsor, ...
    "geometry", geometry, ...
    "components", components, ...
    "products", products);
```

Recommended selectable products:

- `waveform`
- `spectrum`
- `psd`
- `lofar`
- `demon`
- `octave`
- `geometry_plot`
- `component_contribution`
- `bellhop_source`
- `manifest`

Example behavior:

- If `products = ["waveform"]`, only time-domain signal is produced.
- If `products = ["lofar"]`, waveform is generated internally if needed, but only LOFAR products are exported.
- If `components = ["background"]`, no target-radiated noise is generated.
- If `components = ["propeller_tonal", "cavitation"]`, machinery and flow noise are excluded.

## 6. Configuration Schema

Recommended config format:

- YAML for human-readable cases.
- JSON schema for validation.
- MATLAB struct support for script users.

Example:

```yaml
case:
  name: uuv_point_demo
  random_seed: 20260817

signal:
  fs_hz: 48000
  duration_s: 60
  frequency_min_hz: 10
  frequency_max_hz: 20000
  pressure_unit_internal: Pa
  level_reference: "1 uPa"

platform:
  type: UUV
  length_m: 3.5
  diameter_m: 0.35
  speed_mps: 2.5
  depth_m: 50

propulsor:
  type: propeller
  blade_count: 5
  rpm: 900
  diameter_m: 0.18
  cavitation_index: null

geometry:
  type: point
  frame: local_ned
  origin_m: [0, 0, 50]
  directivity: omnidirectional

components:
  background:
    enabled: false
    model: wenz
    sea_state: 3
    wind_speed_mps: 8
  machinery_tonal:
    enabled: true
    base_frequencies_hz: [120, 240, 360]
    source_levels_db: [118, 112, 108]
  machinery_broadband:
    enabled: true
    model: empirical_power_law
  propeller_tonal:
    enabled: true
    include_shaft_rate: true
    include_bpf: true
    harmonics: 8
  cavitation:
    enabled: true
    model: demon_modulated_broadband
    modulation_depth: 0.25
  flow_noise:
    enabled: true
    model: empirical_speed_power_law

products:
  export: [waveform, psd, lofar, demon, spectrum, manifest]

output:
  directory: output/uuv_point_demo
  write_wav: true
  write_mat: true
  write_csv: true
  write_png: true
```

## 7. Output Format Specification

### 7.1 Manifest

File:

```text
manifest.json
```

Required fields:

- Case name.
- Software version.
- Random seed.
- Date generated.
- Config hash.
- Input config path.
- Model names and versions.
- Units.
- Output file list.
- Limitations statement.

### 7.2 Source Spectrum CSV

File:

```text
source_spectrum.csv
```

Columns:

```text
frequency_hz,
SL_total_db_re_1uPa2_per_Hz_at_1m,
SL_machinery_tonal_db,
SL_machinery_broadband_db,
SL_propeller_tonal_db,
SL_cavitation_db,
SL_flow_db,
SL_background_db
```

### 7.3 Time Series

Files:

```text
source_pressure.wav
source_pressure.mat
source_pressure.csv
```

Rules:

- WAV is for listening and signal-chain testing.
- MAT/CSV retains calibrated physical pressure units.
- Internal pressure should be Pa.
- Level metadata must specify reference pressure `1 uPa`.

### 7.4 Analysis Products

Files:

```text
psd.csv
lofar.png
lofar.mat
demon.png
demon.csv
octave_band.csv
geometry_3d.png
component_contribution.png
```

LOFAR:

- Short-time spectrum/spectrogram focused on narrowband tonal structures.

DEMON:

- Band-pass around cavitation broadband.
- Envelope extraction.
- Envelope spectrum showing shaft/blade-related modulation.

## 8. Validation Strategy

Validation should be part of the project from the beginning.

Minimum tests:

- Unit conversion tests: Pa, uPa, dB re 1 uPa.
- dB energy summation tests.
- Shaft and BPF frequency tests.
- PSD level calibration tests.
- Deterministic random seed tests.
- Output schema tests.

Engineering validation:

- Compare ambient-noise curves with Wenz/Knudsen reference curves.
- Compare ship-like empirical source spectra with published model ranges.
- Compare LOFAR/DEMON outputs against synthetic known modulation cases.
- Calibrate UUV parameters against measured tank/sea trial data or CFD/FW-H offline results.

Acceptance policy:

- A default demo case only proves the software pipeline works.
- A calibrated case requires a calibration report, source data provenance, and uncertainty bounds.

## 9. Recommended Open-Source Integration

Use third-party projects as optional dependencies or validation references, not as hidden copied code.

Recommended candidates:

- uwa-channels MATLAB/Octave: ambient noise/time-domain underwater acoustic channel utilities.
- phonometry Python: ambient and vessel noise model reference implementation if license is compatible.
- Acoustics Toolbox: propagation adapter target, not source generation.
- UnderwaterAcoustics.jl: propagation/reference ecosystem.
- OpenFOAM + libAcoustics: offline CFD/FW-H calibration route.

Policy:

- Keep third-party source code outside the core unless license review is complete.
- Put wrappers in `src/python_optional` or `external_adapters`.
- Document exact version, commit hash, license, and citation.

## 10. Theoretical and Standards Basis

Recommended references to cite and document:

- Wenz, G. M. (1962). Acoustic ambient noise in the ocean: spectra and sources.
- Knudsen et al. sea-state ambient-noise curves.
- Urick, Principles of Underwater Sound.
- ISO 17208-1/2 underwater radiated noise measurement and equivalent source level concepts.
- ANSI/ASA underwater acoustics terminology and measurement practices where applicable.
- Ainslie and McColm absorption formula for seawater, if simple propagation loss is included.
- Wales and Heitmeyer empirical ship source spectra.
- Wittekind ship underwater noise source-level model.
- JOMOPANS-ECHO / MacGillivray and de Jong vessel source-level modeling.
- DEMON/passive sonar envelope modulation literature for cavitation/propeller modulation analysis.
- FW-H acoustic analogy references for CFD-based propeller noise calibration.

## 11. Recommended Development Roadmap

### Phase 1: Clean Project Foundation

- Create neutral repository.
- Add config schema.
- Implement source-level unit conversion and output manifest.
- Implement Wenz/Knudsen ambient background noise.
- Add tests and example configs.

### Phase 2: Target Source Core

- Implement point-source UUV model.
- Implement machinery tonal/broadband, shaft/BPF, cavitation broadband, DEMON modulation, and flow broadband.
- Implement selective products: waveform, PSD, LOFAR, DEMON, spectrum.

### Phase 3: Geometry Expansion

- Implement line, surface, and volume equivalent source distributions.
- Add geometry plots and source-weight export.
- Ensure geometry and noise components are independent.

### Phase 4: Empirical Model Backends

- Add ship-like empirical models from published references.
- Add optional wrappers or validation scripts for open-source packages.
- Add comparison plots and validation notes.

### Phase 5: Propagation and Calibration Interfaces

- Export source files for Bellhop/Acoustics Toolbox.
- Support imported transfer-loss table:

```text
RL(f, receiver) = SL(f) - TL(f, receiver)
```

- Add calibration parameter fitting from measured or CFD data.

## 12. Important Limitations Statement

Default parameters must not be described as a real UUV signature.

The project can be strong and reviewable if it is presented as:

- A standards-aware, formula-documented, configurable semi-empirical source simulation framework.
- A tool that can become scenario-faithful after calibration.
- A source model that exports reproducible spectra, waveforms, and analysis products.

It should not be presented as:

- A validated military UUV acoustic signature database.
- A substitute for measured radiated-noise trials.
- A substitute for CFD/FW-H high-fidelity acoustic prediction.

