function web_run_case(config_path, output_dir)
% WEB_RUN_CASE Run one UUV noise case from a JSON config.
%
% This file is a thin local-web wrapper around run_uuv_source_case. It keeps
% the original MATLAB model callable from a backend process without changing
% the model API used by MATLAB users.

if nargin < 2
    error('web_run_case:missingInput', 'config_path and output_dir are required.');
end

model_dir = fileparts(mfilename('fullpath'));
addpath(model_dir);

cfg = jsondecode(fileread(char(config_path)));
params = uuv_default_params();
params = apply_web_config(params, cfg);
params.output_dir = char(output_dir);

result = run_uuv_source_case(params.source.type, params);
write_web_summary(result, params, fullfile(params.output_dir, 'web_result_summary.json'));
end

function params = apply_web_config(params, cfg)
params.fs = number_field(cfg, 'fs', params.fs, 8000, 96000);
params.duration_s = number_field(cfg, 'duration_s', params.duration_s, 1, 60);
params.random_seed = round(number_field(cfg, 'random_seed', params.random_seed, 1, 999999999));

source_type = text_field(cfg, 'source_type', params.source.type);
source_type = lower(source_type);
valid_types = {'point', 'line', 'surface', 'volume'};
if ~any(strcmp(source_type, valid_types))
    error('web_run_case:badSourceType', 'source_type must be point, line, surface, or volume.');
end
params.source.type = source_type;

uuv = struct_field(cfg, 'uuv');
params.uuv.length_m = number_field(uuv, 'length_m', params.uuv.length_m, 0.3, 30);
params.uuv.diameter_m = number_field(uuv, 'diameter_m', params.uuv.diameter_m, 0.05, 5);
params.uuv.depth_m = number_field(uuv, 'depth_m', params.uuv.depth_m, 1, 1000);
params.uuv.speed_mps = number_field(uuv, 'speed_mps', params.uuv.speed_mps, 0, 25);
params.uuv.rpm = number_field(uuv, 'rpm', params.uuv.rpm, 10, 5000);
params.uuv.blade_count = round(number_field(uuv, 'blade_count', params.uuv.blade_count, 2, 12));
params.uuv.propeller_diameter_m = number_field(uuv, 'propeller_diameter_m', ...
    params.uuv.propeller_diameter_m, 0.03, 5);

source = struct_field(cfg, 'source');
params.source.heading_deg = number_field(source, 'heading_deg', params.source.heading_deg, -180, 180);
params.source.length_m = params.uuv.length_m;
params.source.diameter_m = params.uuv.diameter_m;
params.source.center_xyz_m = [0, 0, -abs(params.uuv.depth_m)];
params.source.line_elements = round(number_field(source, 'line_elements', params.source.line_elements, 3, 81));
params.source.surface_axial_elements = round(number_field(source, 'surface_axial_elements', ...
    params.source.surface_axial_elements, 3, 40));
params.source.surface_circum_elements = round(number_field(source, 'surface_circum_elements', ...
    params.source.surface_circum_elements, 4, 48));
params.source.volume_axial_elements = round(number_field(source, 'volume_axial_elements', ...
    params.source.volume_axial_elements, 3, 30));
params.source.volume_radial_elements = round(number_field(source, 'volume_radial_elements', ...
    params.source.volume_radial_elements, 1, 8));
params.source.volume_circum_elements = round(number_field(source, 'volume_circum_elements', ...
    params.source.volume_circum_elements, 4, 48));

receiver = struct_field(cfg, 'receiver');
rx_default = params.geometry.receiver_xyz_m;
params.geometry.receiver_xyz_m = [ ...
    number_field(receiver, 'x_m', rx_default(1), -10000, 10000), ...
    number_field(receiver, 'y_m', rx_default(2), -10000, 10000), ...
    number_field(receiver, 'z_m', rx_default(3), -1000, 100)];
params.geometry.source_xyz_m = params.source.center_xyz_m;

