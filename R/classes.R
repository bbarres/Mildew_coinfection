library(INLA)
setOldClass("inla.mesh")
setOldClass("inla.spde2")
setOldClass("inla.data.stack")
setOldClass("inla")

OccupancyMildew <- setRefClass(
  "OccupancyMildew",
  fields = list(
    basePath = "character",
    runParallel = "logical",
    
    data = "data.frame",
    response = "character",
    type = "character",
    tag = "character",
    coords.scale = "numeric",
    #mesh = "inla.mesh",
    #spde = "inla.spde2",
    #index = "list",
    #A = "Matrix",
    #group.years = "integer",
    mesh = "ANY",
    spde = "ANY",
    index = "ANY",
    A = "ANY",
    group.years = "ANY",
    
    covariates = "ANY",
    model = "formula",
    #data.stack = "inla.data.stack",
    data.stack = "ANY",
    result = "inla"
  ),
  methods = list(
    initialize = function(runParallel=FALSE, response="occupancy", ...) {
      callSuper(response=response, runParallel=runParallel, ...)
      invisible(.self)
    },

    mergeRainfall = function(mildew, rainfallFile="W_uni.csv") {
      message("Loading rainfall data...")
      rainfall <- read.csv(file.path(basePath, rainfallFile))
      return(merge(mildew, rainfall, sort=FALSE, all.x=TRUE, all.y=FALSE, by=c("ID", "Year")))
    },  
    
    loadRawData = function(mildewFile=mildewFile) {
      message("Loading ", response, " data...")
      
      mildew <- read.csv(file.path(basePath, mildewFile))
      mildew <- transform(mildew, y=as.logical(PA), road_PA=as.logical(road_PA), Open_bin=as.logical(Open_bin), varjoisuus=as.ordered(varjoisuus),
                          fallPLM2=fallPLM2, Distance_to_shore=Distance_to_shore, fallPLdry=fallPLdry,
                          logfallPLM2=log(fallPLM2), logDistance_to_shore=log(Distance_to_shore), S=S)
      mildew <- mergeRainfall(mildew)
      mildew$fallPLdry[mildew$fallPLdry > 100] <- NA
      mildew$varjoisuus[mildew$varjoisuus == 0] <- NA
      mildew$varjoisuus <- mildew$varjoisuus[drop=T]
      
      data <<- mildew
      invisible(.self)
    },
    
    getMissingDataProportion = function(exclude.imputation.columns) {
      loadRawData()
      imputation.columns <- !(colnames(data) %in% exclude.imputation.columns)
      x <- complete.cases(data[,imputation.columns])
      message("Rows with missing data in covariates = ", round((1 - sum(x) / length(x)) * 100), "%")
    },
    
    # Imputation by k-nearest neighbors regression using Gower's distance that allows inclusion
    # of unordered and ordered categorical variables as well.
    # Distance columns are the columns used for dissimilarity calculation and imputation columns
    # are the columns to be imputed.
    impute = function(k=50, aggregation.function=median, distance.metric="gower", exclude.distance.columns=NULL, exclude.imputation.columns=NULL) {
      library(StatMatch)
      library(plyr)
      
      aggregation.function <- match.fun(aggregation.function)
      distance.columns <- !(colnames(data) %in% exclude.distance.columns)
      imputation.columns <- !(colnames(data) %in% exclude.imputation.columns)
      k.seq <- 2:(k+1)
      
      missing.data.proportion.before <- sum(!complete.cases(data[,imputation.columns])) / nrow(data)
      message(round(missing.data.proportion.before*100, 3), "% of rows have missing data.")      
      message("Imputing...")
      
      data <<- adply(data, 1, function(data.row, k.seq, data, distance.columns, imputation.columns) {
        data.imputed <- data.row[imputation.columns]
        if (all(complete.cases(data.imputed))) return(data.row)  
        data.distance <- data.row[distance.columns]
        
        row <- rownames(data.row)
        message("Processing data row ", row, " / ", nrow(data), "...")
        
        distance.values <- as.vector(gower.dist(data[, distance.columns], data.distance))
        names(distance.values) <- rownames(data)
        nearest.neighbor.rows <- names(distance.values[order(distance.values)][k.seq])
        
        missing.columns <- which(is.na(data.imputed))
        for (missing.column.index in 1:length(missing.columns)) {
          missing.column <- missing.columns[missing.column.index]  

          neighbor.values <- as.numeric(data[nearest.neighbor.rows, imputation.columns][,missing.column])
          imputed.value <- aggregation.function(neighbor.values, na.rm=TRUE)

          if (is.na(imputed.value)) {
            warning("Could not impute missing value on row = ", row, ", column = ", missing.column, ": all neighboring values are NA. Consider increasing k and/or iterating the imputation several times.")
          }
          else {
            #message("row = ", row, ", column = ", names(data.imputed)[missing.column], " (", missing.column, "), column.class = ", paste(class(data.imputed[,missing.column]), collapse=" "), ", imputed.value = ", imputed.value, " from values = ", paste(neighbor.values, collapse=" "), " from rows = ", paste(nearest.neighbor.rows, collapse=","))
            missing.column.class <- class(data.imputed[,missing.column])[1]
            data.row[imputation.columns][missing.column] <-
              switch(missing.column.class,
                ordered = as.ordered(levels(data.imputed[,missing.column])[round(imputed.value)]),
                factor = as.factor(levels(data.imputed[,missing.column])[round(imputed.value)]),
                logical = as.logical(round(imputed.value)),
                numeric = imputed.value,
                integer = as.integer(round(imputed.value)),
                stop("Unsupported data type = ", missing.column.class))
          }
        }
        return(data.row)
      }, k.seq=k.seq, data=data, distance.columns=distance.columns, imputation.columns=imputation.columns,
        .parallel=runParallel, .paropts=list(.packages="StatMatch"))

      missing.data.proportion.after <- sum(!complete.cases(data[,imputation.columns])) / nrow(data)
      message(round(missing.data.proportion.after*100, 3), "% of rows still have missing data.")
      
      invisible(.self)
    },
        
    getDataFileName = function() {
      return(file.path(basePath, paste("MildewData-", response, ".RData", sep="")))
    },
    
    saveData = function() {
      save(data, file=getDataFileName())
      invisible(.self)
    },
    
    loadData = function() {
      load(getDataFileName(), envir=as.environment(.self))
      data$varjoisuus <<- data$varjoisuus[drop=T] # quick fix
      invisible(.self)
    },
    
    connectivity = function(z1, z2, area, alpha, occurrence=1) {
      return(sum(exp(-alpha * Mod(z2 - z1)) * sqrt(area) * occurrence, na.rm=T))
    },
    
    addLandscapeConnectivity = function(connectivity.scale) {
      library(plyr)

      message("Computing landscape connectivity...")
      
      # Find mean patch coverage for each patch across all years
      x <- ddply(data, .(ID), function(x) {
          data.frame(Z=complex(real=x$Latitude, imaginary=x$Longitude)[1], A=mean(x$fallPLM2))
        }, .parallel=runParallel)
      
      # Landscape connectivity
      x$S <- NA
      for (i in 1:nrow(x)) {
        x$S[i] <- connectivity(x$Z[i], x$Z[-i], x$A[-i], 1 / connectivity.scale)
      }
      
      data$S <<- NULL
      y <- merge(data, x[,c("ID","S")], by="ID", sort=F)
      data <<- y
      
      invisible(.self)
    },
    
    getPersistence = function() {
      # Check whether mildew survived over the winter
            
      occupancy <- if (class(.self) == "OccupancyMildew") .self
      else {
        x <- OccupancyMildew$new(basePath=basePath, runParallel=runParallel)
        x$loadData()
        x
      }
      
      message("Computing persistence...")
      
      persistence <- c()
      years <- sort(unique(occupancy$data$Year))[-1]
      persistence <- ldply(years, function(year, occ.data) {        
        message("Processing year ", year, "...")
        
        x1 <- subset(occ.data, Year==year-1)
        x2 <- subset(occ.data, Year==year)
        x2$persistent <- NA
        for (i in 1:nrow(x2)) {
          j <- which(x1$ID == x2$ID[i])
          if (length(j)==1)
            x2$persistent[i] <- x1$PA[j]==1 & x2$PA[i]==1
        }
        return(x2)
      }, occ.data=occupancy$data, .parallel=runParallel)
      
      occupancy$data$persistent <- NULL
      occupancy$data <- merge(occupancy$data, persistence[,c("ID","Year","persistent")], by=c("ID","Year"), all.x=T, sort=F)
      return(occupancy$data)
    },

    addPopulationConnectivity = function(connectivity.scale) {
      library(plyr)
      
      persistence <- getPersistence()
      
      message("Computing population connectivity...")
      
      # Population connectivity and persistent population connectivity
      x <- ddply(persistence, .(Year), function(x, scale) {
        message("Processing year ", x$Year[1], "...")
        
        Z <- complex(real=x$Longitude, imaginary=x$Latitude)
        x$Smildew <- NA
        x$Smildew_pers <- NA
        for (i in 1:nrow(x)) {
          x$Smildew[i] <- connectivity(Z[i], Z[-i], x$fallPLM2[-i], 1 / scale, x$PA[-i])
          x$Smildew_pers[i] <- connectivity(Z[i], Z[-i], x$fallPLM2[-i], 1 / scale, x$persistent[-i])
        }
        return(x)
      }, scale=connectivity.scale, .parallel=runParallel)
      
      data$Smildew <<- NULL
      data$Smildew_pers <<- NULL
      y <- merge(data, x[,c("ID","Year","Smildew","Smildew_pers")], by=c("ID","Year"))      
      data <<- y
      
      invisible(.self)
    },
    
    reid = function(id) {
      newid <- integer(length(id))
      hash <- list()
      count <- 0
      for (i in 1:length(id)) {
        if (is.null(hash[[as.character(id[i])]])) {
          count <- count + 1
          hash[[as.character(id[i])]] <- count
          newid[i] <- count        
        }
        else {
          newid[i] <- hash[[as.character(id[i])]]
        }
      }
      return(newid)
    },
    
    scaleCovariates = function() {
      library(arm)
      
      message("Scaling covariates...")
      
      covariates$fallPLM2 <<- rescale(covariates$fallPLM2)
      covariates$road_PA <<- rescale(covariates$road_PA)
      covariates$Distance_to_shore <<- rescale(covariates$Distance_to_shore)
      covariates$Open_bin <<- rescale(covariates$Open_bin)    
      if (any(names(covariates) == "S")) covariates$S <<- rescale(covariates$S)
      if (any(names(covariates) == "Smildew")) covariates$Smildew <<- rescale(covariates$Smildew)
      if (any(names(covariates) == "Smildew_pers")) covariates$Smildew_pers <<- rescale(covariates$Smildew_pers)
      covariates$fallPLdy <<- rescale(covariates$fallPLdry)
      #covariates$varjoisuus <<- rescale(covariates$varjoisuus)
      covariates$Rainfall_August <<- rescale(covariates$Rainfall_August)
      covariates$Rainfall_July <<- rescale(covariates$Rainfall_July)
      covariates$logDistance_to_shore <<- rescale(covariates$logDistance_to_shore)
    },
    
    setupModel = function(type, scale.covariates=TRUE, fixed.effects, mesh.params, plot=FALSE, exclude.covariates) {
      library(INLA)
      
      type <<- type
      # Note: does not work with missing covariate data ATM, it is assumed the user to impute the missing values
      #data <<- data[complete.cases(data),]
      
      random.effects <- switch(type,
        glm=NULL,
        temporalreplicate2="f(s, model='iid', group=s.group, control.group=list(model='ar1'))",
        spatialreplicate2="f(s, model=spde, group=s.group, control.group=list(model='ar1', hyper=list(theta=list(initial=0, fixed=T))))",
        spatiotemporal="f(s, model=spde, group=s.group, control.group=list(model='ar1'))",
        spatialonly="f(s, model=spde)",
        temporalonly="f(data$ID, model='iid', group=s.group, control.group=list(model='ar1'))",
        spatialreplicate="f(s, model=spde, replicate=s.repl)",
        temporalreplicate="f(data$ID, model='ar1', replicate=group.years)")
            
      if (missing(fixed.effects)) {
        model <<- as.formula(paste(c("y ~ -1 + intercept", random.effects), collapse=" + "))
        covariates <<- NULL
      }
      else {
        model <<- as.formula(paste(c("y ~ -1 + intercept", paste(fixed.effects, collapse=" + "), random.effects), collapse=" + "))
        #data$intercept <- 1
        #covariates <<- as.data.frame(model.matrix(model, data=data[,!names(data) %in% c("y","PA","Col","Ext","persistent","logfallPLM2")], na.action=na.fail))
        #covariates <<- as.data.frame(model.matrix(~-1+., data=data[,!names(data) %in% c("y","PA","Col","Ext","persistent","logfallPLM2")], na.action=na.fail))
        covariates <<- as.data.frame(model.matrix(~-1+., data=data[,!names(data) %in% exclude.covariates], na.action=na.fail))

        if (nrow(covariates) != nrow(data))
          stop("Missing data (NAs) not allowed in covariates.")
        
        if (scale.covariates) scaleCovariates()
      }
      
      years <- data$Year
      n.years <- length(unique(years))
      group.years <<- as.integer(years - min(years) + 1)

      message("Model: ", model[2], " ", model[1], " ", model[3])
      
      if (type == "glm" | type == "temporalreplicate") return(.self)

      message("Constructing mesh...")
      
      coords.scale <<- mesh.params$coords.scale
      locations <- cbind(data$Longitude, data$Latitude) / coords.scale
      mesh <<- inla.mesh.create.helper(points.domain=locations, min.angle=mesh.params$min.angle, max.edge=mesh.params$max.edge / coords.scale, cutoff=mesh.params$cutoff / coords.scale)
      spde <<- inla.spde2.matern(mesh) 
      
      if (plot) {
        plot(mesh)
        points(locations, col="red", pch=16, cex=.1)
      }
      
      message("Number of mesh nodes = ", mesh$n) 
      
      if (type == "spatiotemporal") {
        index <<- inla.spde.make.index("s", n.spde=mesh$n, n.group=n.years)
        A <<- inla.spde.make.A(mesh, loc=locations, group=group.years, n.group=n.years)
      }
      else if (type == "spatialonly") {
        index <<- inla.spde.make.index("s", n.spde=mesh$n)
        A <<- inla.spde.make.A(mesh, loc=locations)
      }
      else if (type == "spatialreplicate") {
        index <<- inla.spde.make.index("s", n.spde=mesh$n, n.repl=n.years)
        data$reID <<- reid(data$ID)
        A <<- inla.spde.make.A(mesh, loc=locations, index=data$reID, repl=group.years)    
      }
      else if (type == "temporalonly") {
        index <<- inla.spde.make.index("s", n.spde=mesh$n, n.group=n.years)
        A <<- inla.spde.make.A(mesh, loc=locations, group=group.years, n.group=n.years)
      }
      else stop("Unknown model '", type, "'.")
      
      invisible(.self)
    },
    
    invlogit = function(x) exp(x)/(1+exp(x)),

    estimate = function(tag, saveToFile=F, family, Ntrials) {
      tag <<- tag
      
      message("Estimating model ", model[2], " ", model[1], " ", model[3], "...")
      
      if (type == "glm") {
        result <<- inla(model, family=family,
                      Ntrials=Ntrials,                      
                       data=cbind(covariates, intercept=1, y=as.numeric(data$y)),
                       verbose=TRUE,
                       control.predictor=list(compute=TRUE),
                       control.compute=list(cpo=FALSE, dic=TRUE))
        if (is.null(result$ok) || result$ok == FALSE) {
          stop("INLA failed to run.")
        }
        
        data$mu <<- invlogit(result$summary.linear.predictor$mean)
      }
      else if (type == "temporalreplicate") {
        result <<- inla(model, family=family,
                        Ntrials=Ntrials,
                       data=cbind(covariates, intercept=1, y=as.numeric(data$y)),
                       verbose=TRUE,
                       control.predictor=list(compute=TRUE),
                       control.compute=list(cpo=FALSE, dic=TRUE))
        if (is.null(result$ok) || result$ok == FALSE) {
          stop("INLA failed to run.")
        }
        
        data.full <- expand.grid(ID=unique(data$ID), Year=unique(data$Year))  
        data.full$random <- result$summary.random$"data$ID"$mean
        data <<- merge(data, data.full)
        
        data$mu <<- invlogit(result$summary.linear.predictor$mean)
      }
      else {
        data.stack <<- if (is.null(covariates)) {
          inla.stack(data=list(y=as.numeric(data$y)),
            A=list(A),
            effects=list(c(index, list(intercept=1))),
            tag="pred")
        }
        else {
          inla.stack(data=list(y=as.numeric(data$y)),
            A=list(A, 1),
            effects=list(c(index, list(intercept=1)), covariates),
            tag="pred")
        }
        
        result <<- inla(model, family=family, data=inla.stack.data(data.stack),
                        Ntrials=Ntrials,
                       verbose=TRUE,
                       control.predictor=list(A=inla.stack.A(data.stack), compute=TRUE),
                       control.compute=list(cpo=FALSE, dic=TRUE))
        if (is.null(result$ok) || result$ok == FALSE) {
          stop("INLA failed to run.")
        }
        
        if (type != "temporalonly") {
          data$random <<- as.vector(A %*% result$summary.random$s$mean)
        }
        
        index.pred <- inla.stack.index(data.stack, "pred")$data
        data$mu <<- invlogit(result$summary.linear.predictor$mean[index.pred])
      }

      # TODO
      #data$fixed <<- 
      data$residual <<- data$y - data$mu

      message("Finished estimating ", response, "-", type, "-", tag)
      
      if (saveToFile) {
        saveResult()
      }
    },
    
    getResultFileName = function(type, tag) {
      return(file.path(basePath, paste("MildewResult-", response, "-", type, "-", tag, ".RData", sep="")))
    },
    
    saveResult = function() {
      fileName <- getResultFileName(type, tag)
      message("Saving result to ", fileName, "...")
      save(result, data, data.stack, covariates, model, mesh, spde, index, coords.scale, A, file=fileName)
    },
    
    loadResult = function(type, tag) {
      type <<- type
      tag <<- tag
      fileName <- getResultFileName(type, tag)
      message("Loading result from ", fileName, "...")      
      load(fileName, envir=as.environment(.self))
      invisible(.self)
    },
    
    summaryResult = function() {
      library(INLA)
      print(summary(result))
      invisible(.self)
    },
    
    getINLAResult = function(marginal, fun=identity, coords.scale=1) {
      m <- inla.tmarginal(function(x) fun(x) * coords.scale, marginal)
      e <- inla.emarginal(function(x) x, m)
      e2 <- inla.emarginal(function(x) x^2, m)
      sd <- sqrt(e2-e^2)
      q <- inla.qmarginal(c(0.025, 0.5, 0.975), m)
      mode <- inla.mmarginal(m)
      x <- data.frame(e=e, sd=sd, q1=q[1], q2=q[2], q3=q[3], mode=mode)
      colnames(x) <- c("mean", "sd", "0.025quant","0.5quant","0.975quant", "mode")
      return(x)
    },
    
    summaryHyperparameters = function() {
      library(INLA)
      if (!any(names(result) == "summary.hyperpar")) {
        message("Model has no hyperparameters.")
      }
      else {
        spde.result <- inla.spde2.result(result, "s", spde)

        ###
        kappa <- exp(spde.result$summary.log.kappa$mean)
        tau <- exp(spde.result$summary.log.tau$mean)
        kappa.scaled <- kappa * 1/coords.scale
        
        c(kappa.scaled, tau)
        # Should be approximately the same
        c(sqrt(8)/kappa.scaled, exp(spde.result$summary.log.range.nominal$mean) * coords.scale) # scaled range
        (c(1/(4*pi*kappa^2*tau^2), exp(spde.result$summary.log.variance.nominal$mean))) # variance, do not use scaled kappa as scaling is compensated by tau
        ###
        
        range <- getINLAResult(spde.result$marginals.range.nominal[[1]], coords.scale=coords.scale)
        variance <- getINLAResult(spde.result$marginals.variance.nominal[[1]])
        kappa <- getINLAResult(spde.result$marginals.kappa[[1]], coords.scale=1/coords.scale)
        tau <- getINLAResult(spde.result$marginals.tau[[1]])
        
        y <- rbind(kappa=kappa,
                   tau=tau,
                   range=range,
                   variance=variance)
        if (any(rownames(result$summary.hyperpar)=="GroupRho for s"))
          y <- rbind(y, rho=result$summary.hyperpar["GroupRho for s",])
        colnames(y) <- c("mean","sd","0.025quant","0.5quant","0.975quant","mode")
        print(y)
      }
      invisible(.self)
    },
    
    loadBorder = function(fileName=file.path(basePath, "alandmap_1_20000/alandmap_rough")) {
      library(sp)
      library(maptools)
      return(readShapeSpatial(fileName))
    },
    
    plotMesh = function(borderFileName) {
      if (is.null(mesh)) stop("Mesh has not been set up.")
      
      border <- if (missing(borderFileName)) loadBorder()
      else loadBorder(fileName=borderFileName)
      
      t.sub <- 1:nrow(mesh$graph$tv)
      xlim <- range(mesh$loc[,1]) * coords.scale
      ylim <- range(mesh$loc[,2]) * coords.scale
      idx <- t(cbind(mesh$graph$tv[t.sub, c(1:3, 1), drop = FALSE], NA))
      x <- mesh$loc[idx, 1] * coords.scale
      y <- mesh$loc[idx, 2] * coords.scale
      
      plot.new()
      plot.window(xlim = xlim, ylim = ylim, "", asp=1)
      lines(x, y, type = "l", col = "gray", lwd=3)
      plot(border, add=T, border="black", lwd=6)
      points(unique(cbind(data$Longitude, data$Latitude)), pch=20, col="red")
      
      invisible(.self)
    },
    
    saveDataCSV = function(fileName) {
      write.csv(data, file=fileName)
    }
  )
)

