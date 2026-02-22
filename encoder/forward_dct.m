function dctImage = forward_dct(img, blockSize)

[rows, cols] = size(img);
dctImage = zeros(rows, cols);

for i = 1:blockSize:rows
    for j = 1:blockSize:cols

        block = img(i:i+blockSize-1, j:j+blockSize-1);

        % 2D DCT using 1D DCT
        dctBlock = dct(dct(block).').';

        dctImage(i:i+blockSize-1, j:j+blockSize-1) = dctBlock;
    end
end

end
