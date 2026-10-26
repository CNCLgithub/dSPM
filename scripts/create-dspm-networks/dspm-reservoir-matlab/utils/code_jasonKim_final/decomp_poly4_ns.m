function [Pd1,C1,C2,C3a,C3b,C4a,C4b,C4c] = decomp_poly4_ns(A,B,rs,dv,gam,o)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to decompose reservoir parameters into polynomial basis
% 
% Inputs:
% A:        N x N matrix of the connectivity between N neurons
% B:        N x k matrix from the k independent inputs
% rs:       N x 1 vector for the equilibrium point of the RNN
% dv:       N x 1 vector of the effective bias, A*rs + B*xs + d
% gam:      1 x 1 scalar for the time constant of the RNN
% o:        1 x 1 scalar for the order of the Taylor series in x
% 
% Outputs:
% Pd1:      p x k matrix of p polynomial basis terms as powers of k inputs
% C1:       N x p matrix of coefficients of the first series expansion
% C2:       N x p x k matrix of coefficients of the second series expansion
% Subsequent outputs correspond to the coefficients of higher expansion
% terms for the Taylor Series expansion in time.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Base parameters
N = size(A,1);                      % Number of neurons
k = size(B,2);                      % Number of inputs


%% Grid indices
v = reshape(eye(k),[1,k,k]);
Pd1 = eye(k);

for i = 2:o-1
    Pdp = Pd1+v;
    Pdp = permute(Pdp,[2,1,3]);
    Pdp = reshape(Pdp,[k,size(Pdp,2)*size(Pdp,3)])';
    Pd1 = unique([Pd1; Pdp], 'rows','stable');
end

Pd1 = [zeros(1,k); Pd1];
[~,sI1] = sort(max(Pd1,[],2));
[~,sI1a] = sort(sum(Pd1(sI1,:),2));
sI1 = sI1(sI1a);
Pd1 = Pd1(sI1,:);


%% Coefficients
% Initial coefficients
Ars  = A*rs;

% Compute higher order B terms
Bk = cell(o,1);
Bc = cell(o,1);
for i = 1:o-1
    PdI = find(sum(Pd1,2)==i);
    Bk{i} = zeros(N,length(PdI));
    Bc{i} = zeros(1,length(PdI));
    for j = 1:length(PdI)
        Bk{i}(:,j) = prod(B.^Pd1(PdI(j),:),2);
        Bc{i}(1,j) = factorial(i)/prod(factorial(Pd1(PdI(j),:)));
    end
end

% Compute coefficients
tic

% Tanh derivatives
D  = tanh_deriv(dv,o+4);
DD = D(:,2:end).*Ars - D(:,1:end-1);

% Prefactors
As   = (1-tanh(dv).^2).*A - eye(N);% (-1)
AsI  = inv(As);                    % (-1)
AsI2 = AsI*AsI;                    % (+1)
AsI3 = AsI2*AsI;                   % (-1)
AsI4 = AsI3*AsI;                   % (+1)

% Sole higher derivative terms
CM = reshape(DD(:,1:4),[N,1,4]);
for j = 2:o
    CM = cat(2,CM,reshape(DD(:,(0:3)+j),[N,1,4]).*(Bc{j-1}.*Bk{j-1})/factorial(j-1));
end

% ------------- SEE EOF NOTE-----------------------

% xdot terms
C1  =  As\CM(:,:,1);
C2  =  pagemtimes(AsI2,CM(:,:,2).*reshape(Bc{1}.*Bk{1},[N,1,size(Bk{1},2)])/gam);
C3b = -pagemtimes(AsI,C2)/(gam*2);  % NEGATED AND ADDED THE (1/2!)
C4c = -pagemtimes(AsI,C3b)/(gam*3); % NEGATED AND ADDED THE (1/3!), his  
                                    % recurrsion implements the 
                                    % (1/2)*(1/3) = (1/3!)  

% xdot^2 terms (NEGATED C3a and ADDED THE PROPER FACTORIAL DIVISORS TO BOTH)
C3a = -pagemtimes(AsI3,CM(:,:,3).*reshape(Bc{2}.*Bk{2},[N,1,size(Bk{2},2)])/(gam^2 * 2));
C4b =  pagemtimes(AsI4,CM(:,:,3).*reshape(Bk{2},[N,1,size(Bk{2},2)])/(gam^3 * 2));

% xdot^3 terms (ADDED THE PROPER FACTORIAL DIVISOR)
C4a =  pagemtimes(AsI4,CM(:,:,4).*reshape(Bc{3}.*Bk{3},[N,1,size(Bk{3},2)])/(gam^3 * 6));

% -----------------------------------------------

% % disp('Complete');
% % toc

end

% EOF NOTE:
%{ 

This was Jason's original tensor computation pipeline to implement the
higher order *time* derivatives from the Jet expansion of the tanh(Bx+d)
integrand that allowed for a closed form solution approximation of r(t) as
a function of symbolix inputs and *the time derivatives of those inputs as
dynamic error correction terms*, yielding r(t) ≈ h(x,ẋ,ẍ,...)

However I couldn't for the life of me make the decompilation with higher
time derivatives match Jason's script when I implemented the 
(Jet+Polynomial) expansions that yield the decompiled dynamic weights of a
given reservoir! Finally, after massive amounts of debugging, the error was
coming from a need to implement the (1/n!) coefficient for the Jet
expansion AND the logic Jason used for parsing the AsI = inv(As), as it
propagated through to the interaction terms and higher order time
derivatives.

To see what changed from the original (below) look at my emphasized
comments in the actual code above.

Original codeblock:

% xdot terms
C1  = As\CM(:,:,1);
C2  = pagemtimes(AsI2,CM(:,:,2).*reshape(Bc{1}.*Bk{1},[N,1,size(Bk{1},2)])/(1*gam));
C3b = pagemtimes(AsI,C2)/(gam);  
C4c = pagemtimes(AsI,C3b)/(gam); 


% xdot^2 terms
C3a = pagemtimes(AsI3,CM(:,:,3).*reshape(Bc{2}.*Bk{2},[N,1,size(Bk{2},2)])/(gam^2));
C4b = pagemtimes(3*AsI4,CM(:,:,3).*reshape(Bk{2},[N,1,size(Bk{2},2)])/(gam^3));

% xdot^3 terms
C4a = pagemtimes(AsI4,CM(:,:,4).*reshape(Bc{3}.*Bk{3},[N,1,size(Bk{3},2)])/(gam^3));


%}