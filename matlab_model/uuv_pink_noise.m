function x = uuv_pink_noise(n, fs, slope_db_decade)
% UUV_PINK_NOISE Generate normalized colored noise by frequency shaping.

df = fs / n;
n_pos = floor(n/2) + 1;
f = (0:n_pos-1)' * df;
f_safe = max(f, 1);

shape_db = slope_db_decade * log10(f_safe / 1000);
shape = 10.^(shape_db / 10);
shape(1) = 0;

X = zeros(n, 1);
if mod(n, 2) == 0
    pos = (2:n_pos-1)';
else
    pos = (2:n_pos)';
end

amp = sqrt(2 * shape(pos) * df);
phase = 2*pi*rand(numel(pos), 1);
X(pos) = (n/2) * amp .* exp(1i * phase);
mirror = n - pos + 2;
X(mirror) = conj(X(pos));

x = real(ifft(X));
x = x / max(sqrt(mean(x.^2)), eps);
end

