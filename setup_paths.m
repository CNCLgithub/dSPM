function setup_paths()
% SETUP_PATHS  Put this project's code on the MATLAB path.
%
%   setup_paths()
%
% Adds scripts/ and its subfolders, and only core/ of the bundled
% dspm_reservoir package (scripts/create-dspm-networks/dspm-reservoir-matlab).
% The rest of the package stays off the path: utils/code_jasonKim_final/ and
% verify/helpers/ hold other versions of ReservoirTanhB_dc, gen_basis,
% sym2deriv, decomp_poly1_ns and tanh_deriv that would shadow the ones in
% scripts/dependencies/. programming_gui() adds its own GUI folders when called.
%
% data/ and hpc-outputs/ are also left off: data/phys contains third-party
% code whose function names can shadow ours. Scripts load data by relative
% path from their own folder.

root    = fileparts(mfilename('fullpath'));
pkg     = fullfile(root, 'scripts', 'create-dspm-networks', 'dspm-reservoir-matlab');

dirs = strsplit(genpath(fullfile(root, 'scripts')), pathsep);
dirs = dirs(~cellfun(@isempty, dirs) & ~startsWith(dirs, pkg));
addpath(dirs{:});
addpath(fullfile(pkg, 'core'));
addpath(fullfile(root, 'figures'));
end
