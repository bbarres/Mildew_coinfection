library(CNPCluster)
library(Mildew)

if (!exists("basePath") | !exists("runParallel"))
  stop("Please set basePath and runParallel parameters.")


basePath<-"C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection"
runParallel<-FALSE

coin<-CoinfectionMildew$new(basePath=basePath, runParallel=runParallel)$loadData()
coin.mesh.params <- list(min.angle=20, max.edge=c(3400,10000), cutoff=1000, coords.scale=1e6)
coin.connectivity.scale <- 2000
coin.fixed.effects <- "Area_real + PA_20111 + connec2012 + number_MLG + Distance_to_shore + road_PA1 + cumulative_sum"
coin.fixed.effects <- "PA_20111 + connec2012 + number_MLG + RA_F2012"
coin.fixed.effects <- "PA_20111 + connec2012 + number_MLG + AA_F2012"
coin.fixed.effects <- "PA_20111 + connec2012"
coin.fixed.effects <- "PA_20111 + number_MLG"
coin.fixed.effects <- "connec2012 + number_MLG"
coin.fixed.effects <- "connec2012"
coin.fixed.effects <- "PA_20111"
coin.fixed.effects <- "Area_real"
coin.fixed.effects <- "number_MLG"
coin.fixed.effects <- "Distance_to_shore"
coin.fixed.effects <- "cumulative_sum"
coin.fixed.effects <- "road_PA1"
coin.fixed.effects <- "AA_F2012"

estimateOrdinaryLogisticModel <- function(mildew, connectivity.scale, fixed.effects, tag="", type="glm") {
  #mildew$addLandscapeConnectivity(connectivity.scale=connectivity.scale)
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- mildew$data$number_coinf
  Ntrials <- mildew$data$number_genotyped
  
  x <- mildew$setupModel(type=type, fixed.effects=fixed.effects, scale.covariates=FALSE,
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
}

estimateOrdinaryLogisticModel(coin, connectivity.scale=coin.connectivity.scale, fixed.effects=coin.fixed.effects,
                              tag="benoit")
coin$summaryResult()


estimateInterceptOnlyRandomEffectModel <- function(mildew, connectivity.scale, mesh.params, tag="", type) {
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- mildew$data$number_coinf
  Ntrials <- mildew$data$number_genotyped
  
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","PA_2011","connec2012","number_MLG")]
  
  x <- mildew$setupModel(type=type,scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}

estimateInterceptOnlyRandomEffectModel(coin, connectivity.scale=coin.connectivity.scale,
                                       mesh.params=coin.mesh.params, type="spatialonly",tag="intercepbenoit")
coin$summaryResult()


estimateRandomEffectModel <- function(mildew, connectivity.scale, fixed.effects, mesh.params, tag="", type) {

  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- mildew$data$number_coinf
  Ntrials <- mildew$data$number_genotyped
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","PA_2011","connec2012","number_MLG","RA_F2012","AA_F2012")]
  
  x <- mildew$setupModel(type=type, fixed.effects=fixed.effects, scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}

estimateRandomEffectModel(coin, connectivity.scale=coin.connectivity.scale, fixed.effects=coin.fixed.effects,
                          mesh.params=coin.mesh.params, type="spatialonly",tag="benoit")
coin$summaryResult()



getPosteriorRange = function(mildew, title) {
  library(INLA)
  spde.result <- inla.spde2.result(mildew$result, "s", mildew$spde)
  range.t <- inla.tmarginal(function(x) x * mildew$coords.scale / 1000, spde.result$marginals.range.nominal$range.nominal.1)
  return(cbind(Response=title, as.data.frame(unclass(range.t))))
}

coinrangepost<-getPosteriorRange(coin,"coinfection")
plot(coinrangepost$x,coinrangepost$y)





#Analyse of the link between coinfection and evolution of the prevalence of the disease in patches between 
#spring and autumn

varpreval<-VarprevalMildew$new(basePath=basePath, runParallel=runParallel)$loadData()
varpreval$data$index <- 1:nrow(varpreval$data)
varpreval.mesh.params <- list(min.angle=20, max.edge=c(3000,10000), cutoff=1000, coords.scale=1e6)
varpreval.connectivity.scale <- 2000
varpreval.fixed.effects<-"connec2012+perccoinf+f(index,model='iid')"
varpreval.fixed.effects<-"perccoinf"


estimateOrdinaryLogisticModel <- function(mildew, connectivity.scale, fixed.effects, tag="", type="glm") {
  #mildew$addLandscapeConnectivity(connectivity.scale=connectivity.scale)
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data <- mildew$data[mildew$data$AA_S2012!=0,]
  mildew$data <- cbind(mildew$data,"perccoinf"=mildew$data$number_coinf*100/mildew$data$number_genotyped)
  mildew$data$Year <- 2000
  Ntrials<-2
  mildew$data$y <- mildew$data$AA_F2012-mildew$data$AA_S2012
  
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","connec2012","number_MLG",
                                "perccoinf")]
  x <- mildew$setupModel(type=type, fixed.effects=fixed.effects, scale.covariates=FALSE,
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$estimate(tag=tag, saveToFile=TRUE, family="gaussian", Ntrials=Ntrials)
}

estimateOrdinaryLogisticModel(varpreval, connectivity.scale=varpreval.connectivity.scale, fixed.effects=varpreval.fixed.effects,
                              tag="benoit")
varpreval$summaryResult()


estimateRandomEffectModel <- function(mildew, connectivity.scale, fixed.effects, mesh.params, tag="", type) {
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data <- mildew$data[mildew$data$AA_S2012!=0,]
  mildew$data <- cbind(mildew$data,"perccoinf"=mildew$data$number_coinf*100/mildew$data$number_genotyped)
  mildew$data$Year <- 2000
  Ntrials<-2
  mildew$data$y <- mildew$data$AA_F2012-mildew$data$AA_S2012
  
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","connec2012","number_MLG",
                                "perccoinf")]
  
  x <- mildew$setupModel(type=type, fixed.effects=fixed.effects, scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE,family="gaussian", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}


estimateRandomEffectModel(varpreval, connectivity.scale=varpreval.connectivity.scale, fixed.effects=varpreval.fixed.effects,
                          mesh.params=varpreval.mesh.params, type="spatialonly",tag="benoit")
varpreval$summaryResult()


www.r-inla.org
latent models
iid model

spde tutorial

#the linear model  "model.ratioperc" is coming from the coinf_glm.R code
model.ratioperc<-lm((AA_F2012-AA_S2012)~percoinf,data=evolinf4)
#let's compare the fitted value to the original value
fitted(model.ratioperc)
index <- inla.stack.index(varpreval$data.stack, "pred")$data
temp<-data.frame(obs=varpreval$data$y, pred.inla=varpreval$result$summary.fitted.values$mean[index], pred.lm=fitted(model.ratioperc))
plot(temp[,1],type="b")
lines(temp$random)
lines(temp$fixed*coef(model.ratioperc)[2],col="red")

model.ratioperc


temp$random <- as.vector(varpreval$A %*% varpreval$result$summary.random$s$mean)
temp$fixed <- evolinf4$percoinf


#cor(temp$fixed*coef(model.ratioperc)[2],temp$random)
cor(temp$obs, temp$pred.inla)
cor(temp$obs, temp$pred.lm)
cor(temp$obs, temp$random)



mean((temp[,1]-temp[,2])^2)
mean((temp[,1]-temp[,3])^2)





estimateInterceptOnlyRandomEffectModel <- function(mildew, connectivity.scale, mesh.params, tag="", type) {
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data <- mildew$data[mildew$data$AA_S2012!=0,]
  mildew$data <- cbind(mildew$data,"perccoinf"=mildew$data$number_coinf*100/mildew$data$number_genotyped)
  mildew$data$Year <- 2000
  Ntrials<-2
  mildew$data$y <- mildew$data$AA_F2012-mildew$data$AA_S2012
  
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","connec2012","number_MLG",
                                "perccoinf")]
  
  x <- mildew$setupModel(type=type, scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE,family="gaussian", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}

