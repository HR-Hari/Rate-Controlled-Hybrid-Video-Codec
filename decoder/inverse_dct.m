function reconImage = inverse_dct(dctImage, blockSize)

[rows, cols] = size(dctImage);
reconImage = zeros(rows, cols);

for i = 1:blockSize:rows
    for j = 1:blockSize:cols

        block = dctImage(i:i+blockSize-1, j:j+blockSize-1);

        % 2D IDCT using 1D IDCT
        idctBlock = idct(idct(block).').';

        reconImage(i:i+blockSize-1, j:j+blockSize-1) = idctBlock;
    end
end

end
