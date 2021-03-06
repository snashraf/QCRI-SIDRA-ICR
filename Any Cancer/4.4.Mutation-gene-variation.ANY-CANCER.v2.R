#################################################################
###
### This Script calculates the statistics for
### diferentially mutated genes and trends.
###
#################################################################

# Setup environment
rm(list=ls())
#setwd("~/Dropbox/BREAST_QATAR/")
setwd("c:/Users/whendrickx/Dropbox/BREAST_QATAR/")

## Parameters
Cancerset <- "BRCA.BSF2"        # FOR BRCA use BRCA.PCF or BRCA.BSF
Geneset = "DBGS3.FLTR"         # SET GENESET HERE !!!!!!!!!!!!!!
K = 4                          # SET K here
Filter = 1                     # at least one clutser has to have x% mutation frequency
mutation.type = "NonSilent"    # Alterantives "Any" , "Missense" , "NonSilent"
clusters = paste0(rep("ICR",4), 1:4)
IMS.filter = "All"      # Alterantives "All" , "Luminal" , "Basal", "Her2" ,"LumA" ,"LumB"

## Read the mutation frequency file  (Mutation.Frequency.Gene)
load (paste0("./3 ANALISYS/Mutations/",Cancerset,"/Mutation.Data.TCGA.",Cancerset,".",IMS.filter,".",Geneset,".Frequencies.RDATA"))
#numMuts.Any      = data.frame(count=Mutation.Frequency.Patient$Freq.Any,cluster=Mutation.Frequency.Patient$Cluster,mut.type = "Any")
#numMuts.Missense = data.frame(count=Mutation.Frequency.Patient$Freq.Missense,cluster=Mutation.Frequency.Patient$Cluster,mut.type = "Missense")

## Pick genes based on cutoff (Freq.Any.pct OR Freq.Missense.Any.pct) (present in at least "cutoff" samples for each cluster)
gene.list = as.character(unique(Mutation.Frequency.Gene$Hugo_Symbol))
gene.list.selected = NULL
if (mutation.type=="Any") {
  gene.list.selected = unique(Mutation.Frequency.Gene[which(Mutation.Frequency.Gene$Freq.Any.pct>Filter),"Hugo_Symbol"]) #filter one clutser has to have x% mutation
} 
if (mutation.type=="Missense") {
  gene.list.selected = unique(Mutation.Frequency.Gene[which(Mutation.Frequency.Gene$Freq.Missense.Any.pct>Filter),"Hugo_Symbol"]) #filter one clutser has to have x% mutation
} 
if (mutation.type=="NonSilent") {
  gene.list.selected = unique(Mutation.Frequency.Gene[which(Mutation.Frequency.Gene$Freq.NonSilent.Any.pct>Filter),"Hugo_Symbol"]) #filter one clutser has to have x% mutation
} 
variation.table = NULL

gene.list.selected = c(as.character(gene.list.selected),"MAPX")
Test = MAPX.data <- Mutation.Frequency.Gene[which(Mutation.Frequency.Gene$Hugo_Symbol=="MAP3K1" | Mutation.Frequency.Gene$Hugo_Symbol=="MAP2K4"),]

MAPX.data <- Mutation.Frequency.Gene[which(Mutation.Frequency.Gene$Hugo_Symbol=="MAP3K1" | Mutation.Frequency.Gene$Hugo_Symbol=="MAP2K4"),]
MAPX.data[is.na(MAPX.data)] <- 0
MAPX.data.sum <- ddply(MAPX.data, "Cluster", numcolwise(sum))
MAPX.data.sum <- as.data.frame(cbind (Hugo_Symbol="MAPX",MAPX.data.sum))
MAPX.data.sum <- MAPX.data.sum[order(MAPX.data.sum$Cluster),]
MAPX.data.sum$N <- sample.cluster.count$N

