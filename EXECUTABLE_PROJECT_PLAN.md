# UUV Noise Source and Receiver Signal Simulation - Executable Project Plan

## 1. Project Decision

Confirmed first release direction:

- Language: MATLAB first release.
- Core strategy: self-developed core with optional open-source adapters.
- Phase 1: propagation-before source model, ambient background noise, LOFAR/DEMON products, and Bellhop interface specification.
- Phase 2: propagated receiver spectrum and hydrophone received waveform.
- Default parameters: public-literature-level demo parameters only, no real equipment signature.
- Positioning: noise-source and receiver-signal generation module for a 3D sound-field simulation system.

The project must clearly separate:

- Source-side noise before propagation.
- Ocean-channel propagation.
- Receiver-side signal after propagation.
- Analysis products such as LOFAR and DEMON.

## 2. System Boundary

### 2.1 Phase 1 Boundary

Phase 1 generates propagation-before source products:

```text
target parameters
    -> source model
    -> source level spectrum SL(f)
    -> source pressure waveform p_src(t)
    -> source-side LOFAR / DEMON / PSD / geometry plot
```

Phase 1 also generates ambient background noise:

```text
environment parameters
    -> ambient noise model
    -> noise PSD NL(f)
    -> ambient pressure waveform n_amb(t)
```

Bellhop is not run in Phase 1, but the project exports files that a Bellhop adapter can consume later.

### 2.2 Phase 2 Boundary

Phase 2 generates receiver-side products:

```text
source spectrum SL(f)
    + Bellhop/Kraken/RAM/custom TL(f, r, z)
    -> received spectrum RL(f, r, z)
```

and:

```text
source waveform p_src(t)
    + Bellhop arrivals / impulse response h(t)
    -> received target waveform p_rx_target(t)
    + ambient noise n_amb(t)
    + self noise n_self(t)
    + receiver noise n_rec(t)
    -> hydrophone received waveform p_rx(t)
```

## 3. Repository Structure

Recommended repository name:

```text
uuv-noise-source-sim
```

Directory layout:

```text
uuv-noise-source-sim/
  README.md
  LICENSE
  CITATION.cff
  CHANGELOG.md
  config/
    examples/
      phase1_background_wenz.yaml
      phase1_uuv_point_all.yaml
      phase1_uuv_point_lofar_only.yaml
      phase1_uuv_point_demon_only.yaml
      phase1_uuv_line_propulsor.yaml
      phase1_uuv_surface_hull.yaml
      phase1_uuv_volume_cavitation.yaml
      phase2_receiver_spectrum_from_bellhop_tl.yaml
  docs/
    theory/
      01_definitions_and_units.md
      02_ambient_noise_models.md
      03_uuv_source_model.md
      04_geometry_models.md
      05_lofar_demon.md
      06_bellhop_coupling.md
      07_validation_and_limitations.md
    api/
      config_schema.md
      matlab_api.md
      input_output_formats.md
    references.bib
  src/
    +uuvnoise/
      run_case.m
      load_config.m
      validate_config.m
      default_config.m
      version.m
      models/
        ambient_wenz.m
        ambient_knudsen.m
        ambient_shipping_empirical.m
        ambient_thermal.m
        source_uuv_semempirical.m
        source_machinery_tonal.m
        source_machinery_broadband.m
        source_propeller_tonal.m
        source_cavitation_broadband.m
        source_flow_broadband.m
      geometry/
        make_point_source.m
        make_line_source.m
        make_surface_source.m
        make_volume_source.m
        source_weights.m
      synth/
        synthesize_waveform_from_spectrum.m
        synthesize_tonal_lines.m
        synthesize_colored_noise.m
        apply_demon_modulation.m
        calibrate_rms_level.m
      analysis/
        compute_psd.m
        compute_lofar.m
        compute_demon.m
        compute_octave_band.m
        plot_component_contribution.m
        plot_geometry_3d.m
      io/
        write_manifest.m
        write_spectrum_csv.m
        write_waveform_wav.m
        write_waveform_mat.m
        write_products.m
      propagation/
        export_bellhop_frequency_grid.m
        export_bellhop_source_table.m
        read_tl_table.m
        apply_tl_to_source_spectrum.m
        synthesize_received_from_arrivals.m
  examples/
    run_background_only.m
    run_uuv_point_all.m
    run_uuv_point_lofar_only.m
    run_uuv_point_demon_only.m
    run_uuv_line_source.m
    run_uuv_surface_source.m
    run_uuv_volume_source.m
  tests/
    test_units.m
    test_db_energy_sum.m
    test_shaft_bpf_frequency.m
    test_config_validation.m
    test_output_schema.m
  external/
    README.md
  output/
    .gitkeep
```

