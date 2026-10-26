function S = read_pca_js(js_file)
%READ_PCA_JS  Extract all variables needed by lda_geometry_analysis.m
%             from pca_data.js without JSON conversion.
%
%  Returns struct S with fields:
%    S.tvec_bs      [1 x ntbins]       ms time vector
%    S.bounce_wall  [1 x ntrials]      0=none 1=top 2=bottom
%    S.endpoint_y   [1 x ntrials]      final ball y position
%    S.sys_labels   {1 x nSystems}     system name strings
%    S.sys_colors   {1 x nSystems}     hex color strings
%    S.all_expl     {nEpochs x nSys}   [nPC x 1] variance explained
%    S.all_traj     {nEpochs x nSys}   [nPC x ntbins x ntrials] trajectories
%                                      (trimmed to each system's true PC count,
%                                       e.g. ballState → 2)

fprintf('Reading %s ...\n', js_file);
fid = fopen(js_file, 'r');
assert(fid ~= -1, 'Cannot open: %s', js_file);
raw = fread(fid, '*char')';
fclose(fid);
fprintf('  Read %.1f MB\n', numel(raw)/1e6);

%% ── Scalar fields ────────────────────────────────────────────────────
S.ntrials = extract_scalar(raw, 'ntrials');
S.nPC     = extract_scalar(raw, 'nPC');
S.dt      = extract_scalar(raw, 'dt');
fprintf('  ntrials=%d  nPC=%d  dt=%d ms\n', S.ntrials, S.nPC, S.dt);

%% ── 1D numeric arrays ────────────────────────────────────────────────
S.tvec_bs     = extract_num_array(raw, 'tvec');
S.bounce_wall = extract_num_array(raw, 'bounce_wall');
S.endpoint_y  = extract_num_array(raw, 'endpoint_y');
S.ydot0       = extract_num_array(raw, 'ydot0');
try
    S.bounceIdx = extract_num_array(raw, 'bounceIdx');   % validated nbounces (26)
catch
    S.bounceIdx = [];   % older JS without bounceIdx → LDA falls back to bounce_wall>0
end
fprintf('  tvec_bs: %d bins (%.0f–%.0f ms)\n', ...
    numel(S.tvec_bs), S.tvec_bs(1), S.tvec_bs(end));
fprintf('  bounce_wall: %d trials  endpoint_y: %d trials\n', ...
    numel(S.bounce_wall), numel(S.endpoint_y));

%% ── String arrays ────────────────────────────────────────────────────
S.sys_labels = extract_str_array(raw, 'system_labels');
S.sys_colors = extract_str_array(raw, 'system_colors');
S.nSystems   = numel(S.sys_labels);
fprintf('  Systems: ');
fprintf('%s  ', S.sys_labels{:}); fprintf('\n');

%% ── Traj and expl data ───────────────────────────────────────────────
epoch_keys = {'onset', 'transition', 'manifold'};
sys_keys   = extract_str_array(raw, 'system_keys');   % from JS meta (was hardcoded -> broke on rename)
nEpochs    = numel(epoch_keys);

S.all_traj = cell(nEpochs, S.nSystems);
S.all_expl = cell(nEpochs, S.nSystems);

% Pre-extract the data: { ... } block so epoch searches don't hit meta section
data_match = regexp(raw, 'data\s*:\s*\{', 'end', 'once');
assert(~isempty(data_match), 'Cannot find data: block in JS file');
data_block = raw(data_match-1 : find_close_curly(raw, data_match-1));
fprintf('  data block: %d chars\n', numel(data_block));

for ei = 1:nEpochs
    for si = 1:S.nSystems
        fprintf('  Parsing %s / %s ...', epoch_keys{ei}, sys_keys{si});

        % ── Locate epoch block within data block ──────────────────────
        ep_pat   = [epoch_keys{ei} '\s*:\s*\{'];
        ep_match = regexp(data_block, ep_pat, 'end', 'once');
        if isempty(ep_match)
            fprintf(' epoch key not found\n'); continue;
        end
        ep_open  = ep_match - 1;
        ep_close = find_close_curly(data_block, ep_open);
        ep_block = data_block(ep_open : ep_close);

        % ── Locate system block within epoch block ────────────────────
        sys_pat   = [sys_keys{si} '\s*:\s*\{'];
        sys_match = regexp(ep_block, sys_pat, 'end', 'once');
        if isempty(sys_match)
            fprintf(' sys key not found\n'); continue;
        end
        sys_open  = sys_match - 1;
        sys_close = find_close_curly(ep_block, sys_open);
        sys_block = ep_block(sys_open : sys_close);

        % ── Extract expl from system block ────────────────────────────
        expl_pos = regexp(sys_block, 'expl\s*:\s*\[', 'end', 'once');
        if isempty(expl_pos)
            fprintf(' expl not found\n'); continue;
        end
        expl_close = find_close_bracket(sys_block, expl_pos);
        expl_str   = sys_block(expl_pos + 1 : expl_close - 1);
        S.all_expl{ei,si} = str2double(strsplit(strtrim(expl_str), ','))';

        % ── Extract traj from system block ────────────────────────────
        traj_pos = regexp(sys_block, 'traj\s*:\s*\[', 'end', 'once');
        if isempty(traj_pos)
            fprintf(' traj not found\n'); continue;
        end
        traj_close = find_close_bracket(sys_block, traj_pos);
        traj_str   = sys_block(traj_pos + 1 : traj_close - 1);

        % Parse nested array [ntrials][nPC][ntbins]
        traj_3d = parse_traj(traj_str, S.ntrials, S.nPC);

        % permute [ntrials x nPC x ntbins] → [nPC x ntbins x ntrials]
        S.all_traj{ei,si} = permute(traj_3d, [2 3 1]);

        % Trim zero-padding to this system's true PC count (e.g. ballState → 2)
        nReal = numel(S.all_expl{ei,si});
        if nReal >= 1
            S.all_traj{ei,si} = ...
                S.all_traj{ei,si}(1:min(nReal, size(S.all_traj{ei,si},1)), :, :);
        end

        fprintf(' expl=%.1f%%  traj=[%s]\n', S.all_expl{ei,si}(1), ...
            num2str(size(S.all_traj{ei,si})));
    end
