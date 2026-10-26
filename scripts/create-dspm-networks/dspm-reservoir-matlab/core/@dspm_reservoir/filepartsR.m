function path = filepartsR(path,depth)
% this helper function takes a path like path/to/dir/foo/bar.m
% and it runs fileparts() recursively back to a given depth to get
% the path strings for parent directories.
% e.g. filepartsR("path/to/dir/foo/bar.m",depth) -> "path/to/dir"
      
    for i = 1:depth
        path = fileparts(path);
    end

end
