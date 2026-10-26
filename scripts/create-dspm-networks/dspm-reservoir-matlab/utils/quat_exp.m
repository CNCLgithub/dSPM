function q_out = quat_exp(omega, dt)
% QUAT_EXP  Exponential map from angular velocity to quaternion
%
% Computes the quaternion representing rotation by angle |ω|*dt about
% axis ω/|ω|. This is the exponential map from su(2) to SU(2).
%
% q = exp((dt/2) * ω̂) = cos(θ/2) + sin(θ/2) * n̂
%
% where θ = |ω| * dt and n̂ = ω/|ω|
%
% Inputs:
%   omega - (3 × 1) or (3 × T) angular velocity vector(s) (rad/s)
%   dt    - Time step (default: 1)
%
% Output:
%   q_out - (4 × 1) or (4 × T) quaternion(s) [q0; q1; q2; q3] where q0 is scalar
%
% Convention: q = q0 + q1*i + q2*j + q3*k
%
% This is structure-preserving: the result is EXACTLY on S³ regardless of
% the input magnitude.

    if nargin < 2, dt = 1; end
    
    % Handle multiple columns
    if size(omega, 2) > 1
        T = size(omega, 2);
        q_out = zeros(4, T);
        for t = 1:T
            q_out(:, t) = quat_exp(omega(:, t), dt);
        end
        return;
    end
    
    theta = norm(omega) * dt;  % Total rotation angle
    
    if theta < 1e-10
        % Small angle approximation (still normalized)
        q_out = [1; omega * dt / 2];
        q_out = q_out / norm(q_out);
    else
        half_theta = theta / 2;
        axis = omega / norm(omega);
        
        q_out = [cos(half_theta); sin(half_theta) * axis];
    end
end
