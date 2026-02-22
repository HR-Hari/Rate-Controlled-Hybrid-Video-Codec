function deqImage = dequantize_blocks(qImage, Q, blockSize)
[rows, cols] = size(qImage);
deqImage = zeros(rows, cols);
for i = 1:blockSize:rows
    for j = 1:blockSize:cols
        block = qImage(i:i+blockSize-1, j:j+blockSize-1);
        deqBlock = block .* Q;
        deqImage(i:i+blockSize-1, j:j+blockSize-1) = deqBlock;
    end
end
end
