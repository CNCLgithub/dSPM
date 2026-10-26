function prnns = create_and_program_pong_rnns(nnetworks, nneurons, connectivity, o)
% CREATE_AND_PROGRAM_PONG_RNNS  Batch of programmed pong reservoirs.
%
%   prnns = create_and_program_pong_rnns(nnetworks, nneurons, connectivity, ...)
%
% Same output shape as before: prnns(i).prnn is a ReservoirTanhB_dc that
% run_rnn_trials consumes unchanged. Each element also carries
%   .dspm   the dspm_reservoir it came from (omit with keep_dspm=false)
%   .gen    compile stats / timings / dynamics info
%
% NAME-VALUE ARGUMENTS
%   save                 Save prnns to ../../data/untrained-prnns/. Default false.
%   parallel             parfor over networks (forced on above 20). Default false.
%   paddle_exist         false builds a board with no paddle: the paddle
%                        position is folded into the dynamics as a constant
%                        at no_paddle_position, so the paddle detector is
%                        strongly stable at zero wherever the ball is and the
%                        paddle input has no effect. Default true.
%   no_paddle_position   Where the absent paddle sits along its wall, used
%                        only when paddle_exist is false. NaN means
%                        2*paddle_var_limits. Default NaN.
%   keep_dspm            Keep the dspm_reservoir in .dspm. Default true.
%   decompilation_order  Taylor order (degree + 1). Pong is cubic. Default 4.
%   B_scale              Read-in weights ~ U(-B_scale, B_scale). Default 0.05.
%   random_seed          Per-network seed random_seed + i; 0 = unseeded. Default 0.
%   verbose              Default false.

arguments
    nnetworks    (1,1) double {mustBeInteger, mustBeNonnegative}
    nneurons     (1,1) double {mustBeInteger, mustBePositive}
    connectivity (1,1) string {mustBeMember(connectivity, ["programmed","random"])}
    o.save                (1,1) logical = false
    o.parallel            (1,1) logical = false
    o.paddle_exist        (1,1) logical = true
    o.no_paddle_position  (1,1) double  = NaN
    o.keep_dspm           (1,1) logical = true
    o.decompilation_order (1,1) double {mustBeInteger, mustBePositive} = 4
    o.B_scale             (1,1) double {mustBePositive} = 0.05
    o.random_seed         (1,1) double {mustBeInteger, mustBeNonnegative} = 0
    o.verbose             (1,1) logical = false
end

runParams.n                   = nneurons;
runParams.dt                  = 0.01;
runParams.connectivity        = connectivity;
runParams.decompilation_order = o.decompilation_order;
runParams.B_scale             = o.B_scale;
runParams.verbose             = o.verbose;

board_params = getGameBoardParamerters("paddle_exist", o.paddle_exist);
if ~o.paddle_exist
    p_off = o.no_paddle_position;
    if isnan(p_off), p_off = 2 * board_params.paddle_var_limits; end
    board_params.no_paddle_position = p_off;
end

if nnetworks == 0
    prnns.prnn = [];
    prnns.board_params = board_params;
    return
end

% Symbolic tiers once, on the client; workers only run the eval tier.
symcache = pong_symbolic_cache(runParams);

prnns(1:nnetworks, 1) = struct("prnn", [], "board_params", board_params, ...
                               "dspm", [], "gen", []);

if o.parallel || nnetworks > 20
    parfor i = 1:nnetworks
        prnns(i) = build_one(runParams, board_params, symcache, o, i);
    end
else
    for i = 1:nnetworks
        prnns(i) = build_one(runParams, board_params, symcache, o, i);
    end
end

if o.save
    runid      = string(java.util.UUID.randomUUID.toString);
    today      = string(datetime("today"));
    saveString = strcat("../../data/untrained-prnns/", today, "_rnn_id_", runid, ".mat");
    save(saveString, "prnns", '-v7.3')
end

end

function s = build_one(runParams, board_params, symcache, o, i)
rp = runParams;
if o.random_seed > 0, rp.random_seed = o.random_seed + i; end

[basernn, res, gen] = program_rnn(rp, board_params, symcache);

s.prnn         = basernn;
s.board_params = board_params;
s.dspm         = [];
if o.keep_dspm, s.dspm = res; end
s.gen          = gen;
end
