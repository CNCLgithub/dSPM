function summary(obj)
    % SUMMARY  Print a compact summary of the reservoir state
    
    fprintf('\n=== Reservoir Summary ===\n');
    fprintf('Neurons:           N = %d\n', obj.n_neurons);
    fprintf('Recurrent inputs:  k_rec = %d\n', obj.n_recurrent_inputs);
    fprintf('External inputs:   k_ext = %d\n', obj.n_external_inputs);
    fprintf('Time constant:     γ = %.1f\n', obj.gamma);
    fprintf('Time step:         dt = %.4f\n', obj.dt);
    fprintf('\n');
    
    if ~isempty(obj.x_recurrent_star)
        fprintf('Operating point:   x⁎ = [%s]\n', num2str(obj.x_recurrent_star', '%.2f '));
    else
        fprintf('Operating point:   NOT SET\n');
    end
    
    if ~isempty(obj.decompiled_weight_matrix)
        fprintf('\nDecompilation:\n');
        fprintf('  jet_order  = %d\n', obj.jet_order);
        fprintf('  poly_order = %d\n', obj.decompilation_order);
        fprintf('  R matrix   = %d × %d\n', size(obj.decompiled_weight_matrix, 1), ...
            size(obj.decompiled_weight_matrix, 2));
        fprintf('  n_monomials     = %d\n', obj.n_monomials);
    else
        fprintf('\nDecompilation:     NOT DONE\n');
    end
    
    fprintf('\nStatus:\n');
    fprintf('   Initialized: %s\n', mat2str(obj.is_initialized));
    fprintf('   Compiled:    %s\n', mat2str(obj.is_compiled));
    fprintf('   Loop closed: %s\n', mat2str(obj.is_closed));
    fprintf('   Conditioned: %s\n', mat2str(obj.is_conditioned));
    fprintf('  Ready to run: %s\n', mat2str(obj.ready_to_run));
    fprintf('\n');
end