## 4. Noise Models To Implement

### 4.1 Ambient Background Noise

Purpose:

Background noise independent of a target. It may be used alone or added at the receiver side.

First release:

- Wenz-style ambient ocean noise.
- Knudsen sea-state curve option.
- Wind noise component.
- Shipping/traffic background component.
- Thermal high-frequency component.
- Optional colored Gaussian waveform synthesis.

Outputs:

- `ambient_spectrum.csv`
- `ambient_pressure.wav`
- `ambient_pressure.mat`
- `ambient_psd.png`

### 4.2 UUV Target Radiated Noise

Purpose:

Propagation-before radiated-noise source model.

First release components:

- Machinery tonal noise.
- Machinery broadband noise.
- Shaft-rate tonal lines.
- Propeller blade-pass-frequency tonal lines.
- Cavitation broadband noise.
- DEMON-modulated cavitation component.
- Hull/flow broadband noise.

Core frequencies:

```text
f_shaft = RPM / 60
f_BPF = blade_count * f_shaft
```

Tonal pressure synthesis:

```text
p_tonal(t) = sum_k A_k cos(2*pi*f_k*t + phi_k)
```

Cavitation modulation:

```text
p_cav(t) = [1 + m(t)] * n_cav(t)
m(t) = sum_q m_q cos(2*pi*q*f_BPF*t + psi_q)
```

Energy summation:

```text
SL_total(f) = 10*log10( sum_i 10^(SL_i(f)/10) )
```

Important rule:

dB values must not be directly added. Convert each component to linear power, sum, then convert back to dB.

### 4.3 Equivalent Source Geometry

The geometry model is independent from the noise component.

Supported geometry in Phase 1:

- Point source: one equivalent monopole.
- Line source: weighted point sources along UUV axis or propulsor line.
- Surface source: weighted panel source on simplified hull surface.
- Volume source: distributed source cloud for cavitation wake or internal machinery region.

Geometry outputs:

- `source_geometry.csv`
- `source_weights.csv`
- `source_geometry_3d.png`

## 5. Public MATLAB Interface

Recommended main call:

```matlab
result = uuvnoise.run_case("config/examples/phase1_uuv_point_all.yaml");
```

Selective generation:

```matlab
result = uuvnoise.run_case( ...
    "config/examples/phase1_uuv_point_all.yaml", ...
    "components", ["machinery_tonal", "propeller_tonal", "cavitation"], ...
    "products", ["source_spectrum", "waveform", "lofar", "demon"], ...
    "geometry", "point");
```

Background-only case:

```matlab
result = uuvnoise.run_case( ...
    "config/examples/phase1_background_wenz.yaml", ...
    "components", ["ambient"], ...
    "products", ["ambient_spectrum", "waveform", "psd"]);
```

Receiver spectrum in Phase 2:

```matlab
result = uuvnoise.propagation.apply_tl_to_source_spectrum( ...
    "output/phase1_uuv_point_all/source_spectrum.csv", ...
    "input/bellhop_tl_table.csv", ...
    "output/phase2_receiver_spectrum");
```

## 6. Configuration Format

YAML is recommended for user cases. MATLAB struct input should also be supported.

Example:

```yaml
case:
  name: phase1_uuv_point_all
  random_seed: 20260817
  stage: source_before_propagation

signal:
  fs_hz: 48000
  duration_s: 60
  frequency_min_hz: 10
  frequency_max_hz: 20000
  reference_pressure_pa: 1.0e-6

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

geometry:
  type: point
  coordinate_frame: local_ned
  origin_m: [0, 0, 50]
  directivity: omnidirectional

components:
  ambient:
    enabled: false
    model: wenz
    sea_state: 3
    wind_speed_mps: 8
  machinery_tonal:
    enabled: true
    frequencies_hz: [120, 240, 360]
    levels_db: [118, 112, 108]
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
  export:
    - source_spectrum
    - waveform
    - psd
    - lofar
    - demon
    - octave_band
    - geometry_plot
    - manifest

output:
  directory: output/phase1_uuv_point_all
  overwrite: true
```

