# R codes used in 
# Cubaynes, S. C. Lavergne, O. Gimenez (2014). Fitting animal survival models with temporal random effects. 
# Environmental and Ecological Statistics 21:599–610
# to fit band-recovery models with temporal random effects

# can be downloaded freely from
# https://oliviergimenez.github.io/pubs/Cubaynesetal2014EES.pdf

#----------------------------------------------#
# fit band-recovery model with random effect   #
# on the survival probabilities                #
#----------------------------------------------#

schall <- function(y,X,U,Relache,betainit,ksiinit,ssiginit,maxiter,precision){
library(MASS)

# input
# y = observed recoveries ; cohort in rows
# Relache = nb of released individuals, duplicated in each cohort
# X = incidence matrix for fixed effects
# U = incidence matrix for random effects
# betainit = inits
# ksiinit=matrix(0.1,nrow=nc-1,ncol=1)
# ssiginit=10
# maxiter=100
# precision=10^(-5)

# misc 
nfix = length(betainit) 
q = length(ksiinit) 
n = length(y)
ntot = nfix + q

beta = betainit
ksi = ksiinit
theta = c(beta,ksi)
ssig = ssiginit

V = U %*% t(U)
XU = cbind(X,U)

# constant initializing
i = 0
ind1 = 0
ind2 = 0

#-----
# run Schall algorithm
#-----

while (!((ind1&ind2) | (i>=maxiter))) 
{
  # update parameters
	prssig = ssig 
	prbeta = beta 
	prtheta = theta 

  # form z, W and D
	eta = XU %*% theta # X * beta + U * ksi
	mu = Relache * exp(eta) # mu = E(Y) = g-1(eta)
	invW=diag(as.vector(Relache * exp(eta)))
	
	d = (matrix(ssig,nrow=q,ncol=1))
	D = diag(as.vector(d))
	invD = diag(1/as.vector(d)) 

	z = eta + (y-mu) / mu # working vector z
       
  # form MME equations via block multiplication of matrices 
	MME = t(XU) %*% invW %*% XU # first [X U]' * W-1 * [X U]
	MME[(nfix+1):ntot , (nfix+1):ntot] = MME[(nfix+1):ntot , (nfix+1):ntot] + invD 
	# then add D^{-1} to the bottom right block in MME
	
	RHS = t(XU) %*% invW %*% z 

  # solve system of equations
	#theta = solve(MME) %*% RHS
	theta = ginv(MME) %*% RHS
  
  # get fixed and random effects
	beta = theta[1:nfix] # fixed
	ksi = theta[(nfix+1):ntot]  
	#invMME = solve(MME) 
	invMME = ginv(MME) 
	T = invMME[(nfix+1):ntot,(nfix+1):ntot] 
	tt = sum(diag(T))
	ssig = (t(ksi) %*% ksi) / (q - (tt/prssig)) # standard deviation using REML

	#T = MME[(nfix+1):ntot,(nfix+1):ntot]
 	#invT = solve(T)
	#tt = sum(diag(invT))
	#ssig = (t(ksi) %*% ksi) / (q - (tt/prssig)) # standard deviation using ML; to be used in AIC calculation


  # check convergence and apply stopping rules 
	ind1 = (abs(beta - prbeta)) < precision 
	ifelse(sum(ind1)==nfix,ind1<-1,ind1<-0) 
	ind2 = (abs((ssig - prssig)) / prssig) < precision

  # increment loop index
	i = i+1 

}
          
#-----
# compute AIC
#-----

#d = matrix(ssig,nrow=q,ncol=1)
#D = diag(as.vector(d))
#theta[1:nfix] = beta 
#theta[(nfix+1):ntot] = ksi 
#eta = XU %*% theta
#W = solve(diag(as.vector(Relache * exp(eta))))
#z = eta + (y-mu) / mu
#AIC = n * log(2*pi) + determinant(W + U %*% D %*% t(U),logarithm=T)$modulus + t(z - X %*% beta) %*% solve(W + U %*% D %*% t(U)) %*% (z - X %*% beta) + 2 * (nfix+1)

#-----
# display results
#-----

res <- matrix(c(beta[2],exp(beta[2]),beta[1],exp(beta[1]),ssig),ncol=1)
# 'recov prob on log scale','recov prob','mean survival on log scale','mean survival','var of random effect','AIC'
return(res)

}