ColonizationMildew <- setRefClass(
  "ColonizationMildew",
  contains = "OccupancyMildew",
  fields = list(
  ),
  methods = list(
    initialize = function(...) {
      callSuper(response="colonization", ...)
      invisible(.self)
    },
    
    loadRawData = function(mildewFile="SO_col_univariate_2001_2012.csv") {
      message("Loading ", response, " data...")
      
      mildew <- read.csv(file.path(basePath, mildewFile))
      mildew <- transform(mildew, y=as.logical(Col), road_PA=as.logical(road_PA), Open_bin=as.logical(Open_bin), varjoisuus=as.ordered(varjoisuus),
                          fallPLM2=fallPLM2, Distance_to_shore=Distance_to_shore, fallPLdry=fallPLdry,
                          logfallPLM2=log(fallPLM2), logDistance_to_shore=log(Distance_to_shore), S=S)
      mildew <- mergeRainfall(mildew)
      mildew$fallPLdry[mildew$fallPLdry > 100] <- NA
      mildew$varjoisuus[mildew$varjoisuus == 0] <- NA
      
      data <<- mildew
      invisible(.self)
    }
  )
)

ExtinctionMildew <- setRefClass(
  "ExtinctionMildew",
  contains = "OccupancyMildew",
  fields = list(
  ),
  methods = list(
    initialize = function(...) {
      callSuper(response="extinction", ...)
      invisible(.self)
    },
    
    loadRawData = function(mildewFile="SO_ext_univariate_2001_2012.csv") {
      message("Loading ", response, " data...")
      
      mildew <- read.csv(file.path(basePath, mildewFile))
      mildew <- transform(mildew, y=as.logical(Ext), road_PA=as.logical(road_PA), Open_bin=as.logical(Open_bin), varjoisuus=as.ordered(varjoisuus),
                          fallPLM2=fallPLM2, Distance_to_shore=Distance_to_shore, fallPLdry=fallPLdry,
                          logfallPLM2=log(fallPLM2), logDistance_to_shore=log(Distance_to_shore), S=S)
      mildew <- mergeRainfall(mildew)
      mildew$fallPLdry[mildew$fallPLdry > 100] <- NA
      mildew$varjoisuus[mildew$varjoisuus == 0] <- NA
            
      data <<- mildew
      invisible(.self)
    }
  )
)





