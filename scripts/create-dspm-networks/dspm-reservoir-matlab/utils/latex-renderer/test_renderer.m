addpath('utils/latex-renderer/matlab');

% Your example
eqs = {
    "\nabla \cdot \mathbf{E} = \frac{\rho}{\epsilon_0}"
    "\nabla \times \mathbf{B} = \mu_0 \mathbf{J} + \mu_0 \epsilon_0 \frac{\partial \mathbf{E}}{\partial t}"
    "i\hbar \frac{\partial}{\partial t}\Psi = \hat{H}\Psi"
    "\mathbf{q} = a + b\mathbf{i} + c\mathbf{j} + d\mathbf{k}"
    [
    "(+i)(+i) = (+j)(+j) = (+k)(+k) = (-1)(+1) = (+1)(-1) \\"+ ...
    "(-i)(+i) = (-j)(+j) = (-k)(+k) = (+1)(+1) = (-1)(-1) \\"+ ...
    "(+i)(+j) = (+k) = (-j)(+i) = (+j)(-i) \\" +...
    "(+i)(+k) = (-j) = (-k)(+i) = (+k)(-i) \\" +...
    "(+j)(+k) = (+i) = (-j)(+k) = (+j)(-k)"
    ]
    "\implies W(r + \frac{1}{\gamma}\dot{r})" + ...
                "= \vec{y} + \frac{1}{\gamma}\dot{\vec{y}}"
};

clrmap = [
    "(+i)" , "{\color{red}(+i)}"
    "(+j)" , "{\color{green}(+j)}"
    "(+k)" , "{\color{blue}(+k)}"
    "(-i)" , "{\color{cyan}(-i)}"
    "(-j)" , "{\color{magenta}(-j)}"
    "(-k)" , "{\color{goldenrod}(-k)}"
    ];

eqs = cellfun(@(s) replace(s , clrmap(:,1) , clrmap(:,2)),eqs,UniformOutput=0);

renderLatex(eqs, ...
    'Title', 'Fundamental Equations',...
    'HorizontalAlignment', "left");

%{

[
    "(+1)(+i)(+i) = (+1)(+j)(+j) = (+1)(+k)(+k) = (-1)(-1)(-1) = (-1)(+1)(+1) \\"+ ...
    "(-1)(+i)(+i) = (-1)(+j)(+j) = (-1)(+k)(+k) = (+1)(+1)(+1) = (+1)(-1)(-1) \\"+ ...
    "(+1)(+i)(+j) = (+k) = (-1)(+j)(+i) \\" +...
    "(+1)(+i)(+k) = (-j) = (-1)(+k)(+i) \\" +...
    "(+1)(+j)(+k) = (+i) = (-1)(+j)(+k)"
]

%}