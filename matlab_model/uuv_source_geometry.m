function geometry = uuv_source_geometry(params)
% UUV_SOURCE_GEOMETRY Build point, line, surface, or volume source elements.
%
% The element weights are power weights and sum to one. The propagation
% preview uses sqrt(weight) as the pressure-amplitude split per element.

source = params.source;
if isfield(params.geometry, 'source_xyz_m') && ~isfield(source, 'center_xyz_m')
    source.center_xyz_m = params.geometry.source_xyz_m;
end

type = lower(string(source.type));
center = row3(source.center_xyz_m);
heading = deg2rad(source.heading_deg);
axis_u = [cos(heading), sin(heading), 0];
cross_u = [-sin(heading), cos(heading), 0];
up_u = [0, 0, 1];

switch char(type)
    case 'point'
        local_xyz = [0, 0, 0];
        weights = 1;

    case 'line'
        n = max(2, round(source.line_elements));
        x = linspace(-source.length_m/2, source.length_m/2, n)';
        local_xyz = [x, zeros(n, 1), zeros(n, 1)];
        weights = axial_weights(x, source.length_m, source.weighting);

    case 'surface'
        nx = max(2, round(source.surface_axial_elements));
        nt = max(4, round(source.surface_circum_elements));
        x = linspace(-source.length_m/2, source.length_m/2, nx)';
        theta = linspace(0, 2*pi, nt + 1);
        theta(end) = [];
        [X, TH] = ndgrid(x, theta);
        r = source.diameter_m / 2;
        local_xyz = [X(:), r*cos(TH(:)), r*sin(TH(:))];
        wx = axial_weights(X(:), source.length_m, source.weighting);
        weights = wx / nt;

    case 'volume'
        nx = max(2, round(source.volume_axial_elements));
        nr = max(1, round(source.volume_radial_elements));
        nt = max(4, round(source.volume_circum_elements));
        x = linspace(-source.length_m/2, source.length_m/2, nx)';
        rho = linspace(0, 1, nr + 1);
        rho = rho(2:end);
        theta = linspace(0, 2*pi, nt + 1);
        theta(end) = [];
        [X, RHO, TH] = ndgrid(x, rho, theta);
        r = (source.diameter_m / 2) * sqrt(RHO);
        local_xyz = [X(:), r(:).*cos(TH(:)), r(:).*sin(TH(:))];
        wx = axial_weights(X(:), source.length_m, source.weighting);
        weights = wx .* max(r(:), source.diameter_m / (4 * nr));

    otherwise
        error('uuv_source_geometry:badType', ...
            'Unsupported source.type "%s". Use point, line, surface, or volume.', source.type);
end

weights = weights(:);
weights = max(weights, 0);
weights = weights / sum(weights);

R = [axis_u(:), cross_u(:), up_u(:)];
positions = center + local_xyz * R.';

geometry = struct();
geometry.type = char(type);
geometry.center_xyz_m = center;
geometry.axis_unit = axis_u;
geometry.cross_unit = cross_u;
geometry.up_unit = up_u;
geometry.local_xyz_m = local_xyz;
geometry.element_xyz_m = positions;
geometry.weight = weights;
geometry.num_elements = size(positions, 1);
geometry.length_m = source.length_m;
geometry.diameter_m = source.diameter_m;
geometry.description = sprintf('%s source with %d elements', char(type), geometry.num_elements);
end

function w = axial_weights(x, length_m, weighting)
mode = lower(string(weighting));
switch char(mode)
    case 'uniform'
        w = ones(size(x));
    otherwise
        xi = 2 * x / max(length_m, eps);
        w = 0.25 + 0.75 * cos(0.5*pi*max(min(xi, 1), -1)).^2;
end
end

function x = row3(x)
x = x(:).';
if numel(x) ~= 3
    error('uuv_source_geometry:badVector', 'Expected a 1x3 vector.');
end
end
