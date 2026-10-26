function v = get_24cell_vertices()
% GET_24CELL_VERTICES  Return the 24 vertices of the 24-cell
%
% The 24-cell is the unique regular polytope in 4D that has no analog in
% other dimensions. It is self-dual and its vertices form the binary
% tetrahedral group when interpreted as unit quaternions.
%
% Output:
%   v - (4 × 24) matrix where each column is a vertex on S³
%
% The 24 vertices consist of:
%   - 8 permutations of (±1, 0, 0, 0) - hyperoctahedron/16-cell vertices
%   - 16 combinations of (±½, ±½, ±½, ±½) - tesseract/8-cell vertices
%
% Geometric properties:
%   - All vertices lie on S³ (unit 3-sphere)
%   - Each vertex is equidistant from its 8 nearest neighbors
%   - Geodesic distance to nearest neighbors: π/3 (60°)
%   - The Voronoi cell is the 24-cell itself (self-dual)
%   - Optimal for minimax polynomial approximation on S³
%
% As quaternions:
%   - The 8 hyperoctahedron vertices include ±1, ±i, ±j, ±k
%   - The 16 tesseract vertices are primitive 6th roots of unity
%   - Together they form the binary tetrahedral group 2T
%
% Example:
%   v = get_24cell_vertices();
%   plot_on_S3(v);  % Visualize (requires custom plotting)

    % 8 hyperoctahedron vertices: permutations of (±1, 0, 0, 0)
    v_hyper = [eye(4), -eye(4)];
    
    % 16 tesseract vertices: all (±1/2, ±1/2, ±1/2, ±1/2)
    % Generate all 16 sign combinations
    n_tess = 16;
    v_tess = zeros(4, n_tess);
    for i = 0:15
        signs = 2 * bitget(i, 1:4) - 1;  % Convert bits to ±1
        v_tess(:, i+1) = 0.5 * signs(:);
    end
    
    % Combine
    v = [v_hyper, v_tess];
end
