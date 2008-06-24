function [Gamma_y,ivar]=th_autocovariances(dr,ivar,M_,options_)
% Computes the theoretical auto-covariances, Gamma_y, for an AR(p) process 
% with coefficients dr.ghx and dr.ghu and shock variances Sigma_e_
% for a subset of variables ivar (indices in lgy_)
%  
% INPUTS
%   dr:         structure of decisions rules for stochastic simulations
%   ivar:       subset of variables
%   M_
%   options_
%    
% OUTPUTS
%   Gamma_y:    theoritical auto-covariances
%   ivar:       subset of variables
%
% SPECIAL REQUIREMENTS
%   Theoretical HP filtering is available as an option
%  
% part of DYNARE, copyright Dynare Team (2001-2008)
% Gnu Public License.

  exo_names_orig_ord  = M_.exo_names_orig_ord;
  if exist('OCTAVE_VERSION')
    warning('off', 'Octave:divide-by-zero')
  elseif sscanf(version('-release'),'%d') < 13
    warning off
  else
    eval('warning off MATLAB:dividebyzero')
  end
  nar = options_.ar;
  Gamma_y = cell(nar+1,1);
  if isempty(ivar)
    ivar = [1:M_.endo_nbr]';
  end
  nvar = size(ivar,1);
  
  ghx = dr.ghx;
  ghu = dr.ghu;
  npred = dr.npred;
  nstatic = dr.nstatic;
  kstate = dr.kstate;
  order = dr.order_var;
  iv(order) = [1:length(order)];
  nx = size(ghx,2);
  
  ikx = [nstatic+1:nstatic+npred];
  
  k0 = kstate(find(kstate(:,2) <= M_.maximum_lag+1),:);
  i0 = find(k0(:,2) == M_.maximum_lag+1);
  i00 = i0;
  n0 = length(i0);
  AS = ghx(:,i0);
  ghu1 = zeros(nx,M_.exo_nbr);
  ghu1(i0,:) = ghu(ikx,:);
  for i=M_.maximum_lag:-1:2
    i1 = find(k0(:,2) == i);
    n1 = size(i1,1);
    j1 = zeros(n1,1);
    for k1 = 1:n1
      j1(k1) = find(k0(i00,1)==k0(i1(k1),1));
    end
    AS(:,j1) = AS(:,j1)+ghx(:,i1);
    i0 = i1;
  end
  b = ghu1*M_.Sigma_e*ghu1';


  ipred = nstatic+(1:npred)';
  % state space representation for state variables only
  [A,B] = kalman_transition_matrix(dr,ipred,1:nx,dr.transition_auxiliary_variables,M_.exo_nbr);
  if options_.order == 2 | options_.hp_filter == 0
    [vx, u] =  lyapunov_symm(A,B*M_.Sigma_e*B',options_.qz_criterium);
    iky = iv(ivar);
    if ~isempty(u)
      iky = iky(find(all(abs(ghx(iky,:)*u) < options_.Schur_vec_tol,2)));
      ivar = dr.order_var(iky);
    end
    aa = ghx(iky,:);
    bb = ghu(iky,:);
    if options_.order == 2         % mean correction for 2nd order
      Ex = (dr.ghs2(ikx)+dr.ghxx(ikx,:)*vx(:)+dr.ghuu(ikx,:)*M_.Sigma_e(:))/2;
      Ex = (eye(n0)-AS(ikx,:))\Ex;
      Gamma_y{nar+3} = AS(iky,:)*Ex+(dr.ghs2(iky)+dr.ghxx(iky,:)*vx(:)+...
				     dr.ghuu(iky,:)*M_.Sigma_e(:))/2;
    end
  end
  if options_.hp_filter == 0
    Gamma_y{1} = aa*vx*aa'+ bb*M_.Sigma_e*bb';
    k = find(abs(Gamma_y{1}) < 1e-12);
    Gamma_y{1}(k) = 0;
    
    % autocorrelations
    if nar > 0
      vxy = (A*vx*aa'+ghu1*M_.Sigma_e*bb');

      sy = sqrt(diag(Gamma_y{1}));
      sy = sy *sy';
      Gamma_y{2} = aa*vxy./sy;
      
      for i=2:nar
	vxy = A*vxy;
	Gamma_y{i+1} = aa*vxy./sy;
      end
    end
    
    % variance decomposition
    if M_.exo_nbr > 1
      Gamma_y{nar+2} = zeros(length(ivar),M_.exo_nbr);
      SS(exo_names_orig_ord,exo_names_orig_ord)=M_.Sigma_e+1e-14*eye(M_.exo_nbr);
      cs = chol(SS)';
      b1(:,exo_names_orig_ord) = ghu1;
      b1 = b1*cs;
      b2(:,exo_names_orig_ord) = ghu(iky,:);
      b2 = b2*cs;
      vx  = lyapunov_symm(A,b1*b1',options_.qz_criterium);
      vv = diag(aa*vx*aa'+b2*b2');
      for i=1:M_.exo_nbr
	vx1 = lyapunov_symm(A,b1(:,i)*b1(:,i)',options_.qz_criterium);
	Gamma_y{nar+2}(:,i) = abs(diag(aa*vx1*aa'+b2(:,i)*b2(:,i)'))./vv;
      end
    end
  else
    if options_.order < 2
      iky = iv(ivar);  
      aa = ghx(iky,:);
      bb = ghu(iky,:);
    end
    lambda = options_.hp_filter;
    ngrid = options_.hp_ngrid;
    freqs = 0 : ((2*pi)/ngrid) : (2*pi*(1 - .5/ngrid)); 
    tpos  = exp( sqrt(-1)*freqs);
    tneg  =  exp(-sqrt(-1)*freqs);
    hp1 = 4*lambda*(1 - cos(freqs)).^2 ./ (1 + 4*lambda*(1 - cos(freqs)).^2);
    
    mathp_col = [];
    IA = eye(size(A,1));
    IE = eye(M_.exo_nbr);
    for ig = 1:ngrid
      f_omega  =(1/(2*pi))*( [inv(IA-A*tneg(ig))*ghu1;IE]...
			     *M_.Sigma_e*[ghu1'*inv(IA-A'*tpos(ig)) ...
		    IE]); % state variables
      g_omega = [aa*tneg(ig) bb]*f_omega*[aa'*tpos(ig); bb']; % selected variables
      f_hp = hp1(ig)^2*g_omega; % spectral density of selected filtered series
      mathp_col = [mathp_col ; (f_hp(:))'];    % store as matrix row
                                               % for ifft
    end;

    % covariance of filtered series
    imathp_col = real(ifft(mathp_col))*(2*pi);

    Gamma_y{1} = reshape(imathp_col(1,:),nvar,nvar);
    
    % autocorrelations
    if nar > 0
      sy = sqrt(diag(Gamma_y{1}));
      sy = sy *sy';
      for i=1:nar
	Gamma_y{i+1} = reshape(imathp_col(i+1,:),nvar,nvar)./sy;
      end
    end
    
    %variance decomposition
    if M_.exo_nbr > 1
      Gamma_y{nar+2} = zeros(nvar,M_.exo_nbr);
      SS(exo_names_orig_ord,exo_names_orig_ord) = M_.Sigma_e+1e-14*eye(M_.exo_nbr);
      cs = chol(SS)';
      SS = cs*cs';
      b1(:,exo_names_orig_ord) = ghu1;
      b2(:,exo_names_orig_ord) = ghu(iky,:);
      mathp_col = [];
      IA = eye(size(A,1));
      IE = eye(M_.exo_nbr);
      for ig = 1:ngrid
	f_omega  =(1/(2*pi))*( [inv(IA-A*tneg(ig))*b1;IE]...
			       *SS*[b1'*inv(IA-A'*tpos(ig)) ...
		    IE]); % state variables
	g_omega = [aa*tneg(ig) b2]*f_omega*[aa'*tpos(ig); b2']; % selected variables
	f_hp = hp1(ig)^2*g_omega; % spectral density of selected filtered series
	mathp_col = [mathp_col ; (f_hp(:))'];    % store as matrix row
						 % for ifft
      end;

      imathp_col = real(ifft(mathp_col))*(2*pi);
      vv = diag(reshape(imathp_col(1,:),nvar,nvar));
      for i=1:M_.exo_nbr
	mathp_col = [];
	SSi = cs(:,i)*cs(:,i)';
	for ig = 1:ngrid
	  f_omega  =(1/(2*pi))*( [inv(IA-A*tneg(ig))*b1;IE]...
				 *SSi*[b1'*inv(IA-A'*tpos(ig)) ...
		    IE]); % state variables
	  g_omega = [aa*tneg(ig) b2]*f_omega*[aa'*tpos(ig); b2']; % selected variables
	  f_hp = hp1(ig)^2*g_omega; % spectral density of selected filtered series
	  mathp_col = [mathp_col ; (f_hp(:))'];    % store as matrix row
						   % for ifft
	end;

	imathp_col = real(ifft(mathp_col))*(2*pi);
	Gamma_y{nar+2}(:,i) = abs(diag(reshape(imathp_col(1,:),nvar,nvar)))./vv;
      end
    end
  end
  if exist('OCTAVE_VERSION')
    warning('on', 'Octave:divide-by-zero')
  elseif sscanf(version('-release'),'%d') < 13
    warning_config
  else
    eval('warning on MATLAB:dividebyzero')
  end
  