#--------------------------------------------------------#
#                                                        #
#                     EXAMPLE 1                          #
#                                                        #
# fit band-recovery model with random effect             #
# to Youngs and Robson (1975) Brook trout recovery data  #
#--------------------------------------------------------#

#---------------------------------------------------------------
# read in data
#---------------------------------------------------------------

# observed recoveries ; cohort in rows
y <- c(72,  44,   8,   9,   4,   4,   1,   1,   1,   0,
74,  30,  20,   7,   4,   2,   1,   0,   0,
54,  48,  13,  23,   5,   4,   2,   0,
74,  24,  16,   7,   3,   1,   1,
48,  40,   5,   5,   2,   5,
31,  10,   6,   3,   2,
38,  30,   6,   2,
19,   6,   6,
13,  14,
17)

# nb of recovery years
nc = 10

# nb of released individuals, duplicated in each cohort
Relache <- c(rep(1048,10),
rep(844,9),
rep(989,8),
rep(971,7),
rep(863,6),
rep(465,5), 
rep(845,4),
rep(360,3),
rep(625,2),
rep(760,1))

#---------------------------------------------------------------
# specify model by building X and U matrices
#---------------------------------------------------------------

betaF = matrix(1,nrow=length(y),ncol=1)
betaS = NULL
a = 0:(nc-1)
b = a[length(a):1]
for (t in b){
    a = 0:t
    betaS = c(betaS,a)
}
X = cbind(betaS,betaF)
 
U = matrix(0,nrow=length(y),ncol=nc-1)
for (i in 1:(nc-1)){
U[1:nc,i]=rbind(matrix(0,nrow=i,ncol=1),matrix(1,nrow=nc-i,ncol=1))
}

fin=nc
for (i in 1:nc){
fin = c(fin,fin[i]+(nc-i))
}

for (j in 1:(nc-2)){
U[(fin[j]+1):(fin[j+1]),(j+1):(nc-1)] = U[(j+1):nc,(j+1):(nc-1)]
}

#---------------------------------------------------------------
# fit model
#---------------------------------------------------------------

# inits
betainit=c(-0.5,-0.5)
ksiinit=matrix(0.1,nrow=nc-1,ncol=1)
ssiginit=10

# numerical options
maxiter=100
precision=10^(-5)

# load schall function (to fit random-effect recovery model)
source('schall.R')

# fit model
schall(y,X,U,Relache,betainit,ksiinit,ssiginit,maxiter,precision)

#---------------------------------------------------------------






#----------------------------------------------#
#                                              #
#                EXAMPLE 2                     #
#                                              #
# fit band-recovery model with random effect   #
# to Franklin et al. (2002) California (male)  #
# mallard Recovery Data                        #
#----------------------------------------------#

#---------------------------------------------------------------
# read in data
#---------------------------------------------------------------

