simMsOcc <- function(J.x, J.y, n.rep, N, beta, alpha, psi.RE = list(), 
		     p.RE = list(), sp = FALSE, cov.model, 
		     sigma.sq, phi, nu, factor.model = FALSE, n.factors, ...) {

  # Check for unused arguments ------------------------------------------
  formal.args <- names(formals(sys.function(sys.parent())))
  elip.args <- names(list(...))
  for(i in elip.args){
      if(! i %in% formal.args)
          warning("'",i, "' is not an argument")
  }
  # Check function inputs -------------------------------------------------
  # J.x -------------------------------
  if (missing(J.x)) {
    stop("error: J.x must be specified")
  }
  if (length(J.x) != 1) {
    stop("error: J.x must be a single numeric value.")
  }
  # J.y -------------------------------
  if (missing(J.y)) {
    stop("error: J.y must be specified")
  }
  if (length(J.y) != 1) {
    stop("error: J.y must be a single numeric value.")
  }
  J <- J.x * J.y
  # n.rep -----------------------------
  if (missing(n.rep)) {
    stop("error: n.rep must be specified.")
  }
  if (length(n.rep) != J) {
    stop(paste("error: n.rep must be a vector of length ", J, sep = ''))
  }
  # N ---------------------------------
  if (missing(N)) {
    stop("error: N must be specified")
  }
  if (length(N) != 1) {
    stop("error: N must be a single numeric value.")
  }
  # beta ------------------------------
  if (missing(beta)) {
    stop("error: beta must be specified")
  }
  if (!is.matrix(beta)) {
    stop(paste("error: beta must be a numeric matrix with ", N, " rows", sep = ''))
  }
  if (nrow(beta) != N) {
    stop(paste("error: beta must be a numeric matrix with ", N, " rows", sep = ''))
  }
  # alpha -----------------------------
  if (missing(alpha)) {
    stop("error: alpha must be specified.")
  }
  if (!is.matrix(alpha)) {
    stop(paste("error: alpha must be a numeric matrix with ", N, " rows", sep = ''))
  }
  if (nrow(alpha) != N) {
    stop(paste("error: alpha must be a numeric matrix with ", N, " rows", sep = ''))
  }
  if (sp & !factor.model) {
    # sigma.sq --------------------------
    if (missing(sigma.sq)) {
      stop("error: sigma.sq must be specified when sp = TRUE")
    }
    if (length(sigma.sq) != N) {
      stop(paste("error: sigma.sq must be a vector of length ", N, sep = ''))
    }
    # phi -------------------------------
    if(missing(phi)) {
      stop("error: phi must be specified when sp = TRUE")
    }
    if (length(phi) != N) {
      stop(paste("error: phi must be a vector of length ", N, sep = ''))
    }
  }
  if (sp) {
    # Covariance model ----------------
    if(missing(cov.model)) {
      stop("error: cov.model must be specified when sp = TRUE")
    }
    cov.model.names <- c("exponential", "spherical", "matern", "gaussian")
    if(! cov.model %in% cov.model.names){
      stop("error: specified cov.model '",cov.model,"' is not a valid option; choose from ", 
           paste(cov.model.names, collapse=", ", sep="") ,".")
    }
    if (cov.model == 'matern' & missing(nu)) {
      stop("error: nu must be specified when cov.model = 'matern'")
    }
  }
  if (factor.model) {
    # n.factors -----------------------
    if (missing(n.factors)) {
      stop("error: n.factors must be specified when factor.model = TRUE")
    }
    if (sp) {
      if (!missing(sigma.sq)) {
        message("sigma.sq is specified but will be set to 1 for spatial latent factor model")
      }
      if(missing(phi)) {
        stop("error: phi must be specified when sp = TRUE")
      }
      if (length(phi) != n.factors) {
        stop(paste("error: phi must be a vector of length ", n.factors, sep = ''))
      }
    }
  }
  # psi.RE ----------------------------
  names(psi.RE) <- tolower(names(psi.RE))
  if (!is.list(psi.RE)) {
    stop("error: if specified, psi.RE must be a list with tags 'levels' and 'sigma.sq.psi'")
  }
  if (length(names(psi.RE)) > 0) {
    if (!'sigma.sq.psi' %in% names(psi.RE)) {
      stop("error: sigma.sq.psi must be a tag in psi.RE with values for the occurrence random effect variances")
    }
    if (!'levels' %in% names(psi.RE)) {
      stop("error: levels must be a tag in psi.RE with the number of random effect levels for each occurrence random intercept.")
    }
  }
  # p.RE ----------------------------
  names(p.RE) <- tolower(names(p.RE))
  if (!is.list(p.RE)) {
    stop("error: if specified, p.RE must be a list with tags 'levels' and 'sigma.sq.p'")
  }
  if (length(names(p.RE)) > 0) {
    if (!'sigma.sq.p' %in% names(p.RE)) {
      stop("error: sigma.sq.p must be a tag in p.RE with values for the detection random effect variances")
    }
    if (!'levels' %in% names(p.RE)) {
      stop("error: levels must be a tag in p.RE with the number of random effect levels for each detection random intercept.")
    }
  }

  # Subroutines -----------------------------------------------------------
  # MVN 
  rmvn <- function(n, mu=0, V = matrix(1)) {
    p <- length(mu)
    if(any(is.na(match(dim(V),p))))
      stop("Dimension problem!")
    D <- chol(V)
    t(matrix(rnorm(n*p), ncol=p)%*%D + rep(mu,rep(n,p)))
  }

  logit <- function(theta, a = 0, b = 1){log((theta-a)/(b-theta))}
  logit.inv <- function(z, a = 0, b = 1){b-(b-a)/(1+exp(z))}
  
  # Form occupancy covariates (if any) ------------------------------------
  J <- J.x * J.y
  p.occ <- ncol(beta)
  X <- matrix(1, nrow = J, ncol = p.occ) 
  if (p.occ > 1) {
    for (i in 2:p.occ) {
      X[, i] <- rnorm(J)
    } # i
  }

  # Form detection covariate (if any) -------------------------------------
  p.det <- ncol(alpha)
  X.p <- array(NA, dim = c(J, max(n.rep), p.det))
  X.p[, , 1] <- 1
  if (p.det > 1) {
    for (i in 2:p.det) {
      for (j in 1:J) {
        X.p[j, 1:n.rep[j], i] <- rnorm(n.rep[j])
      } # j
    } # i
  }

  # Simulate latent (spatial) random effect for each species --------------
  # Matrix of spatial locations
  s.x <- seq(0, 1, length.out = J.x)
  s.y <- seq(0, 1, length.out = J.y)
  coords <- as.matrix(expand.grid(s.x, s.y))
  w.star <- matrix(0, nrow = N, ncol = J)
  if (factor.model) {
    lambda <- matrix(rnorm(N * n.factors, 0, 1), N, n.factors) 
    # Set diagonals to 1
    diag(lambda) <- 1
    # Set upper tri to 0
    lambda[upper.tri(lambda)] <- 0
    w <- matrix(NA, n.factors, J)
    if (sp) { # sfMsPGOcc
      if (cov.model == 'matern') {
        theta <- cbind(phi, nu)
      } else {
        theta <- as.matrix(phi)
      }
      for (ll in 1:n.factors) {
        Sigma <- mkSpCov(coords, as.matrix(1), as.matrix(0), 
            	     theta[ll, ], cov.model)
        w[ll, ] <- rmvn(1, rep(0, J), Sigma)
      }

    } else { # lsMsPGOcc
      for (ll in 1:n.factors) {
        w[ll, ] <- rnorm(J)
      } # ll  
    }
    for (j in 1:J) {
      w.star[, j] <- lambda %*% w[, j]
    }
  } else {
    if (sp) { # spMsPGOcc
      lambda <- NA
      if (cov.model == 'matern') {
        theta <- cbind(phi, nu)
      } else {
        theta <- as.matrix(phi)
      }
      # Spatial random effects for each species
      for (i in 1:N) {
        Sigma <- mkSpCov(coords, as.matrix(sigma.sq[i]), as.matrix(0), 
            	     theta[i, ], cov.model)
        w.star[i, ] <- rmvn(1, rep(0, J), Sigma)
      }
    }
    # For naming consistency
    w <- w.star
    lambda <- NA
  }

  # Random effects --------------------------------------------------------
  if (length(psi.RE) > 0) {
    p.occ.re <- length(psi.RE$levels)
    sigma.sq.psi <- rep(NA, p.occ.re)
    n.occ.re.long <- psi.RE$levels
    n.occ.re <- sum(n.occ.re.long)
    beta.star.indx <- rep(1:p.occ.re, n.occ.re.long)
    beta.star <- matrix(0, N, n.occ.re)
    X.re <- matrix(NA, J, p.occ.re)
    for (l in 1:p.occ.re) {
      X.re[, l] <- sample(1:psi.RE$levels[l], J, replace = TRUE)         
      for (i in 1:N) {
        beta.star[i, which(beta.star.indx == l)] <- rnorm(psi.RE$levels[l], 0, 
							  sqrt(psi.RE$sigma.sq.psi[l]))
      }
    }
    if (p.occ.re > 1) {
      for (j in 2:p.occ.re) {
        X.re[, j] <- X.re[, j] + max(X.re[, j - 1], na.rm = TRUE)
      }
    } 
    beta.star.sites <- matrix(NA, N, J)
    for (i in 1:N) {
      beta.star.sites[i, ] <- apply(X.re, 1, function(a) sum(beta.star[i, a]))
    }
  } else {
    X.re <- NA
    beta.star <- NA
  }
  if (length(p.RE) > 0) {
    p.det.re <- length(p.RE$levels)
    sigma.sq.p <- rep(NA, p.det.re)
    n.det.re.long <- p.RE$levels
    n.det.re <- sum(n.det.re.long)
    alpha.star.indx <- rep(1:p.det.re, n.det.re.long)
    alpha.star <- matrix(0, N, n.det.re)
    X.p.re <- array(NA, dim = c(J, max(n.rep), p.det.re))
    for (l in 1:p.det.re) {
      X.p.re[, , l] <- matrix(sample(1:p.RE$levels[l], J * max(n.rep), replace = TRUE), 
		              J, max(n.rep))	      
      for (i in 1:N) {
        alpha.star[i, which(alpha.star.indx == l)] <- rnorm(p.RE$levels[l], 0, sqrt(p.RE$sigma.sq.p[l]))
      }
    }
    for (j in 1:J) {
      X.p.re[j, -(1:n.rep[j]), ] <- NA
    }
    if (p.det.re > 1) {
      for (j in 2:p.det.re) {
        X.p.re[, , j] <- X.p.re[, , j] + max(X.p.re[, , j - 1], na.rm = TRUE) 
      }
    }
    alpha.star.sites <- array(NA, c(N, J, max(n.rep)))
    for (i in 1:N) {
      alpha.star.sites[i, , ] <- apply(X.p.re, c(1, 2), function(a) sum(alpha.star[i, a]))
    }
  } else {
    X.p.re <- NA
    alpha.star <- NA
  }

  # Latent Occupancy Process ----------------------------------------------
  psi <- matrix(NA, nrow = N, ncol = J)
  z <- matrix(NA, nrow = N, ncol = J)
  for (i in 1:N) {
    if (sp | factor.model) {
      if (length(psi.RE) > 0) {
        psi[i, ] <- logit.inv(X %*% as.matrix(beta[i, ]) + w.star[i, ] + beta.star.sites[i, ])
      } else {
        psi[i, ] <- logit.inv(X %*% as.matrix(beta[i, ]) + w.star[i, ])
      }
    } else {
      if (length(psi.RE) > 0) {
        psi[i, ] <- logit.inv(X %*% as.matrix(beta[i, ]) + beta.star.sites[i, ])
      } else {
        psi[i, ] <- logit.inv(X %*% as.matrix(beta[i, ]))
      }
    }
    z[i, ] <- rbinom(J, 1, psi[i, ])
  }

  # Data Formation --------------------------------------------------------
  p <- array(NA, dim = c(N, J, max(n.rep)))
  y <- array(NA, dim = c(N, J, max(n.rep)))
  for (i in 1:N) {
    for (j in 1:J) {
      if (length(p.RE) > 0) {
        p[i, j, 1:n.rep[j]] <- logit.inv(X.p[j, 1:n.rep[j], ] %*% as.matrix(alpha[i, ]) + alpha.star.sites[i, j, 1:n.rep[j]])
      } else {
        p[i, j, 1:n.rep[j]] <- logit.inv(X.p[j, 1:n.rep[j], ] %*% as.matrix(alpha[i, ]))
      }
 
        y[i, j, 1:n.rep[j]] <- rbinom(n.rep[j], 1, p[i, j, 1:n.rep[j]] * z[i, j]) 
    } # j
  } # i
  return(
    list(X = X, X.p = X.p, coords = coords,
	 w = w, psi = psi, z = z, p = p, y = y, X.p.re = X.p.re, 
	 X.re = X.re, alpha.star = alpha.star, beta.star = beta.star, 
	 lambda = lambda)
  )
}