## for each gene, pick the 4 clusters, corresponding Freq.Any.pct OR Freq.Missense.Any.pct
for (gene in gene.list.selected){
  #print(gene)

  gene.data = Mutation.Frequency.Gene[which(Mutation.Frequency.Gene$Hugo_Symbol==gene),]   # select a gene
  if(gene=="MAPX") gene.data = MAPX.data.sum
  gene.data[is.na(gene.data)] = 0
  # Add missing clusters data
  gene.clusters = gene.data$Cluster
  if(length(gene.clusters)<4){
  missing.clusters = clusters[which(!(clusters %in% gene.clusters))]
  gene.missingdata = data.frame(matrix(ncol=ncol(gene.data), nrow=length(missing.clusters)))
  colnames(gene.missingdata) = colnames(gene.data)
  gene.missingdata$Hugo_Symbol = gene
  gene.missingdata$Cluster = missing.clusters
  gene.missingdata[is.na(gene.missingdata)] = 0
  gene.data = rbind(gene.data, gene.missingdata)
  }
  gene.data = gene.data[order(gene.data$Cluster),]
  gene.data$N = sample.cluster.count$N
  
  if (mutation.type=="Any") {
    gene.data.pct = gene.data[which(gene.data$Hugo_Symbol==gene),"Freq.Any.pct"]           # add the percentages
    gene.patients = gene.data$Freq.Any
  }
  if (mutation.type=="Missense") {
    gene.data.pct = gene.data[which(gene.data$Hugo_Symbol==gene),"Freq.Missense.Any.pct"]  # add the percentages
    gene.patients = gene.data$Freq.Missense.Any
  }
  if (mutation.type=="NonSilent") {
    gene.data.pct = gene.data[which(gene.data$Hugo_Symbol==gene),"Freq.NonSilent.Any.pct"] # add the percentages
    gene.patients = gene.data$Freq.NonSilent.Any
  }
  ## FIsher exact test ICR1 vs ICR4
  gene.patients[is.na(gene.patients)] = 0
  gene.patients.wt = sample.cluster.count$N-gene.patients
  test.matrix = cbind(gene.patients[c(1,4)],gene.patients.wt[c(1,4)])
  res.f = fisher.test(test.matrix)
 
  if (sum(rowSums(test.matrix))>0) {
    res.c = chisq.test(test.matrix)
  }
  
  #print(gene)
  #print( res$p.value)
  
  variation = max(gene.data.pct) - min(gene.data.pct)                                      # calculate max variation
  trend = sign(diff(gene.data.pct))                                                        # add direction of change
  trend.test = (trend[which(trend!=0)])                                                    # exclude 0's from trend
  flag = all(trend.test==trend.test[1])                                                    # test for trend 
  if(all(trend.test==0)){flag=FALSE}                                                       # 0,0,0 = no trend
  gene.data[is.na(gene.data)] <- 0
  ## Add Chi-square
  all.patients = gene.data$N
  trend.results = prop.trend.test(gene.patients, all.patients)
  trend.matrix = paste0(c(gene.patients, all.patients), collapse = ":")
  trend.pval = trend.results[[3]]
  db.test=FALSE
  if (gene.data.pct[1]<=1) {
    if ((gene.data.pct[4] - gene.data.pct[1])>=4){
      db.test=TRUE
    }
  }
  if (gene.data.pct[4]<=1) {
    if ((gene.data.pct[1] - gene.data.pct[4])>=4){
      db.test=TRUE
    }
  }  
  gene.data.row = data.frame(gene,
                             paste0(gene.data.pct, collapse=" : "),
                             variation,
                             paste0((trend), collapse=" -> "),
                             flag,
                             trend.matrix,
                             trend.pval,
                             paste0(test.matrix, collapse=" : "),
                             res.f$p.value,
                             res.c$p.value,
                             db.test)  
  variation.table = rbind(variation.table, gene.data.row)
  res.c$p.value = NA
}
colnames(variation.table) = c("Gene",
                              "Cluster_Percentages",
                              "Max_Variation",
                              "Direction",
                              "Trend",
                              "Trend_Matrix",
                              "Trend_pVal_ChiSquared",
                              "testmatrix",
                              "Fisher_ICR1vs4",
                              "ChiSquare_ICR1vs4",
                              "db.test")

write.csv (variation.table,file=paste0("./3 ANALISYS/Mutations/",Cancerset,"/",Cancerset,".",IMS.filter,".",Geneset,".",mutation.type,".VariationTable.csv"))
variation.table <- read.csv(paste0("./3 ANALISYS/Mutations/",Cancerset,"/",Cancerset,".",IMS.filter,".",Geneset,".",mutation.type,".VariationTable.csv"))

# significance filter
SL1 = 0.0005 #chisquare p for LOW OR trend = TRUE
SL2 = 4   #maxvar Filter multiplier for LOW
SH1 = SL1/10 #chisquare p for HIGH OR trend = TRUE
SH2 = SL2*2 #maxvar Filter multiplier for HIGH
low.significant.variation.table = variation.table[which((variation.table$Trend_pVal_ChiSquared<SL1 | variation.table$Trend) & variation.table$Max_Variation>=Filter*SL2), ]  
high.significant.variation.table = variation.table[which((variation.table$Trend_pVal_ChiSquared<SH1 | variation.table$Trend) & variation.table$Max_Variation>=Filter*SH2), ] 
db.test.significant.variation.table = variation.table[which(variation.table$db.test | variation.table$ChiSquare_ICR1vs4<0.05), ]
db.test.strict.significant.variation.table = variation.table[which(variation.table$db.test & variation.table$ChiSquare_ICR1vs4<0.05), ]
chisq.significant.variation.table = variation.table[which(variation.table$ChiSquare_ICR1vs4<0.05), ]
fisher.significant.variation.table = variation.table[which(variation.table$Fisher_ICR1vs4<0.01), ]

# settings Table (SL1,SL2,SH1,SH2)
# BLCA  (0.01,2,0.005,4)
# COAD  (0.0005,4,0.00005,8)

#automatic significance filter
ASF1     = 0.001
ASF2     = 1
ASF.stop = 30
L.sig = nrow(variation.table)
while (L.sig > ASF.stop){
  auto.significant.variation.table = variation.table[which((variation.table$Trend_pVal_ChiSquared<ASF1 | variation.table$Trend) & variation.table$Max_Variation>=Filter*ASF2), ]
  ASF2 = ASF2+0.1
  L.sig = nrow(auto.significant.variation.table)
}

save(low.significant.variation.table,
     high.significant.variation.table,
     auto.significant.variation.table,
     db.test.significant.variation.table,
     db.test.strict.significant.variation.table,
     chisq.significant.variation.table,
     fisher.significant.variation.table,
     variation.table,
     file=paste0("./3 ANALISYS/Mutations/",Cancerset,"/",Cancerset,".",IMS.filter,".",Geneset,".",mutation.type,".VariationTables.RData"))

