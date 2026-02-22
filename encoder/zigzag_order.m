function idx = zigzag_order(n)
%
% Returns a vector of linear indices that read an n x n matrix
% in zigzag (diagonal) order, starting from top-left.
%
% For n=4, the zigzag reads positions in this order:
%
%   1  2  5  10
%   3  4  8  11       <- matrix positions
%   6  7  9  12       (numbers show read order)
%   13 14 15 16
%
% Zigzag diagonals alternate direction:
%   diagonal 1 (sum=2): (1,1)              ¡ú down
%   diagonal 2 (sum=3): (1,2),(2,1)        ¡ú up-right
%   diagonal 3 (sum=4): (3,1),(2,2),(1,3)  ¡ú down-left
%   diagonal 4 (sum=5): (1,4),(2,3),(3,2),(4,1) ¡ú ...
%   etc.

idx = zeros(1, n*n);
pos = 1;

for diag = 2:(2*n)   % diagonal index, sum of (row+col) goes from 2 to 2n
    if mod(diag, 2) == 0
        % Even diagonal: go DOWN-LEFT (row increases, col decreases)
        r_start = max(1, diag - n);
        r_end   = min(n, diag - 1);
        for r = r_start:r_end
            c = diag - r;
            idx(pos) = (c-1)*n + r;   % linear index (column-major for Octave/MATLAB)
            pos = pos + 1;
        end
    else
        % Odd diagonal: go UP-RIGHT (row decreases, col increases)
        r_start = min(n, diag - 1);
        r_end   = max(1, diag - n);
        for r = r_start:-1:r_end
            c = diag - r;
            idx(pos) = (c-1)*n + r;
            pos = pos + 1;
        end
    end
end
end
