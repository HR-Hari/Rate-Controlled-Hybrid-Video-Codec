function total_bits = estimate_bits(qImg, blockSize, zigzag_idx, rows, cols)
%
% Estimates compressed bitrate using:
%   1. Zigzag scan of each 8x8 quantised block
%   2. Run-Length Encoding (RLE) of AC coefficients
%   3. Shannon entropy of resulting symbol stream
%
% This is a realistic proxy for Huffman-coded bitstream size.

all_rle_symbols = [];

for i = 1:blockSize:rows
    for j = 1:blockSize:cols
        block = qImg(i:i+blockSize-1, j:j+blockSize-1);
        flat  = block(zigzag_idx);

        % DC coefficient ¡ª variable length based on magnitude
        dc_coeff = flat(1);
        dc_bits  = max(1, ceil(log2(abs(dc_coeff) + 1)) + 1);
        all_rle_symbols(end+1) = dc_bits;

        % AC coefficients ¡ª RLE encoded
        ac_coeffs = flat(2:end);
        run = 0;
        for k = 1:length(ac_coeffs)
            coeff = ac_coeffs(k);
            if coeff == 0
                run = run + 1;
            else
                level_bits = ceil(log2(abs(coeff) + 1)) + 1;
                symbol = run * 100 + level_bits;
                all_rle_symbols(end+1) = symbol;
                run = 0;
            end
        end
        all_rle_symbols(end+1) = -1;  % EOB
    end
end

% Shannon entropy estimation
unique_syms  = unique(all_rle_symbols);
total_syms   = length(all_rle_symbols);
entropy_H    = 0;
for s = 1:length(unique_syms)
    p = sum(all_rle_symbols == unique_syms(s)) / total_syms;
    entropy_H = entropy_H - p * log2(p);
end

total_bits = ceil(entropy_H * total_syms);
end