## 7. Output Format

### 7.1 Manifest

File:

```text
manifest.json
```

Required fields:

- case name
- generation stage: `source_before_propagation` or `receiver_after_propagation`
- software version
- random seed
- config hash
- model names
- units
- output file list
- limitation statement

### 7.2 Source Spectrum

File:

```text
source_spectrum.csv
```

Columns:

```text
frequency_hz
SL_total_db_re_1uPa2_per_Hz_at_1m
SL_machinery_tonal_db
SL_machinery_broadband_db
SL_propeller_tonal_db
SL_cavitation_db
SL_flow_db
```

### 7.3 Ambient Spectrum

File:

```text
ambient_spectrum.csv
```

Columns:

```text
frequency_hz
NL_total_db_re_1uPa2_per_Hz
NL_wind_db
NL_shipping_db
NL_thermal_db
NL_other_db
```

### 7.4 Bellhop Coupling Tables

Frequency grid exported by Phase 1:

```text
bellhop_frequency_grid.csv
```

Columns:

```text
frequency_hz
source_depth_m
receiver_depth_m
range_m
env_file_name
```

Transmission loss table consumed in Phase 2:

```text
bellhop_tl_table.csv
```

Columns:

```text
frequency_hz
range_m
receiver_depth_m
TL_db
model_name
```

Receiver spectrum output:

```text
received_spectrum.csv
```

Columns:

```text
frequency_hz
range_m
receiver_depth_m
RL_target_db_re_1uPa2_per_Hz
NL_ambient_db_re_1uPa2_per_Hz
RL_total_db_re_1uPa2_per_Hz
```

Core coupling equation:

```text
RL_target(f, r, z) = SL(f) - TL(f, r, z)
```

Receiver-side energy summation:

```text
RL_total(f) = 10*log10(
    10^(RL_target(f)/10)
  + 10^(NL_ambient(f)/10)
  + 10^(NL_self(f)/10)
  + 10^(NL_receiver(f)/10)
)
```

### 7.5 Time-Domain Outputs

Source-side:

```text
source_pressure.wav
source_pressure.mat
source_lofar.png
source_demon.png
```

Receiver-side Phase 2:

```text
received_pressure.wav
received_pressure.mat
received_lofar.png
received_demon.png
```

## 8. Open-Source Integration Strategy

### 8.1 Core Self-Developed

The main MATLAB package should implement:

- model composition
- dB/unit handling
- source waveform synthesis
- LOFAR/DEMON analysis
- geometry generation
- file I/O and manifest

This avoids making the project dependent on one external academic package.

### 8.2 Optional Adapters

Open-source tools should be optional, versioned, and documented:

- uwa-channels: optional reference for channel replay and realistic ambient noise generation.
- Acoustics Toolbox/Bellhop: propagation adapter target.
- phonometry: optional formula/reference comparison for underwater acoustic quantities and vessel source models.
- OpenFOAM/libAcoustics: future offline CFD/FW-H calibration route.

Policy:

- Do not copy third-party code unless license and attribution are reviewed.
- Store third-party projects under `external/` only if needed.
- Record project name, URL, commit hash, license, and citation in `external/README.md`.

## 9. Theory and Reference Basis

The project documentation should cite and distinguish the following:

- Wenz ambient-noise curves for ocean ambient-noise spectra.
- Knudsen sea-state curves for sea-state-dependent ambient noise.
- ISO 17208-2 equivalent monopole source level concept for underwater radiated noise from ships.
- ISO 18405 underwater acoustics terminology where applicable.
- Wales-Heitmeyer, Wittekind, RANDI, and JOMOPANS-ECHO as empirical or semi-empirical vessel-noise references.
- DEMON literature for envelope modulation of propeller/cavitation broadband noise.
- Bellhop/Acoustics Toolbox documentation for propagation loss and arrival structure.

