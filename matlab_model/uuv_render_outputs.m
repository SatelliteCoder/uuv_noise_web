function uuv_render_outputs(result, params)
% UUV_RENDER_OUTPUTS Save figures, audio, MAT, and CSV outputs.

outdir = params.output_dir;
if ~isfolder(outdir)
    mkdir(outdir);
end

save(fullfile(outdir, 'uuv_source_model_result.mat'), 'result', 'params');
write_spectrum_csv(result, fullfile(outdir, 'uuv_source_spectrum.csv'));
write_tone_csv(result, fullfile(outdir, 'uuv_tonal_lines.csv'));
write_geometry_csv(result, fullfile(outdir, 'uuv_source_geometry.csv'));
write_description(result, params, fullfile(outdir, 'uuv_noise_description.txt'));

uuv_write_wav(fullfile(outdir, 'uuv_source_signal.wav'), result.source.source_signal_uPa, params.fs);
uuv_write_wav(fullfile(outdir, 'uuv_received_target.wav'), result.received.target_uPa, params.fs);
uuv_write_wav(fullfile(outdir, 'uuv_received_mix.wav'), result.received.mix_uPa, params.fs);

plot_source_spectrum(result, params, fullfile(outdir, 'uuv_source_spectrum.png'));
plot_waveforms(result, params, fullfile(outdir, 'uuv_waveforms.png'));
plot_spectrogram(result, params, fullfile(outdir, 'uuv_spectrogram.png'));
plot_lofar(result, params, fullfile(outdir, 'uuv_lofar.png'));
plot_demon(result, params, fullfile(outdir, 'uuv_demon.png'));
plot_source_geometry_3d(result, params, fullfile(outdir, 'uuv_source_geometry_3d.png'));
plot_summary(result, params, fullfile(outdir, 'uuv_summary.png'));
end

function write_spectrum_csv(result, filename)
f = result.spectrum.f_hz;
idx = spectrum_export_index(numel(f), 50000);
T = table(f(idx), ...
    result.spectrum.total_db(idx), ...
    result.spectrum.machine_db(idx), ...
    result.spectrum.prop_db(idx), ...
    result.spectrum.flow_db(idx), ...
    result.spectrum.line_db(idx), ...
    result.propagation.tl_db(idx), ...
    result.spectrum.total_db(idx) - result.propagation.tl_db(idx), ...
    'VariableNames', {'frequency_hz', 'SL_total_db_re_1uPa2_per_Hz', ...
    'SL_machine_db', 'SL_prop_cavitation_db', 'SL_flow_db', ...
    'SL_tonal_lines_db', 'TL_preview_db', 'RL_preview_db'});
writetable(T, filename);
end

function idx = spectrum_export_index(n, max_rows)
if n <= max_rows
    idx = (1:n).';
else
    idx = unique(round(linspace(1, n, max_rows))).';
end
end

function write_tone_csv(result, filename)
names = result.spectrum.tones.name(:);
freq = result.spectrum.tones.frequency_hz(:);
level = result.spectrum.tones.level_db(:);
T = table(names, freq, level, ...
    'VariableNames', {'name', 'frequency_hz', 'line_level_db_re_1uPa2'});
writetable(T, filename);
end

function write_geometry_csv(result, filename)
idx = (1:result.geometry.num_elements).';
xyz = result.geometry.element_xyz_m;
weight = result.geometry.weight(:);
range_m = result.propagation.element_range_m(:);
delay_s = result.propagation.element_delay_s(:);
T = table(idx, xyz(:, 1), xyz(:, 2), xyz(:, 3), weight, range_m, delay_s, ...
    'VariableNames', {'element_index', 'x_m', 'y_m', 'z_m', ...
    'power_weight', 'receiver_range_m', 'receiver_delay_s'});
writetable(T, filename);
end

