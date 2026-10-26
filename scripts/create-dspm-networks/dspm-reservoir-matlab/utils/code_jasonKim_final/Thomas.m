classdef Thomas < handle
    % Defines a class for an N dimensional nonlinear reservoir
    properties
        x0              % Initial State: 3 x 1
        x               % Current State: 3 x 1
        delT
        parms
    end
    
    methods
        % Constructor
        function obj = Thomas(x0, delT)
            obj.x0 = x0;
            obj.x = x0;
            obj.delT = delT;
        end
        
        function dx = del_x(o,x)
            dx = [-3.7*x(1,:) + 5*sin(x(2,:)*4);...
                  -3.7*x(2,:) + 5*sin(x(3,:)*4);...
                  -3.7*x(3,:) + 5*sin(x(1,:)*4)];
        end
        
        function X = propagate(o,n)
            nInd = 0;                                   % Counter
            X = zeros([3,n,4]); 
            X(:,1,1) = o.x;
            fprintf([repmat('.', [1, 100]) '\n']);
            for i = 2:n
                if(i > nInd*n)
                    fprintf('=');                       % Display Progress
                    nInd = nInd + .01;
                end
                k1 = o.delT * o.del_x(o.x);
                k2 = o.delT * o.del_x(o.x + k1/2);
                k3 = o.delT * o.del_x(o.x + k2/2);
                k4 = o.delT * o.del_x(o.x + k3);
                X(:,i,1) = o.x + (k1 + 2*k2 + 2*k3 + k4)/6;
                X(:,i-1,2:4) = reshape([o.x+k1/2, o.x+k2/2, o.x+k3], [3 1 3]);
                o.x = X(:,i,1);
            end
            fprintf('\n');
        end
    end
end