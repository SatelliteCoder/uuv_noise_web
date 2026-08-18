function [y, propagation] = uuv_apply_propagation(x, fs, source_f_hz, params, geometry)
% UUV_APPLY_PROPAGATION Apply distributed-source preview propagation.
%
% This is a preview transfer function only. Replace it with Bellhop/RAM TL
% when coupling to the full 3D sound-field solver.

if nargin < 5 || isempty(geometry)
    geometry = uuv_source_geometry(params);
end

if ~params.propagation.enabled
    y = x;
    tl_source_grid_db = zeros(size(source_f_hz));
else
    y = distributed_time_preview(x, fs, params, geometry);
    tl_source_grid_db = distributed_power_tl(source_f_hz, params, geometry);
end

rx = row3(params.geometry.receiver_xyz_m);
ranges = sqrt(sum((geometry.element_xyz_m - rx).^2, 2));
range_m = sum(geometry.weight(:) .* ranges(:));

propagation = struct();
propagation.range_m = range_m;
propagation.min_range_m = min(ranges);
propagation.max_range_m = max(ranges);
propagation.element_range_m = ranges;
propagation.element_delay_s = ranges / sound_speed_mps(params);
propagation.frequency_hz = source_f_hz;
propagation.transfer_function = 10.^(-tl_source_grid_db / 20);
propagation.tl_db = tl_source_grid_db;
propagation.received_level_db = params_to_received_level(source_f_hz, tl_source_grid_db);
end

function y = distributed_time_preview(x, fs, params, geometry)
rx = row3(params.geometry.receiver_xyz_m);
ranges = sqrt(sum((geometry.element_xyz_m - rx).^2, 2));
ranges = max(ranges, 1);
weights = geometry.weight(:);
c = sound_speed_mps(params);
alpha_1khz = thorp_absorption_db_per_km(1);

n = numel(x);
y = zeros(size(x));
for m = 1:numel(ranges)
    r = ranges(m);
    tl_db = 20 * log10(r);
    if params.propagation.include_absorption
        tl_db = tl_db + alpha_1khz * (r / 1000);
    end
    gain = sqrt(weights(m)) * 10^(-tl_db / 20);
    delay_samples = round((r / c) * fs);
    if delay_samples < n
        y(delay_samples+1:end) = y(delay_samples+1:end) + gain * x(1:end-delay_samples);
    end
end
end

function tl_db = distributed_power_tl(f_hz, params, geometry)
rx = row3(params.geometry.receiver_xyz_m);
ranges = sqrt(sum((geometry.element_xyz_m - rx).^2, 2));
ranges = max(ranges, 1);
weights = geometry.weight(:);

power_gain = zeros(size(f_hz));
for m = 1:numel(ranges)
    r = ranges(m);
    tl_m = 20 * log10(r);
    if params.propagation.include_absorption
        tl_m = tl_m + thorp_absorption_db_per_km(f_hz / 1000) * (r / 1000);
    end
    power_gain = power_gain + weights(m) .* 10.^(-tl_m / 10);
end
tl_db = -10 * log10(max(power_gain, realmin));
end

function c = sound_speed_mps(params)
if isfield(params.propagation, 'sound_speed_mps')
    c = params.propagation.sound_speed_mps;
else
    c = 1500;
end
end

function alpha = thorp_absorption_db_per_km(f_khz)
f2 = f_khz.^2;
alpha = 0.11 .* f2 ./ (1 + f2) ...
    + 44 .* f2 ./ (4100 + f2) ...
    + 2.75e-4 .* f2 ...
    + 0.003;
alpha(f_khz <= 0) = 0;
end

function placeholder = params_to_received_level(source_f_hz, tl_db)
placeholder = struct();
placeholder.f_hz = source_f_hz;
placeholder.tl_db = tl_db;
end

function x = row3(x)
x = x(:).';
end