function write_description(result, params, filename)
fid = fopen(filename, 'w');
if fid < 0
    warning('Could not write description file: %s', filename);
    return;
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'UUV equivalent-source radiated-noise model\n');
fprintf(fid, '==========================================\n\n');
fprintf(fid, 'Equivalent source type: %s\n', result.geometry.type);
fprintf(fid, 'Number of source elements: %d\n', result.geometry.num_elements);
fprintf(fid, 'Sampling rate: %.0f Hz\n', params.fs);
fprintf(fid, 'Duration: %.2f s\n\n', params.duration_s);

fprintf(fid, 'This is not arbitrary white noise.\n');
fprintf(fid, 'It is a semi-empirical UUV target radiated-noise signal composed of:\n');
fprintf(fid, '1. Machinery broadband noise.\n');
fprintf(fid, '2. Machinery/electric-motor tonal lines.\n');
fprintf(fid, '3. Shaft-frequency tonal lines.\n');
fprintf(fid, '4. Propeller blade-pass-frequency (BPF) tonal lines and harmonics.\n');
fprintf(fid, '5. Modulated propeller/cavitation broadband noise for DEMON features.\n');
fprintf(fid, '6. Hull-flow broadband noise.\n\n');

fprintf(fid, 'Key features:\n');
fprintf(fid, 'Shaft frequency: %.3f Hz\n', result.features.shaft_hz);
fprintf(fid, 'Blade-pass frequency: %.3f Hz\n', result.features.bpf_hz);
fprintf(fid, 'Tip speed: %.3f m/s\n', result.features.tip_speed_mps);
fprintf(fid, 'Cavitation activity index: %.3f\n', result.features.cavitation_activity);
fprintf(fid, 'Preview SNR: %.3f dB\n\n', result.metrics.preview_snr_db);

fprintf(fid, 'Main files:\n');
fprintf(fid, 'uuv_source_signal.wav: 1 m equivalent source signal preview.\n');
fprintf(fid, 'uuv_received_target.wav: simplified propagated target signal preview.\n');
fprintf(fid, 'uuv_received_mix.wav: target plus ambient preview signal.\n');
fprintf(fid, 'uuv_source_spectrum.csv: source-level spectrum and preview received level.\n');
fprintf(fid, 'uuv_tonal_lines.csv: shaft, BPF, and motor tonal-line table.\n');
fprintf(fid, 'uuv_source_geometry.csv: equivalent source element coordinates and weights.\n');
end

function plot_source_spectrum(result, params, filename)
fig = new_fig();
f = result.spectrum.f_hz;
mask = f >= 5 & f <= params.fs/2;
semilogx(f(mask), result.spectrum.total_db(mask), 'k', 'LineWidth', 1.4); hold on;
semilogx(f(mask), result.spectrum.prop_db(mask), 'Color', [0.00 0.45 0.74], 'LineWidth', 1.0);
semilogx(f(mask), result.spectrum.machine_db(mask), 'Color', [0.85 0.33 0.10], 'LineWidth', 1.0);
semilogx(f(mask), result.spectrum.flow_db(mask), 'Color', [0.47 0.67 0.19], 'LineWidth', 1.0);
grid on;
xline(result.features.shaft_hz, '--', 'shaft');
xline(result.features.bpf_hz, '--', 'BPF');
xlabel('Frequency [Hz]');
ylabel('Source level [dB re 1 uPa^2/Hz @ 1 m]');
title('UUV equivalent point-source spectrum');
legend({'Total', 'Propeller/cavitation broadband', 'Machinery broadband', 'Flow broadband'}, ...
    'Location', 'southwest');
safe_export(fig, filename);
end

function plot_waveforms(result, params, filename)
fig = new_fig();
t = result.time_s;
nshow = min(numel(t), round(2 * params.fs));
subplot(3, 1, 1);
plot(t(1:nshow), result.source.source_signal_uPa(1:nshow), 'k');
grid on; ylabel('uPa'); title('Source signal @ 1 m');
subplot(3, 1, 2);
plot(t(1:nshow), result.received.target_uPa(1:nshow), 'Color', [0 0.45 0.74]);
grid on; ylabel('uPa'); title(sprintf('Received target preview, range %.1f m', result.propagation.range_m));
subplot(3, 1, 3);
plot(t(1:nshow), result.received.mix_uPa(1:nshow), 'Color', [0.85 0.33 0.10]);
grid on; xlabel('Time [s]'); ylabel('uPa'); title('Received target + ambient preview');
safe_export(fig, filename);
end