Documentation rule:

Every implemented formula must live in `docs/theory/` with:

- formula
- variable definition
- unit
- valid range
- reference
- limitation

## 10. Development Roadmap

### Milestone 0: Repository Foundation

Deliverables:

- repository structure
- README
- license
- config examples
- `docs/theory/01_definitions_and_units.md`
- `docs/api/config_schema.md`

Acceptance:

- MATLAB can add `src/` to path.
- `uuvnoise.version()` works.
- config validation reports clear errors.

### Milestone 1: Ambient Noise

Deliverables:

- Wenz/Knudsen ambient spectrum model
- ambient waveform synthesis
- PSD plot
- background-only example

Acceptance:

- `examples/run_background_only.m` generates expected CSV/WAV/MAT/PNG files.
- output manifest states `stage = ambient_noise`.

### Milestone 2: UUV Point Source

Deliverables:

- machinery tonal/broadband
- shaft and BPF lines
- cavitation broadband
- DEMON modulation
- flow broadband
- point-source geometry

Acceptance:

- shaft frequency equals `RPM/60`.
- BPF equals `blade_count*RPM/60`.
- component levels are energy-summed, not dB-summed.
- user can generate only LOFAR, only DEMON, or all products.

### Milestone 3: Line/Surface/Volume Sources

Deliverables:

- line source distribution
- surface source distribution
- volume source distribution
- geometry CSV and 3D plot

Acceptance:

- geometry model changes spatial distribution only.
- same noise component can be used with point, line, surface, or volume geometry.

### Milestone 4: Bellhop Interface Specification

Deliverables:

- frequency grid export
- source table export
- TL table schema
- example dummy TL table
- `apply_tl_to_source_spectrum.m`

Acceptance:

- source spectrum and TL table produce receiver spectrum by `RL = SL - TL`.
- no claim that Bellhop directly consumes noise spectrum.

### Milestone 5: Receiver Signal Phase 2

Deliverables:

- receiver spectrum generation
- ambient/self/receiver noise addition
- arrival-based time-domain synthesis
- receiver-side LOFAR/DEMON

Acceptance:

- receiver outputs are clearly named `received_*`.
- source outputs remain clearly named `source_*`.
- manifest states whether product is before or after propagation.

## 11. Validation Plan

Unit tests:

- pressure and dB conversion
- power summation in linear domain
- shaft and BPF frequency calculation
- deterministic random seed
- output schema
- YAML config validation

Model verification:

- Wenz/Knudsen curves compared against reference plots.
- synthetic tonal cases verify LOFAR frequency positions.
- synthetic amplitude-modulated broadband cases verify DEMON peak positions.
- Bellhop coupling verified with known artificial TL table.

Engineering validation:

- Calibrate UUV model parameters against open measured datasets, controlled tank/sea-trial data, or CFD/FW-H outputs.
- Default demo parameters must be marked as uncalibrated.

## 12. README Positioning Statement

Recommended public wording:

```text
This project is a MATLAB-based underwater noise-source and receiver-signal
simulation framework for 3D sound-field simulation workflows. It provides
configurable ambient-noise models, semi-empirical UUV/ship-like radiated-noise
source models, equivalent source geometries, LOFAR/DEMON analysis products,
and Bellhop-compatible propagation interface specifications.

Default parameters are public-literature-level demonstration parameters and
do not represent the acoustic signature of any real platform. Scenario-faithful
use requires calibration against measured data or high-fidelity CFD/FW-H
prediction.
```

## 13. Main Risk Controls

Risk 1: confusing source-side and receiver-side products.

Control:

- all files must use `source_*`, `ambient_*`, or `received_*` prefixes.
- manifest must include `stage`.

Risk 2: overclaiming model fidelity.

Control:

- default cases are labeled `demo_uncalibrated`.
- calibrated cases require calibration report and data provenance.

Risk 3: hidden third-party dependency risk.

Control:

- external adapters are optional.
- license and commit hash recorded.

Risk 4: Bellhop interface misunderstanding.

Control:

- Bellhop adapter works with frequency grids, TL tables, or arrivals.
- source spectra are combined with TL outside Bellhop.

