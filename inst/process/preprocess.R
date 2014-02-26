library(CNPCluster)
library(Mildew)

if (!exists("basePath") | !exists("runParallel"))
  stop("Please set basePath and runParallel parameters.")


#dataset with uncorrected number of MLG
coinfection<- CoinfectionMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
coinfection$loadRawData(mildewFile="stat_patch2012.txt")
coinfection$data
coinfection$saveData()

#dataset with corrected number of MLG
coinfection<- CoinfectionMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
coinfection$loadRawData(mildewFile="stat_patch2012corr.txt")
coinfection$data
coinfection$saveData()




