function qImage = quantize_blocks(dctImage, Q, blockSize)

[rows, cols] = size(dctImage);
qImage = zeros(rows, cols);

for i = 1:blockSize:rows
    for j = 1:blockSize:cols

        block = dctImage(i:i+blockSize-1, j:j+blockSize-1);

        qBlock = round(block ./ Q);

        qImage(i:i+blockSize-1, j:j+blockSize-1) = qBlock;
    end
end

end