ambient = struct_field(cfg, 'ambient');
params.ambient.enabled = logical_field(ambient, 'enabled', params.ambient.enabled);
params.ambient.rms_uPa = number_field(ambient, 'rms_uPa', params.ambient.rms_uPa, 0, 100000);
params.ambient.slope_db_decade = number_field(ambient, 'slope_db_decade', ...
    params.ambient.slope_db_decade, -40, 10);
end

function s = struct_field(parent, name)
if isstruct(parent) && isfield(parent, name) && isstruct(parent.(name))
    s = parent.(name);
else
    s = struct();
end
end

function value = number_field(parent, name, default_value, min_value, max_value)
value = default_value;
if isstruct(parent) && isfield(parent, name)
    candidate = parent.(name);
    if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate)
        value = double(candidate);
    end
end
value = min(max(value, min_value), max_value);
end

function value = logical_field(parent, name, default_value)
value = default_value;
if isstruct(parent) && isfield(parent, name)
    candidate = parent.(name);
    if islogical(candidate) && isscalar(candidate)
        value = candidate;
    elseif isnumeric(candidate) && isscalar(candidate)
        value = candidate ~= 0;
    end
end
end

function value = text_field(parent, name, default_value)
value = char(string(default_value));
if isstruct(parent) && isfield(parent, name)
    value = char(string(parent.(name)));
end
end

function write_web_summary(result, params, filename)
summary = struct();
summary.source_type = char(result.geometry.type);
summary.noise_type = 'UUV target radiated noise, semi-empirical';
summary.noise_components = { ...
    'machinery broadband noise', ...
    'machinery and motor tonal lines', ...
    'shaft-frequency tonal lines', ...
    'propeller blade-pass-frequency tonal lines', ...
    'modulated propeller/cavitation broadband noise for DEMON preview', ...
    'hull-flow broadband noise'};
summary.notice = ['Engineering prototype only. Default parameters are illustrative ', ...
    'and are not calibrated to a real UUV acoustic signature.'];

summary.geometry = struct();
summary.geometry.type = char(result.geometry.type);
summary.geometry.num_elements = result.geometry.num_elements;
summary.geometry.receiver_xyz_m = params.geometry.receiver_xyz_m;
summary.geometry.source_center_xyz_m = result.geometry.center_xyz_m;

summary.features = struct();
summary.features.shaft_hz = result.features.shaft_hz;
summary.features.bpf_hz = result.features.bpf_hz;
summary.features.tip_speed_mps = result.features.tip_speed_mps;
summary.features.cavitation_activity = result.features.cavitation_activity;

summary.metrics = struct();
summary.metrics.source_rms_uPa = result.metrics.source_rms_uPa;
summary.metrics.received_target_rms_uPa = result.metrics.received_target_rms_uPa;
summary.metrics.ambient_rms_uPa = result.metrics.ambient_rms_uPa;
summary.metrics.received_mix_rms_uPa = result.metrics.received_mix_rms_uPa;
summary.metrics.preview_snr_db = result.metrics.preview_snr_db;

summary.files = struct();
summary.files.summary_png = 'uuv_summary.png';
summary.files.spectrum_png = 'uuv_source_spectrum.png';
summary.files.waveforms_png = 'uuv_waveforms.png';
summary.files.spectrogram_png = 'uuv_spectrogram.png';
summary.files.lofar_png = 'uuv_lofar.png';
summary.files.demon_png = 'uuv_demon.png';
summary.files.geometry_png = 'uuv_source_geometry_3d.png';
summary.files.source_wav = 'uuv_source_signal.wav';
summary.files.received_target_wav = 'uuv_received_target.wav';
summary.files.received_mix_wav = 'uuv_received_mix.wav';
summary.files.spectrum_csv = 'uuv_source_spectrum.csv';
summary.files.tones_csv = 'uuv_tonal_lines.csv';
summary.files.geometry_csv = 'uuv_source_geometry.csv';
summary.files.mat_result = 'uuv_source_model_result.mat';
summary.files.description_txt = 'uuv_noise_description.txt';
summary.files.log_file = 'matlab_stdout.log';

fid = fopen(filename, 'w');
if fid < 0
    warning('web_run_case:summaryWriteFailed', 'Could not write %s', filename);
    return;
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(summary, 'PrettyPrint', true), 'char');
end
