#New class coinfection

CoinfectionMildew<- setRefClass(
  "CoinfectionMildew", 
  contains = "OccupancyMildew",
  fields = list(),
  methods = list(
    loadRawData = function(mildewFile){
     temp<-read.table(file.path(basePath,mildewFile),header=TRUE,sep="\t",
                      colClasses=c("factor","numeric","numeric","numeric","numeric","numeric","numeric","numeric",
                                   "numeric","numeric","numeric","numeric","numeric","factor","character","character",
                                   "numeric","numeric","numeric","numeric","numeric","numeric","numeric","numeric",
                                   "numeric","numeric","factor","factor","factor","factor","factor","factor",
                                   "factor","factor","factor","factor","factor","factor","factor","factor","numeric",
                                   "factor","numeric","numeric","numeric","factor","numeric","numeric","numeric",
                                   "numeric","factor","factor"))
     colnames(temp)[1]<-"ID"
     temp<-temp[,c("ID","number_coinf","number_genotyped","number_pure","number_MLG","number_pure_new",
                   "Longitude","Latitude","Area_real","PA_2011","connec2012","cumulative_sum","road_PA",
                   "Distance_to_shore")]
     data<<-temp
      #data<<-data.frame(x=c(1,2,3,4))
    },
    
    loadBorder = function(fileName=file.path(basePath, "alandmap_rough.shp")) {
      library(sp)
      library(maptools)
      library(rgdal)
      Aland<-readShapePoly(fileName,proj4string=CRS("+init=epsg:2393"))  
      Aland<-spTransform(Aland,CRS("+init=epsg:3067"))
      return(Aland)
    })
  
  )












