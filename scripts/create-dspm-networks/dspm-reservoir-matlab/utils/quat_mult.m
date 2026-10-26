function q_out = quat_mult(q1, q2)
% QUAT_MULT  Quaternion multiplication (Hamilton product)
%
% Computes q_out = q1 * q2
%
% The Hamilton product satisfies:
%   i² = j² = k² = ijk = -1
%   ij = k, jk = i, ki = j
%   ji = -k, kj = -i, ik = -j
%
% Inputs:
%   q1, q2 - (4 × 1) quaternions [q0; q1; q2; q3]
%            Can also be (4 × T) for batch multiplication
%
% Output:
%   q_out  - (4 × 1) or (4 × T) quaternion product
%
% Properties:
%   - ||q1 * q2|| = ||q1|| * ||q2||
%   - (q1 * q2)^* = q2^* * q1^* (conjugation reverses order)
%   - Rotation composition: R(q1*q2) = R(q1) * R(q2)

    % Handle batch multiplication
    if size(q1, 2) > 1 || size(q2, 2) > 1
        T = max(size(q1, 2), size(q2, 2));
        if size(q1, 2) == 1
            q1 = repmat(q1, 1, T);
        end
        if size(q2, 2) == 1
            q2 = repmat(q2, 1, T);
        end
        q_out = zeros(4, T);
        for t = 1:T
            q_out(:, t) = quat_mult(q1(:, t), q2(:, t));
        end
        return;
    end
    
    a0 = q1(1); a = q1(2:4);
    b0 = q2(1); b = q2(2:4);
    
    q_out = [a0*b0 - dot(a, b);
             a0*b + b0*a + cross(a, b)];
end