# observed recoveries ; cohort in rows
y <- c(103,60,39,20,10,6,1,3,3,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
88,51,27,9,9,5,3,2,1,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
58,15,12,8,4,4,2,3,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
43,13,13,7,1,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
58,52,22,9,10,5,2,2,3,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
19,5,1,5,5,4,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
26,16,16,15,2,7,4,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
20,13,10,4,3,5,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
32,12,6,7,4,3,0,4,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
46,21,17,17,10,3,1,6,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
58,21,18,17,11,1,2,3,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
29,19,12,8,5,2,1,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
58,33,16,13,14,8,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
35,20,12,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
38,21,22,10,4,4,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
41,24,10,3,5,3,3,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
60,21,11,4,8,4,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
50,24,17,9,2,3,2,1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
39,34,17,16,4,2,2,3,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
36,18,16,7,6,3,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
64,67,27,23,8,8,5,8,2,1,1,1,0,0,0,0,0,0,0,0,0,0,
76,36,30,14,8,14,5,1,0,0,1,1,0,0,0,0,0,0,0,0,0,
93,79,30,18,11,11,6,4,2,1,0,0,1,0,0,1,0,0,0,0,
197,122,51,26,35,27,8,14,4,1,0,0,1,0,1,0,0,0,0,
133,74,47,30,18,7,15,5,1,4,0,2,0,0,0,0,0,0,
113,78,37,20,21,9,9,4,6,2,1,0,0,1,0,0,0,
117,88,45,29,23,11,10,7,10,4,7,1,0,0,0,0,
72,41,19,24,8,8,5,4,5,6,1,0,1,0,0,
68,33,36,20,13,9,3,9,1,4,1,0,0,1,
74,54,24,23,14,11,6,4,5,4,0,3,1,
103,42,33,13,18,10,9,5,4,1,3,3,
75,63,39,24,17,16,15,5,7,4,3,
85,34,40,16,20,23,9,7,3,3,
60,50,32,28,16,9,12,11,8,
96,45,44,22,23,15,9,13,
82,74,54,39,26,22,17,
96,47,37,22,16,12,
62,50,31,26,15,
36,26,24,18,
145,99,70,
124,68,
85)

# nb of recovery years
nc= 42

# nb of released individuals, duplicated in each cohort
Relache <- c(rep(1353,42),
rep(783,41),
rep(528,40),
rep(500,39),
rep(994,38),
rep(268,37),
rep(507,36),
rep(278,35),
rep(365,34),
rep(565,33),
rep(602,32),
rep(394,31),
rep(598,30),
rep(358,29),
rep(454,28),
rep(414,27),
rep(507,26),
rep(461,25),
rep(465,24),
rep(467,23),
rep(862,22),
rep(1020,21),
rep(1228,20),
rep(2279,19),
rep(1720,18),
rep(1571,17),
rep(1769,16),
rep(1076,15),
rep(1100,14),
rep(1218,13),
rep(1350,12),
rep(1713,11),
rep(1313,10),
rep(1226,9),
rep(1348,8),
rep(2192,7),
rep(1269,6),
rep(1165,5),
rep(858,4),
rep(2222,3),
rep(1618,2),
rep(1037,1))

#---------------------------------------------------------------
# specify model by building X and U matrices
#---------------------------------------------------------------

betaF = matrix(1,nrow=length(y),ncol=1)
betaS = NULL
a = 0:(nc-1)
b = a[length(a):1]
for (t in b){
    a = 0:t
    betaS = c(betaS,a)
}
X = cbind(betaS,betaF)
 
U = matrix(0,nrow=length(y),ncol=nc-1)
for (i in 1:(nc-1)){
U[1:nc,i]=rbind(matrix(0,nrow=i,ncol=1),matrix(1,nrow=nc-i,ncol=1))
}

fin=nc
for (i in 1:nc){
fin = c(fin,fin[i]+(nc-i))
}

for (j in 1:(nc-2)){
U[(fin[j]+1):(fin[j+1]),(j+1):(nc-1)] = U[(j+1):nc,(j+1):(nc-1)]
}

#---------------------------------------------------------------
# fit model
#---------------------------------------------------------------

# initial values
betainit=c(-0.5,-0.5)
ksiinit=matrix(0.1,nrow=nc-1,ncol=1)
ssiginit=10

# numerical options
maxiter=100
precision=10^(-5)

# fit model
schall(y,X,U,Relache,betainit,ksiinit,ssiginit,maxiter,precision)

