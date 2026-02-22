clear;
clc;
close all;
pkg load signal   % Required for dct() and idct()
addpath('encoder');
addpath('decoder');

%% -------------------------------------------------
% GUI Image Selection
%% -------------------------------------------------
[filename, pathname] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.bmp', 'Image Files (*.png, *.jpg, *.bmp)'}, ...
    'Select an Image');
if isequal(filename,0)
    error('No image selected.');
end
img = imread(fullfile(pathname, filename));

% Convert to grayscale if RGB
if size(img,3) == 3
    img = rgb2gray(img);
end
img = double(img);

%% -------------------------------------------------
% Block Setup and Padding
%% -------------------------------------------------
blockSize = 8;
[rows, cols] = size(img);

padRows = mod(rows, blockSize);
padCols = mod(cols, blockSize);
if padRows ~= 0
    img(end+1:end+(blockSize-padRows), :) = 0;
end
if padCols ~= 0
    img(:, end+1:end+(blockSize-padCols)) = 0;
end

[paddedRows, paddedCols] = size(img);

%% -------------------------------------------------
% Display Original Image
%% -------------------------------------------------
figure;
imshow(uint8(img));
title('Original Image');

%% -------------------------------------------------
% DC Level Shift
%% -------------------------------------------------
img_shifted = img - 128;

%% -------------------------------------------------
% Channel Constraint
%% -------------------------------------------------
channel_bitrate = 430000;   % 300 + 130 -e20130 kbps = 430000 bits per second = bits per image

%% -------------------------------------------------
% Build Zigzag Scan Index Map
%% -------------------------------------------------

zigzag_idx = zigzag_order(blockSize);
% zigzag_idx is a 64-element vector of linear indices into an 8x8 block

%% -------------------------------------------------
% Test Quantisation Levels
%% -------------------------------------------------
levels = [1 2 3];
PSNR_values   = zeros(1, length(levels));
bitrate_values = zeros(1, length(levels));

fprintf('Image size (after padding): %d x %d pixels\n', paddedRows, paddedCols);
fprintf('Channel bitrate budget: %d bits\n\n', channel_bitrate);

for idx = 1:length(levels)
    level = levels(idx);
    Q = get_quant_matrix(level);

    %% ---------- ENCODER ----------

    % Step 1: Forward DCT on all 8x8 blocks
    dctImg = forward_dct(img_shifted, blockSize);

    % Step 2: Quantise all blocks (divide by Q matrix, round to integer)
    qImg = quantize_blocks(dctImg, Q, blockSize);

    %% ---------- BITRATE ESTIMATION (Zigzag + RLE + Entropy) ----------


    all_rle_symbols = [];   % will collect all RLE (run, level) pairs

    for i = 1:blockSize:paddedRows
        for j = 1:blockSize:paddedCols
            % Extract quantised block
            block = qImg(i:i+blockSize-1, j:j+blockSize-1);

            flat = block(zigzag_idx);


            % Separate DC and AC
            dc_coeff = flat(1);
            ac_coeffs = flat(2:end);

            % --- DC Coding ---

            dc_bits = max(1, ceil(log2(abs(dc_coeff) + 1)) + 1);
            all_rle_symbols(end+1) = dc_bits;   %#ok store bit cost as symbol

            % --- AC Coding via RLE ---
            % Scan AC coefficients (positions 2¨C64 in zigzag order)
            run = 0;    % count of consecutive zeros
            for k = 1:length(ac_coeffs)
                coeff = ac_coeffs(k);
                if coeff == 0
                    run = run + 1;  % increment zero run counter
                else

                    level_bits = ceil(log2(abs(coeff) + 1)) + 1;
                    % Pack run and level_bits into one symbol for entropy estimation
                    % (in real JPEG these are Huffman coded jointly)
                    symbol = run * 100 + level_bits;
                    all_rle_symbols(end+1) = symbol;  %#ok
                    run = 0;    % reset run counter after emitting
                end
            end
            % End-of-Block (EOB) marker: signals remaining coefficients are zero
            % In JPEG this is a special Huffman code; we count it as 1 symbol
            all_rle_symbols(end+1) = -1;  %#ok  -1 = EOB marker
        end
    end

    %% Shannon Entropy-Based Bit Estimation

    unique_symbols = unique(all_rle_symbols);
    total_symbols  = length(all_rle_symbols);
    entropy_H      = 0;

    for s = 1:length(unique_symbols)
        count = sum(all_rle_symbols == unique_symbols(s));
        p = count / total_symbols;
        entropy_H = entropy_H - p * log2(p);
    end

    total_bits = ceil(entropy_H * total_symbols);
    bitrate_values(idx) = total_bits;

    %% ---------- DECODER ----------
    deqImg   = dequantize_blocks(qImg, Q, blockSize);
    reconImg = inverse_dct(deqImg, blockSize);
    reconImg = reconImg + 128;
    reconImg = min(max(reconImg, 0), 255);

    %% ---------- QUALITY EVALUATION ----------
    MSE  = mean((img(:) - reconImg(:)).^2);
    if MSE == 0
        PSNR = Inf;
    else
        PSNR = 10 * log10(255^2 / MSE);
    end
    PSNR_values(idx) = PSNR;

    %% ---------- PRINT RESULTS ----------
    fprintf('---------------------------------\n');
    fprintf('Level %d | Scale = %.1f\n', level, 0.5 * level);
    fprintf('PSNR            = %.2f dB\n', PSNR);
    fprintf('Entropy H       = %.4f bits/symbol\n', entropy_H);
    fprintf('Total Symbols   = %d\n', total_symbols);
    fprintf('Estimated Bits  = %d bits (%.1f kb)\n', total_bits, total_bits/1000);
    fprintf('Budget          = %d bits (%.1f kb)\n', channel_bitrate, channel_bitrate/1000);
    if total_bits <= channel_bitrate
        fprintf('Status: PASS - Channel constraint satisfied.\n');
    else
        fprintf('Status: FAIL - Exceeds channel budget by %d bits.\n', total_bits - channel_bitrate);
    end

    %% Save reconstructed image
    outputName = sprintf('reconstructed_level_%d.png', level);
    imwrite(uint8(reconImg), outputName);
    fprintf('Saved: %s\n', outputName);
