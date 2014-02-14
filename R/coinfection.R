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
                                   "factor","factor","factor","factor","factor","factor","factor","numeric",
                                   "factor","numeric","numeric","numeric","factor","numeric","numeric","numeric",
                                   "numeric","factor","factor"))
      
      
     data<<-temp
      #data<<-data.frame(x=c(1,2,3,4))
    })
  
  )












