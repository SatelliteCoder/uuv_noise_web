function result = uuv_run_model(params)
% UUV_RUN_MODEL Generate UUV source spectrum, source signal, and previews.

rng(params.random_seed);

fs = params.fs;
n = round(params.fs * params.duration_s);
t = (0:n-1)' / fs;

spectrum = uuv_source_spectrum(params, n);
source = uuv_synthesize_source_signal(params, spectrum, t);
geometry = uuv_source_geometry(params);

[target_rx_uPa, propagation] = uuv_apply_propagation( ...
    source.source_signal_uPa, fs, spectrum.f_hz, params, geometry);

if params.ambient.enabled
    ambient_uPa = uuv_pink_noise(n, fs, params.ambient.slope_db_decade);
    ambient_uPa = ambient_uPa / rms_safe(ambient_uPa) * params.ambient.rms_uPa;
else
    ambient_uPa = zeros(n, 1);
end

received_mix_uPa = target_rx_uPa + ambient_uPa;

result = struct();
result.params = params;
result.time_s = t;
result.spectrum = spectrum;
result.source = source;
result.geometry = geometry;
result.propagation = propagation;
result.received.target_uPa = target_rx_uPa;
result.received.ambient_uPa = ambient_uPa;
result.received.mix_uPa = received_mix_uPa;
result.features = spectrum.features;

result.metrics.source_rms_uPa = rms_safe(source.source_signal_uPa);
result.metrics.received_target_rms_uPa = rms_safe(target_rx_uPa);
result.metrics.ambient_rms_uPa = rms_safe(ambient_uPa);
result.metrics.received_mix_rms_uPa = rms_safe(received_mix_uPa);
result.metrics.preview_snr_db = 20 * log10( ...
    result.metrics.received_target_rms_uPa / max(result.metrics.ambient_rms_uPa, eps));
end

function y = rms_safe(x)
y = sqrt(mean(x(:).^2));
end