estimateInterceptOnlyRandomEffectModel(varpreval, connectivity.scale=varpreval.connectivity.scale,
                                       mesh.params=varpreval.mesh.params, type="spatialonly",tag="benoit")
varpreval$summaryResult()








#analysis of the effect of coinfection on the P/A of powdery mildew the next year
basePath<-"C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection"
runParallel<-FALSE

survi<-Survival2013Mildew$new(basePath=basePath, runParallel=runParallel)$loadData()
survi.mesh.params <- list(min.angle=20, max.edge=c(3000,10000), cutoff=1000, coords.scale=1e6)
survi.connectivity.scale <- 2000
survi.fixed.effects<-"connec2012+PA_20111+number_coinf+Area_real"
survi.fixed.effects<-"number_coinf+PA_20111"

estimateOrdinaryLogisticModel <- function(mildew, connectivity.scale, fixed.effects, tag="", type="glm") {
  #mildew$addLandscapeConnectivity(connectivity.scale=connectivity.scale)
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- as.numeric(as.character(mildew$data$PA_2013))
  Ntrials <-rep(1,dim(mildew$data)[1])
  
  x <- mildew$setupModel(type=type, fixed.effects=fixed.effects, scale.covariates=FALSE,
                         exclude.covariates=c("number_genotyped","Year","Longitude","Latitude","y"))
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
}

estimateOrdinaryLogisticModel(survi, connectivity.scale=survi.connectivity.scale, fixed.effects=survi.fixed.effects,
                              tag="benoit")
survi$summaryResult()


estimateInterceptOnlyRandomEffectModel <- function(mildew, connectivity.scale, mesh.params, tag="", type) {
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- as.numeric(as.character(mildew$data$PA_2013))
  Ntrials <-rep(1,dim(mildew$data)[1])
  
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","PA_2011","connec2012","number_MLG")]
  
  x <- mildew$setupModel(type=type,scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}

estimateInterceptOnlyRandomEffectModel(survi, connectivity.scale=survi.connectivity.scale,
                                       mesh.params=survi.mesh.params, type="spatialonly",tag="intercepbenoit")
survi$summaryResult()


estimateRandomEffectModel <- function(mildew, connectivity.scale, fixed.effects, mesh.params, tag="", type) {
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- as.numeric(as.character(mildew$data$PA_2013))
  Ntrials <-rep(1,dim(mildew$data)[1])
  
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","PA_2011","connec2012","number_MLG",
                                "number_coinf")]
  
  x <- mildew$setupModel(type=type, fixed.effects=fixed.effects, scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}

estimateRandomEffectModel(survi, connectivity.scale=survi.connectivity.scale, fixed.effects=survi.fixed.effects,
                          mesh.params=survi.mesh.params, type="spatialonly",tag="benoit")
survi$summaryResult()


getPosteriorRange = function(mildew, title) {
  library(INLA)
  spde.result <- inla.spde2.result(mildew$result, "s", mildew$spde)
  range.t <- inla.tmarginal(function(x) x * mildew$coords.scale / 1000, spde.result$marginals.range.nominal$range.nominal.1)
  return(cbind(Response=title, as.data.frame(unclass(range.t))))
}

survirangepost<-getPosteriorRange(survi,"coinfection")
plot(survirangepost$x,survirangepost$y)
