function spectrum = uuv_source_spectrum(params, n)
% UUV_SOURCE_SPECTRUM Build a semi-empirical source-level spectrum.
%
% Output levels are equivalent monopole source levels at 1 m.

fs = params.fs;
df = fs / n;
f = (0:floor(n/2))' * df;
f_safe = max(f, 1);

rps = params.uuv.rpm / 60;
shaft_hz = rps;
bpf_hz = params.uuv.blade_count * shaft_hz;
tip_speed = pi * params.uuv.propeller_diameter_m * rps;

speed_gain_db = 50 * log10(max(params.uuv.speed_mps, 0.1) / 3.0);
rpm_gain_db = 30 * log10(max(params.uuv.rpm, 60) / 720);
size_gain_db = 20 * log10(max(params.uuv.length_m, 0.5) / 3.2);

raw_cav = (tip_speed / params.cavitation.tip_onset_mps - 1) ...
    + 0.5 * (params.uuv.speed_mps / params.cavitation.speed_onset_mps - 1) ...
    - 0.002 * max(params.uuv.depth_m - 20, 0);
cavitation_activity = 1 / (1 + exp(-3 * raw_cav));
cav_gain_db = params.cavitation.max_gain_db * cavitation_activity;

machine_db = params.levels.machine_bb_100hz_db ...
    + 0.35 * rpm_gain_db + size_gain_db ...
    - params.levels.machine_slope_db_decade * log10(f_safe / 100) ...
    - 10 * log10(1 + (f_safe / 3500).^2);

prop_db = params.levels.prop_bb_1khz_db ...
    + rpm_gain_db + 20 * log10(max(params.uuv.propeller_diameter_m, 0.05) / 0.24) ...
    + 0.4 * speed_gain_db + cav_gain_db ...
    - params.levels.prop_slope_db_decade * log10(f_safe / 1000) ...
    - 10 * log10(1 + (f_safe / 15000).^4);

flow_db = params.levels.flow_bb_100hz_db ...
    + 60 * log10(max(params.uuv.speed_mps, 0.1) / 3.0) + size_gain_db ...
    - params.levels.flow_slope_db_decade * log10(f_safe / 100) ...
    - 10 * log10(1 + (f_safe / 2200).^3);

machine_psd = 10.^(machine_db / 10);
prop_psd = 10.^(prop_db / 10);
flow_psd = 10.^(flow_db / 10);

[line_psd, tones] = tonal_psd(params, f, df, shaft_hz, bpf_hz, cav_gain_db, rpm_gain_db);

broadband_psd = machine_psd + prop_psd + flow_psd;
total_psd = broadband_psd + line_psd;

spectrum = struct();
spectrum.f_hz = f;
spectrum.df_hz = df;
spectrum.machine_psd = machine_psd;
spectrum.prop_psd = prop_psd;
spectrum.flow_psd = flow_psd;
spectrum.broadband_psd = broadband_psd;
spectrum.line_psd = line_psd;
spectrum.total_psd = total_psd;
spectrum.machine_db = 10 * log10(max(machine_psd, realmin));
spectrum.prop_db = 10 * log10(max(prop_psd, realmin));
spectrum.flow_db = 10 * log10(max(flow_psd, realmin));
spectrum.line_db = 10 * log10(max(line_psd, realmin));
spectrum.total_db = 10 * log10(max(total_psd, realmin));
spectrum.tones = tones;

spectrum.features.shaft_hz = shaft_hz;
spectrum.features.bpf_hz = bpf_hz;
spectrum.features.tip_speed_mps = tip_speed;
spectrum.features.cavitation_activity = cavitation_activity;
spectrum.features.cavitation_gain_db = cav_gain_db;
if isfield(params, 'source') && isfield(params.source, 'center_xyz_m')
    center_xyz = params.source.center_xyz_m;
else
    center_xyz = params.geometry.source_xyz_m;
end
spectrum.features.range_m = norm(params.geometry.receiver_xyz_m - center_xyz);
end

function [line_psd, tones] = tonal_psd(params, f, df, shaft_hz, bpf_hz, cav_gain_db, rpm_gain_db)
line_psd = zeros(size(f));
tone_freqs = [];
tone_levels = [];
tone_names = {};

for k = 1:numel(params.tonal.shaft_orders)
    order = params.tonal.shaft_orders(k);
    tone_freqs(end+1, 1) = order * shaft_hz; %#ok<AGROW>
    tone_levels(end+1, 1) = params.tonal.shaft_line_levels_db(k) + 0.25 * rpm_gain_db; %#ok<AGROW>
    tone_names{end+1, 1} = sprintf('shaft_%dX', order); %#ok<AGROW>
end

for k = 1:numel(params.tonal.bpf_orders)
    order = params.tonal.bpf_orders(k);
    tone_freqs(end+1, 1) = order * bpf_hz; %#ok<AGROW>
    tone_levels(end+1, 1) = params.tonal.bpf_line_levels_db(k) ...
        + 0.35 * cav_gain_db + 0.30 * rpm_gain_db; %#ok<AGROW>
    tone_names{end+1, 1} = sprintf('bpf_%dX', order); %#ok<AGROW>
end

for k = 1:numel(params.tonal.motor_orders)
    order = params.tonal.motor_orders(k);
    tone_freqs(end+1, 1) = order * params.tonal.motor_hz; %#ok<AGROW>
    tone_levels(end+1, 1) = params.tonal.motor_line_levels_db(k); %#ok<AGROW>
    tone_names{end+1, 1} = sprintf('motor_%dX', order); %#ok<AGROW>
end

valid = tone_freqs > 0 & tone_freqs < max(f);
tone_freqs = tone_freqs(valid);
tone_levels = tone_levels(valid);
tone_names = tone_names(valid);

sigma = max(params.tonal.linewidth_hz / 2.355, df);
for k = 1:numel(tone_freqs)
    g = exp(-0.5 * ((f - tone_freqs(k)) / sigma).^2);
    area = sum(g) * df;
    if area > 0
        g = g / area;
    end
    line_power = 10^(tone_levels(k) / 10);
    line_psd = line_psd + line_power * g;
end

tones = struct();
tones.frequency_hz = tone_freqs;
tones.level_db = tone_levels;
tones.name = tone_names;
end