end

fprintf('Done.\n');
end


%% ── Helper: find matching close curly brace ──────────────────────────
function pos = find_close_curly(raw, open_pos)
% open_pos points to the '{' character
% returns position of matching '}'
    depth = 0;
    for i = open_pos : numel(raw)
        if raw(i) == '{', depth = depth + 1;
        elseif raw(i) == '}'
            depth = depth - 1;
            if depth == 0, pos = i; return; end
        end
    end
    error('Unmatched curly brace starting at position %d', open_pos);
end


%% ── Helper: find matching close bracket ─────────────────────────────
function pos = find_close_bracket(raw, open_pos)
% open_pos points to the '[' character
% returns position of matching ']'
    depth = 0;
    for i = open_pos : numel(raw)
        if raw(i) == '[', depth = depth + 1;
        elseif raw(i) == ']'
            depth = depth - 1;
            if depth == 0, pos = i; return; end
        end
    end
    error('Unmatched bracket starting at position %d', open_pos);
end


%% ── Helper: extract scalar number ───────────────────────────────────
function val = extract_scalar(raw, key)
    pattern = [key ':\s*(-?[\d.eE+\-]+)'];
    tok = regexp(raw, pattern, 'tokens', 'once');
    assert(~isempty(tok), 'Key not found: %s', key);
    val = str2double(tok{1});
end


%% ── Helper: extract 1D numeric array ────────────────────────────────
function arr = extract_num_array(raw, key)
    pattern = [key ':\s*\['];
    pos = regexp(raw, pattern, 'end', 'once');
    assert(~isempty(pos), 'Array key not found: %s', key);
    close_pos = find_close_bracket(raw, pos);
    arr_str = raw(pos + 1 : close_pos - 1);
    arr = str2double(strsplit(strtrim(arr_str), ','))';
    arr = arr(:)';   % ensure row vector
end


%% ── Helper: extract string array ────────────────────────────────────
function arr = extract_str_array(raw, key)
    pattern = [key ':\s*\['];
    pos = regexp(raw, pattern, 'end', 'once');
    assert(~isempty(pos), 'String array key not found: %s', key);
    close_pos = find_close_bracket(raw, pos);
    arr_str = raw(pos + 1 : close_pos - 1);
    toks = regexp(arr_str, '"([^"]*)"', 'tokens');
    arr = cellfun(@(t) t{1}, toks, 'UniformOutput', false);
end


%% ── Helper: parse traj nested array ─────────────────────────────────
function traj = parse_traj(str, ntrials, nPC)
% str is the contents of the outer [...] — ntrials inner [...] blocks
% Each trial block: [pc1_arr, pc2_arr, ...] where each pc_arr: [v1,v2,...]
% Returns [ntrials x nPC x ntbins]

    % Find each trial block (top-level [...])
    traj_cell = cell(ntrials, 1);
    depth = 0;
    block_start = [];
    trial_idx = 0;

    for i = 1 : numel(str)
        ch = str(i);
        if ch == '['
            depth = depth + 1;
            if depth == 1, block_start = i + 1; end
        elseif ch == ']'
            depth = depth - 1;
            if depth == 0 && ~isempty(block_start)
                trial_idx = trial_idx + 1;
                if trial_idx <= ntrials
                    traj_cell{trial_idx} = str(block_start : i - 1);
                end
                block_start = [];
            end
        end
    end

    % Parse first trial to get ntbins
    pc_arrs = split_top_level(traj_cell{1});
    ntbins  = numel(str2double(strsplit(strtrim(pc_arrs{1}), ',')));
    traj    = zeros(ntrials, nPC, ntbins);

    for c = 1 : trial_idx
        pc_arrs = split_top_level(traj_cell{c});
        for p = 1 : min(numel(pc_arrs), nPC)
            vals = str2double(strsplit(strtrim(pc_arrs{p}), ','));
            traj(c, p, 1:numel(vals)) = vals;
        end
    end
end


%% ── Helper: split top-level bracket blocks ───────────────────────────
function blocks = split_top_level(str)
% Split '[...],[...],...' into separate block strings (without outer brackets)
    blocks = {};
    depth = 0;
    block_start = [];
    for i = 1 : numel(str)
        ch = str(i);
        if ch == '['
            depth = depth + 1;
            if depth == 1, block_start = i + 1; end
        elseif ch == ']'
            depth = depth - 1;
            if depth == 0 && ~isempty(block_start)
                blocks{end+1} = str(block_start : i - 1); %#ok<AGROW>
                block_start = [];
            end
        end
    end
end
