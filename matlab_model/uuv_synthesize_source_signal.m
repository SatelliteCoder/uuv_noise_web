function source = uuv_synthesize_source_signal(params, spectrum, t)
% UUV_SYNTHESIZE_SOURCE_SIGNAL Generate a time-domain UUV source waveform.

fs = params.fs;
n = numel(t);

prop_noise = synthesize_from_psd(spectrum.f_hz, spectrum.prop_psd, fs, n);
machine_noise = synthesize_from_psd(spectrum.f_hz, spectrum.machine_psd, fs, n);
flow_noise = synthesize_from_psd(spectrum.f_hz, spectrum.flow_psd, fs, n);

envelope = 1 ...
    + params.cavitation.mod_bpf_depth * spectrum.features.cavitation_activity ...
        * cos(2*pi*spectrum.features.bpf_hz*t + 0.2) ...
    + params.cavitation.mod_shaft_depth * spectrum.features.cavitation_activity ...
        * cos(2*pi*spectrum.features.shaft_hz*t + 1.1);
envelope = max(envelope, 0.05);
envelope = envelope / rms_safe(envelope);
prop_noise = prop_noise .* envelope;

tonal = zeros(n, 1);
for k = 1:numel(spectrum.tones.frequency_hz)
    f0 = spectrum.tones.frequency_hz(k);
    line_power = 10^(spectrum.tones.level_db(k) / 10);
    amp = sqrt(2 * line_power);
    phase = 2*pi*rand();
    tonal = tonal + amp * cos(2*pi*f0*t + phase);
end

source_signal = prop_noise + machine_noise + flow_noise + tonal;

source = struct();
source.source_signal_uPa = source_signal;
source.prop_noise_uPa = prop_noise;
source.machine_noise_uPa = machine_noise;
source.flow_noise_uPa = flow_noise;
source.tonal_uPa = tonal;
source.envelope = envelope;
end

function x = synthesize_from_psd(f_hz, psd, fs, n)
% Create a real time series whose one-sided PSD approximately follows psd.
df = fs / n;
n_pos = floor(n/2) + 1;
f_bins = (0:n_pos-1)' * df;
s_bins = interp1(f_hz, psd, f_bins, 'linear', 'extrap');
s_bins = max(s_bins, 0);

X = zeros(n, 1);
if mod(n, 2) == 0
    pos = (2:n_pos-1)';
else
    pos = (2:n_pos)';
end

amp = sqrt(2 * s_bins(pos) * df);
phase = 2*pi*rand(numel(pos), 1);
X(pos) = (n/2) * amp .* exp(1i * phase);
mirror = n - pos + 2;
X(mirror) = conj(X(pos));

x = real(ifft(X));
end

function y = rms_safe(x)
y = sqrt(mean(x(:).^2));
end

