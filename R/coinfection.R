#New class coinfection

CoinfectionMildew<- setRefClass(
  "CoinfectionMildew", 
  contains = "OccupancyMildew",
  fields = list(),
  methods = list(
    loadRawData = function(mildewFile){
     temp<-read.table(file.path(basePath,mildewFile),header=TRUE,sep="\t")
      
      
     data<<-temp
      #data<<-data.frame(x=c(1,2,3,4))
    })
  
  )