function plot_spectrogram(result, params, filename)
fig = new_fig();
x = result.source.source_signal_uPa;
win_len = min(2048, numel(x));
win = hann(win_len, 'periodic');
noverlap = min(floor(0.75 * win_len), win_len - 1);
nfft = max(4096, 2^nextpow2(win_len));
[S, F, T] = spectrogram(x, win, noverlap, nfft, params.fs);
imagesc(T, F/1000, 20*log10(abs(S) + eps));
axis xy; colorbar;
ylim([0, min(8, params.fs/2000)]);
xlabel('Time [s]');
ylabel('Frequency [kHz]');
title('UUV source spectrogram');
safe_export(fig, filename);
end

function plot_lofar(result, params, filename)
fig = new_fig();
x = result.source.source_signal_uPa;
win_len = min(8192, numel(x));
win = hann(win_len, 'periodic');
noverlap = min(floor(0.875 * win_len), win_len - 1);
nfft = max(8192, 2^nextpow2(win_len));
[S, F, T] = spectrogram(x, win, noverlap, nfft, params.fs);
imagesc(T, F, 20*log10(abs(S) + eps));
axis xy; colorbar;
ylim([0, min(1000, params.fs/2)]);
xlabel('Time [s]');
ylabel('Frequency [Hz]');
title('LOFAR-style low-frequency display');
hold on;
yline(result.features.shaft_hz, 'w--', 'shaft');
yline(result.features.bpf_hz, 'w--', 'BPF');
safe_export(fig, filename);
end

function plot_demon(result, params, filename)
fig = new_fig();
x = result.source.source_signal_uPa;
f1 = max(2 * result.features.bpf_hz, 80);
f2 = min(8000, params.fs/2 * 0.90);
if f1 >= f2
    f1 = max(50, result.features.bpf_hz);
end

xb = fft_bandpass(x, params.fs, [f1, f2]);
if exist('hilbert', 'file')
    env = abs(hilbert(xb));
else
    env = abs(xb);
end
env = env - mean(env);

n = numel(env);
nfft = 2^nextpow2(n);
E = abs(fft(env .* hann(n, 'periodic'), nfft));
f = (0:nfft-1)' * params.fs / nfft;
mask = f >= 0 & f <= 500;

plot(f(mask), 20*log10(E(mask) + eps), 'k');
grid on;
xline(result.features.shaft_hz, '--', 'shaft');
xline(result.features.bpf_hz, '--', 'BPF');
xline(2*result.features.bpf_hz, '--', '2BPF');
xlabel('Modulation frequency [Hz]');
ylabel('Envelope spectrum [dB]');
title(sprintf('DEMON preview, band %.0f-%.0f Hz', f1, f2));
safe_export(fig, filename);
end

function plot_source_geometry_3d(result, params, filename)
fig = new_fig();
src = result.geometry.center_xyz_m;
rx = params.geometry.receiver_xyz_m;
xyz = result.geometry.element_xyz_m;
w = result.geometry.weight(:);

subplot(1, 2, 1);
[xs, ys, zs] = sphere(60);
radii = [40, 120, 260];
hold on;
for k = 1:numel(radii)
    r = radii(k);
    c = -20*log10(r) * ones(size(xs));
    surf(src(1) + r*xs, src(2) + r*ys, src(3) + r*zs, c, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.15 + 0.08*k);
end
scatter3(xyz(:,1), xyz(:,2), xyz(:,3), 24 + 120*w/max(w), w, 'filled', ...
    'MarkerFaceAlpha', 0.72);
plot3(src(1), src(2), src(3), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
plot3(rx(1), rx(2), rx(3), 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 7);
plot3([src(1), rx(1)], [src(2), rx(2)], [src(3), rx(3)], 'r--', 'LineWidth', 1.2);
grid on; axis equal; view(35, 20); colorbar;
xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]');
title(sprintf('Propagation overview, range %.1f m', result.propagation.range_m));
legend({'Radiation shells', '', '', 'Source elements', 'Source center', 'Receiver'}, ...
    'Location', 'best');

