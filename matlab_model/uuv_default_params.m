function params = uuv_default_params()
% UUV_DEFAULT_PARAMS Default parameters for the semi-empirical UUV source.
%
% The default values are intentionally conservative and editable. They are
% not a certified source signature of any real vehicle.

params = struct();

% Time and sampling.
params.fs = 48000;
params.duration_s = 12;
params.random_seed = 20260813;

% UUV geometry and operation.
params.uuv.length_m = 3.2;
params.uuv.diameter_m = 0.45;
params.uuv.depth_m = 50;
params.uuv.speed_mps = 3.0;
params.uuv.rpm = 720;
params.uuv.blade_count = 4;
params.uuv.propeller_diameter_m = 0.24;

% 3D equivalent source geometry and receiver geometry.
% source.type can be: 'point', 'line', 'surface', or 'volume'.
params.source.type = 'volume';
params.source.center_xyz_m = [0, 0, -50];
params.source.heading_deg = 20;
params.source.length_m = params.uuv.length_m;
params.source.diameter_m = params.uuv.diameter_m;
params.source.line_elements = 21;
params.source.surface_axial_elements = 10;
params.source.surface_circum_elements = 8;
params.source.volume_axial_elements = 6;
params.source.volume_radial_elements = 2;
params.source.volume_circum_elements = 8;
params.source.weighting = 'tapered'; % 'uniform' or 'tapered'

% Backward-compatible center used by older scripts.
params.geometry.source_xyz_m = params.source.center_xyz_m;
params.geometry.receiver_xyz_m = [600, 160, -45];

% Semi-empirical source-level calibration values.
% Units are dB re 1 uPa^2/Hz @ 1 m for broadband references, and
% dB re 1 uPa^2 @ 1 m for tonal line powers.
params.levels.machine_bb_100hz_db = 82;
params.levels.prop_bb_1khz_db = 76;
params.levels.flow_bb_100hz_db = 70;
params.levels.machine_slope_db_decade = 18;
params.levels.prop_slope_db_decade = 10;
params.levels.flow_slope_db_decade = 15;

% Tonal settings.
params.tonal.linewidth_hz = 0.8;
params.tonal.shaft_orders = 1:4;
params.tonal.shaft_line_levels_db = [108, 103, 98, 94];
params.tonal.bpf_orders = 1:6;
params.tonal.bpf_line_levels_db = [118, 113, 109, 105, 101, 98];
params.tonal.motor_hz = 120;
params.tonal.motor_orders = [1, 2, 3, 4, 6];
params.tonal.motor_line_levels_db = [105, 101, 97, 93, 89];

% Cavitation and DEMON-style modulation settings.
params.cavitation.tip_onset_mps = 10;
params.cavitation.speed_onset_mps = 2.5;
params.cavitation.max_gain_db = 22;
params.cavitation.mod_bpf_depth = 0.28;
params.cavitation.mod_shaft_depth = 0.10;

% Simple propagation for sanity-check rendering before Bellhop/RAM coupling.
params.propagation.enabled = true;
params.propagation.include_absorption = true;

% Optional receiver-side ambient noise, used only for a received-mixture
% preview. The target source model itself is in source_signal_uPa.
params.ambient.enabled = true;
params.ambient.rms_uPa = 800;
params.ambient.slope_db_decade = -17;

params.output_dir = fullfile(pwd, 'output');
end
