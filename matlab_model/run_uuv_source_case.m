function result = run_uuv_source_case(source_type, varargin)
% RUN_UUV_SOURCE_CASE Run one UUV equivalent-source case.
%
% result = run_uuv_source_case(source_type)
% result = run_uuv_source_case(source_type, params)
%
% source_type must be: 'point', 'line', 'surface', or 'volume'.

if nargin < 1 || isempty(source_type)
    source_type = 'point';
end

if nargin >= 2 && ~isempty(varargin{1})
    params = varargin{1};
else
    params = uuv_default_params();
end

model_dir = fileparts(mfilename('fullpath'));
addpath(model_dir);

source_type = char(lower(string(source_type)));
valid_types = {'point', 'line', 'surface', 'volume'};
if ~any(strcmp(source_type, valid_types))
    error('run_uuv_source_case:badType', ...
        'source_type must be point, line, surface, or volume.');
end

params.source.type = source_type;
if ~isfield(params, 'output_dir') || isempty(params.output_dir)
    params.output_dir = fullfile(model_dir, 'output', source_type);
end

fprintf('\nRunning UUV %s equivalent-source noise model...\n', source_type);
fprintf('Noise content: machinery tones/broadband + shaft/BPF propeller tones + ');
fprintf('modulated propeller-cavitation broadband + flow broadband.\n');

result = uuv_run_model(params);
uuv_render_outputs(result, params);

fprintf('Output folder: %s\n', params.output_dir);
fprintf('Equivalent source type: %s\n', result.geometry.type);
fprintf('Source elements: %d\n', result.geometry.num_elements);
fprintf('Shaft frequency: %.2f Hz\n', result.features.shaft_hz);
fprintf('Blade-pass frequency: %.2f Hz\n', result.features.bpf_hz);
fprintf('Cavitation activity index: %.2f\n', result.features.cavitation_activity);
fprintf('Preview SNR: %.2f dB\n', result.metrics.preview_snr_db);
end