ModelResults <- setRefClass(
  "ModelResults",
  fields = list(
    occ = "OccupancyMildew",
    col = "ColonizationMildew",
    ext = "ExtinctionMildew",
    shortName = "character",
    longName = "character"
  ),
  methods = list(
    initialize = function(basePath, type, tag="", shortName, ...) {
      callSuper(...)
      if (missing(basePath) | missing(type) | missing(shortName))
        stop("Missing argument.")
      shortName <<- shortName
      occ <<- OccupancyMildew$new(basePath=basePath)$loadResult(type, tag)
      col <<- ColonizationMildew$new(basePath=basePath)$loadResult(type, tag)
      ext <<- ExtinctionMildew$new(basePath=basePath)$loadResult(type, tag)
    }
  )
)

MildewResults = setRefClass(
  "MildewResults",
  fields = list(
    results = "list",
    basePath = "character"
  ),
  methods = list(
    initialize = function(basePath, ...) {
      callSuper(...)
      if (missing(basePath))
        stop("Missing argument.")
      basePath <<- basePath
      addResult(type="glm", shortName="OL")
      addResult(type="spatiotemporal", tag="interceptonly", shortName="ST-I")
      addResult(type="spatialonly", shortName="S")
      addResult(type="temporalreplicate", shortName="TR")
      addResult(type="spatialreplicate", shortName="SR")
      addResult(type="spatiotemporal", shortName="ST")
    },
    
    addResult = function(type, tag="", shortName) {
      n <- length(results)
      results[[n + 1]] <<- ModelResults$new(basePath=basePath, type=type, tag=tag, shortName=shortName)
    },
    
    plotYearEstimates = function(size=18) {
      library(plyr)
      library(ggplot2)
      library(grid)
      
      prepareResult <- function(mildew, predname, outcome) {
        library(reshape2)
        mildew.data <- mildew$data[!is.na(mildew$data$y),]        
        mildew.data$Year <- as.factor(mildew.data$Year)
        levels(mildew.data$Year) <- substr(levels(mildew.data$Year),3,4)        
        x <- melt(ddply(mildew.data, .(Year),
                        function(x) cbind(Observed=sum(x$y)/nrow(x),
                                          Predicted=sum(x$mu)/nrow(x))), ## TODO
                  #q025=quantile(x$mu, .025), q975=quantile(x$mu, .975))),
                  #q025=sum(x$mu025), q975=sum(x$mu975))),
                  id.vars="Year")
        x$Data <- as.factor(!(x$variable %in% "Observed"))
        levels(x$Data) <- c("Observed", predname)
        x$Summary <- as.factor(!(x$variable %in% c("Observed","Predicted")))
        levels(x$Summary) <- c("Mean","95% quantiles")
        x$Outcome <- outcome
        return(x)
      }
              
      result <- ldply(results, function(x) {
        rbind(prepareResult(x$occ, x$shortName, "Occupancy"),
              prepareResult(x$col, x$shortName, "Colonization"),
              prepareResult(x$ext, x$shortName, "Extinction"))
      })
      
      result$Outcome <- factor(result$Outcome)
            
      years <- levels(result$Year)
      breaks <- years[seq(1, length(years), by=2)]
      years.numeric <- as.numeric(as.character(result$Year))
      breaks.numeric <- seq(min(years.numeric), max(years.numeric), by=2)
      labels <- sprintf(breaks.numeric, fmt="%02d")
      #print(breaks.numeric)
      #print(labels)
      p <- ggplot(result, aes(x=Year, y=value, group=interaction(variable, Data), colour=Data)) +
        geom_line(size=1, aes(linetype=Data)) + facet_wrap(~Outcome, scales="free_y") +
        #geom_line(aes(linetype=Summary), size=1) +
        ylab("Probability") + theme_bw(size) +
        theme(legend.position="bottom", legend.title=element_blank()) +
        theme(plot.margin=unit(c(0,0,-1,0), "lines")) +
        scale_x_discrete(breaks=breaks, labels=labels)
      
      print(p)
      ggsave(p, filename=file.path(basePath, paste("years", "all", ".png", sep="")), width=8, height=4)
      return(p)
    }
        
  )
)
