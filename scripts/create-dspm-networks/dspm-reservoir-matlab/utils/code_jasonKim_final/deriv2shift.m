function [XC] = deriv2shift(C,DX,Pd1,PdS)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function that shifts the coefficients of a Taylor Series expansion term
% by the amount specified in DX. This shift represents a multiplication of
% the Series expansion term by a particular time derivative DX of a
% dynamical system.
%
% Inputs:
% C:        N x p x q matrix of coefficients of the Taylor Series expansion 
% DX:       q x p matrix of weights determined by the time derivative DX
% Pd1:      p x k matrix of p polynomial basis terms as powers of k inputs
% PdS:      p x p matrix of shifts that are products of polynomials in Pd1
% 
% Outputs
% XC:       N x p x q matrix of shifted coefficients
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Prefactors
XC = zeros(size(C));
for i = 1:size(Pd1,1)
    pd  = PdS(i,:);
    pdi = find(pd);
    pd  = pd(pdi);
    XC(:,pd,:) = XC(:,pd,:) + C(:,pdi,:).*reshape(DX(:,i),[1,1,size(DX,1)]);
end

end