subplot(1, 2, 2);
plot_local_source_geometry(result, params);
safe_export(fig, filename);
end

function plot_local_source_geometry(result, params)
local = result.geometry.local_xyz_m;
w = result.geometry.weight(:);
hold on;
draw_uuv_reference_body(params);

if result.geometry.num_elements == 1
    scatter3(local(:,1), local(:,2), local(:,3), 180, w, 'filled', ...
        'MarkerEdgeColor', 'k');
else
    scatter3(local(:,1), local(:,2), local(:,3), 28 + 180*w/max(w), w, 'filled', ...
        'MarkerFaceAlpha', 0.82, 'MarkerEdgeAlpha', 0.15);
end

axis equal; grid on; view(35, 22); colorbar;
xlim(0.58 * [-params.source.length_m, params.source.length_m]);
r = max(params.source.diameter_m / 2, 0.1);
ylim(1.35 * [-r, r]);
zlim(1.35 * [-r, r]);
xlabel('body x [m]');
ylabel('body y [m]');
zlabel('body z [m]');
title(sprintf('%s equivalent source, %d elements', ...
    result.geometry.type, result.geometry.num_elements));
end

function draw_uuv_reference_body(params)
len = params.source.length_m;
rad = params.source.diameter_m / 2;
[cyl_y, cyl_z, cyl_x] = cylinder(rad, 48);
cyl_x = (cyl_x - 0.5) * len;
surf(cyl_x, cyl_y, cyl_z, 'FaceColor', [0.78 0.82 0.86], ...
    'FaceAlpha', 0.12, 'EdgeColor', [0.55 0.60 0.65], 'EdgeAlpha', 0.18);
plot3([-len/2, len/2], [0, 0], [0, 0], 'k-', 'LineWidth', 1.2);
plot3([-len/2, -len/2], [0, 0], [-rad, rad], 'k:', 'LineWidth', 0.9);
plot3([len/2, len/2], [0, 0], [-rad, rad], 'k:', 'LineWidth', 0.9);
end

function plot_summary(result, params, filename)
fig = new_fig();
f = result.spectrum.f_hz;
mask = f >= 5 & f <= min(10000, params.fs/2);

subplot(2, 2, 1);
semilogx(f(mask), result.spectrum.total_db(mask), 'k');
grid on; xlabel('Hz'); ylabel('SL [dB]'); title('Source spectrum');

subplot(2, 2, 2);
nshow = min(numel(result.time_s), params.fs);
plot(result.time_s(1:nshow), result.source.source_signal_uPa(1:nshow));
grid on; xlabel('s'); ylabel('uPa'); title('Source waveform');

subplot(2, 2, 3);
bar([result.metrics.source_rms_uPa, result.metrics.received_target_rms_uPa, ...
    result.metrics.ambient_rms_uPa, result.metrics.received_mix_rms_uPa]);
set(gca, 'XTickLabel', {'source', 'target rx', 'ambient', 'mix'});
ylabel('RMS [uPa]'); title(sprintf('Preview SNR %.1f dB', result.metrics.preview_snr_db));
grid on;

subplot(2, 2, 4);
stem(result.spectrum.tones.frequency_hz, result.spectrum.tones.level_db, 'filled');
xlim([0, min(800, params.fs/2)]);
grid on; xlabel('Hz'); ylabel('Line level [dB]'); title('Tonal lines');

safe_export(fig, filename);
end

function xb = fft_bandpass(x, fs, band_hz)
n = numel(x);
f = (0:n-1)' * fs / n;
fm = min(f, fs - f);
H = double(fm >= band_hz(1) & fm <= band_hz(2));
xb = real(ifft(fft(x) .* H));
end

function fig = new_fig()
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1200, 820]);
end

function safe_export(fig, filename)
try
    exportgraphics(fig, filename, 'Resolution', 200);
catch
    saveas(fig, filename);
end
close(fig);
end