end

%% -------------------------------------------------
% Plot PSNR vs Quantisation Level
%% -------------------------------------------------
figure;
plot(levels, PSNR_values, '-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Quantisation Level (1=High Q, 3=Low Q)');
ylabel('PSNR (dB)');
title('PSNR vs Quantisation Level');
grid on;

%% -------------------------------------------------
% Plot Bitrate vs Quantisation Level with budget line
%% -------------------------------------------------
figure;
plot(levels, bitrate_values/1000, '-o', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
plot([levels(1) levels(end)], [channel_bitrate/1000, channel_bitrate/1000], ...
    '--r', 'LineWidth', 1.5);
hold off;
xlabel('Quantisation Level (1=High Q, 3=Low Q)');
ylabel('Estimated Bitrate (kb)');
title('Bitrate vs Quantisation Level');
legend('Estimated Bitrate', 'Channel Budget (430 kb)', 'Location', 'northeast');
grid on;

%% -------------------------------------------------
% Stage 3.1.3 ¡ª Adaptive Bitrate: Binary Search for Best QP
%% -------------------------------------------------
%
% Problem: find the LARGEST scale factor (most aggressive quantisation)
% that still keeps total_bits <= channel_bitrate.
% Larger scale = lower PSNR but fewer bits.
% We binary search the scale between 0.1 and 20.
%
fprintf('\n=================================================\n');
fprintf('Adaptive Bitrate Search (Target: %d bits)\n', channel_bitrate);
fprintf('=================================================\n');

scale_low  = 0.1;
scale_high = 20.0;
best_scale = scale_high;
best_bits  = Inf;
best_PSNR  = 0;
best_recon = [];
    % Build quantisation matrix from this scale
    Qbase = [
        16 11 10 16 24 40 51 61;
        12 12 14 19 26 58 60 55;
        14 13 16 24 40 57 69 56;
        14 17 22 29 51 87 80 62;
        18 22 37 56 68 109 103 77;
        24 35 55 64 81 104 113 92;
        49 64 78 87 103 121 120 101;
        72 92 95 98 112 100 103 99];

for iter = 1:30   % 30 iterations gives precision of 20/2^30 ¡Ö negligible
    scale_mid = (scale_low + scale_high) / 2;


    Q_test = max(round(Qbase * scale_mid), 1);

    % Encode
    dctImg_t = forward_dct(img_shifted, blockSize);
    qImg_t   = quantize_blocks(dctImg_t, Q_test, blockSize);

    % Estimate bits using same zigzag+RLE+entropy method
    bits_test = estimate_bits(qImg_t, blockSize, zigzag_idx, paddedRows, paddedCols);

    if bits_test <= channel_bitrate
        % This scale fits ¡ª try less compression (lower scale)
        best_scale = scale_mid;
        best_bits  = bits_test;
        scale_high = scale_mid;

        % Decode and measure PSNR
        deqImg_t   = dequantize_blocks(qImg_t, Q_test, blockSize);
        reconImg_t = inverse_dct(deqImg_t, blockSize) + 128;
        reconImg_t = min(max(reconImg_t, 0), 255);
        MSE_t = mean((img(:) - reconImg_t(:)).^2);
        if MSE_t == 0
            best_PSNR = Inf;
        else
            best_PSNR = 10 * log10(255^2 / MSE_t);
        end
        best_recon = reconImg_t;
    else
        % Too many bits ¡ª need more compression (higher scale)
        scale_low = scale_mid;
    end
end

fprintf('Best scale found : %.4f\n', best_scale);
fprintf('Estimated bits   : %d (budget: %d)\n', best_bits, channel_bitrate);
fprintf('Best PSNR        : %.2f dB\n', best_PSNR);

if ~isempty(best_recon)
    figure;
    imshow(uint8(best_recon));
    title(sprintf('Adaptive Output | Scale=%.3f | PSNR=%.2f dB | Bits=%d', ...
        best_scale, best_PSNR, best_bits));
    imwrite(uint8(best_recon), 'reconstructed_adaptive.png');
    fprintf('Saved: reconstructed_adaptive.png\n');
else
    fprintf('WARNING: No valid encoding found within budget.\n');
end
