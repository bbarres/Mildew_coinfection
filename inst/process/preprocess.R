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
#2012
coinfection<- CoinfectionMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
coinfection$loadRawData(mildewFile="stat_patch2012corr.txt",
                        selecfact=c("ID","number_coinf","number_genotyped","number_pure","number_MLG","number_pure_new",
                                    "Longitude","Latitude","Area_real","PLM2_Sept2012","PA_2011","connec2012","RA_F2012",
                                    "AA_F2012"))
coinfection$data
coinfection$saveData()
#2013
coinfection<- CoinfectionMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
coinfection$loadRawData(mildewFile="stat_patch2013corr.txt",
                        selecfact=c("ID","number_coinf","number_genotyped","number_pure","number_MLG","number_pure_new",
                                    "Longitude","Latitude","Area_real","PLM2_Sept2012","PA_2011","connec2012","RA_F2012",
                                    "AA_F2012"))
coinfection$data
coinfection$saveData()

#dataset with 5 samples re-sampled from patches with at least 5 sampled individuals
coinfection<- CoinfectionMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
coinfection$loadRawData(mildewFile="stat_patch2012_5.txt")
coinfection$data
coinfection$saveData()

#dataset with 5 samples re-sampled from patches with at least 5 sampled individuals and corrected number of MLG
coinfection<- CoinfectionMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
coinfection$loadRawData(mildewFile="stat_patch2012_5corr.txt")
coinfection$data
coinfection$saveData()



#dataset with prevalence spring and autumn with sample size > 3
varpreval<- VarprevalMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
varpreval$loadRawData(mildewFile="stat_patch2012corr_evolabund.txt",
                      selecfact=c("ID","number_coinf","number_genotyped","number_pure","number_MLG","number_pure_new",
                                  "Longitude","Latitude","Area_real","connec2012","AA_F2012","AA_S2012"))
varpreval$data
varpreval$saveData()

#Not working anymore since modification of the code#################
# #dataset with prevalence spring and autumn
# varpreval<- VarprevalMildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
# varpreval$loadRawData(mildewFile="stat_patch2012corr.txt")
# varpreval$data
# varpreval$saveData()
# 
#dataset with 5 samples re-sampled from patches with at least 5 sampled individuals and corrected number of MLG
survival<- Survival2013Mildew$new(basePath="C:/HY-Data/BBARRES/documents/Work/Rfichiers/Podosphaera/coinfection")
survival$loadRawData(mildewFile="stat_patch2012_5corr.txt")
survival$data
survival$saveData()########################

