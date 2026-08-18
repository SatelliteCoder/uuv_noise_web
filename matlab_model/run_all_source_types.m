% RUN_ALL_SOURCE_TYPES
% Generate point, line, surface, and volume UUV radiated-noise cases.

clear; close all; clc;

types = {'point', 'line', 'surface', 'volume'};
for k = 1:numel(types)
    run_uuv_source_case(types{k});
end

fprintf('\nAll requested source types finished.\n');

