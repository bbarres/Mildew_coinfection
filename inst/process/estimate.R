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
coin.fixed.effects <- "PA_20111 + connec2012 + number_MLG"
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


estimateInterceptOnlyRandomEffectModel <- function(mildew, connectivity.scale, mesh.params, tag="", type) {
  
  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- mildew$data$number_coinf
  Ntrials <- mildew$data$number_genotyped
  
  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","PA_2011","connec2012","number_MLG",
                                "cumulative_sum","road_PA","Distance_to_shore")]
  
  x <- mildew$setupModel(type=type,scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}

estimateInterceptOnlyRandomEffectModel(coin, connectivity.scale=coin.connectivity.scale,
                                       mesh.params=coin.mesh.params, type="spatialonly",tag="intercepbenoit")


estimateRandomEffectModel <- function(mildew, connectivity.scale, fixed.effects, mesh.params, tag="", type) {

  missingIndex <- complete.cases(mildew$data)
  mildew$data <- mildew$data[missingIndex,]
  mildew$data$Year <- 2000
  mildew$data$y <- mildew$data$number_coinf
  Ntrials <- mildew$data$number_genotyped

  mildew$data <- mildew$data[,c("Year", "Longitude","Latitude","y","Area_real","PA_2011","connec2012","number_MLG",
                                "cumulative_sum","road_PA","Distance_to_shore")]
  
  x <- mildew$setupModel(type=type, fixed.effects=fixed.effects, scale.covariates=FALSE, mesh.params=mesh.params, 
                         exclude.covariates=c("number_coinf","number_genotyped","Year","Longitude","Latitude","y"))
  mildew$plotMesh()
  
  mildew$estimate(tag=tag, saveToFile=TRUE, family="binomial", Ntrials=Ntrials)
  mildew$summaryHyperparameters()
}


estimateRandomEffectModel(coin, connectivity.scale=coin.connectivity.scale, fixed.effects=coin.fixed.effects,
                          mesh.params=coin.mesh.params, type="spatialonly",tag="benoit")
coin$summaryResult()


