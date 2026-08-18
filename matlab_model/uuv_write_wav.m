function uuv_write_wav(filename, x, fs)
% UUV_WRITE_WAV Write a normalized preview WAV file.

x = x(:);
peak = max(abs(x));
if peak > 0
    x = 0.8 * x / peak;
end
audiowrite(filename, x, fs);
end

