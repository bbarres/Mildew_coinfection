library(CNPCluster)
library(Mildew)

if (!exists("basePath") | !exists("runParallel"))
  stop("Please set basePath and runParallel parameters.")



coinfection<- CoinfectionMildew$new(basePath="")
coinfection$loadRawData()
coinfection$data






