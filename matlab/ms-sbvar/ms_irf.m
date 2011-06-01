function [options_, oo_]=ms_irf(varlist,M_, options_, oo_)
%function ms_irf()
% calls ms irf mex function
%
% INPUTS
%    varlist:     (chararray) list of selected endogenous variables
%    M_:          (struct)    model structure
%    options_:    (struct)    options
%    oo_:         (struct)    results
%
% OUTPUTS
%    options_:    (struct)    options
%    oo_:         (struct)    results
%
% SPECIAL REQUIREMENTS
%    none

% Copyright (C) 2011 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.

disp('IRFs');
options_ = set_ms_estimation_flags_for_other_mex(options_);
options_ = set_ms_simulation_flags_for_other_mex(options_);
oo_ = set_oo_w_estimation_output(options_, oo_);

opt = {options_.ms.output_file_tag, ...
    'seed', options_.DynareRandomStreams.seed, ...
    'horizon', options_.ms.horizon, ...
    'filtered', options_.ms.filtered_probabilities, ...
    'error_bands', options_.ms.error_bands, ...
    'percentiles', options_.ms.error_band_percentiles, ...
    'thin', options_.ms.thinning_factor };

[err, irf] = mex_ms_irf(opt{:}, 'free_parameters', oo_.ms.maxparams, 'shocks_per_parameter', options_.ms.shock_draws);
mexErrCheck('mex_ms_irf ergodic ', err);
plot_ms_irf(M_,options_,irf,options_.varobs,'Ergodic Impulse Responses',varlist);

[err, regime_irfs] = mex_ms_irf(opt{:}, 'free_parameters',oo_.ms.maxparams,'shocks_per_parameter', options_.ms.shock_draws,'regimes');
mexErrCheck('mex_ms_irf ergodic regimes ',err);
save([M_.fname '/' options_.ms.output_file_tag '_ergodic_irf.mat'], 'irf', 'regime_irfs');

if exist(options_.ms.load_mh_file,'file') > 0
    [err, irf] = mex_ms_irf(opt{:}, 'shocks_per_parameter', options_.ms.shocks_per_parameter, ...
        'parameter_uncertainty','simulation_file',options_.ms.load_mh_file);
    mexErrCheck('mex_ms_irf bayesian ',err);
    plot_ms_irf(M_,options_,irf,options_.varobs,'Impulse Responses w/ Parameter Uncertainty',varlist);
    
    [err, regime_irfs] = mex_ms_irf(opt{:}, 'shocks_per_parameter', options_.ms.shocks_per_parameter, ...
        'simulation_file',options_.ms.load_mh_file,'parameter_uncertainty','regimes');
    mexErrCheck('mex_ms_irf bayesian regimes ',err);
    save([M_.fname '/' options_.ms.output_file_tag '_bayesian_irf.mat'], 'irf', 'regime_irfs');
end
options_ = initialize_ms_sbvar_options(M_, options_);
end
