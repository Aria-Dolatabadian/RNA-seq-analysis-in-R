#https://combine-australia.github.io/RNAseq-R/06-rnaseq-day1.html

#install packages
if (!requireNamespace("BiocManager"))
    install.packages("BiocManager")
BiocManager::install(c("limma", "edgeR", "Glimma", "org.Mm.eg.db", "gplots", "RColorBrewer", "NMF", "BiasedUrn"))

#install Go.db
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install("GO.db")

#load packages
library(edgeR)
library(limma)
library(Glimma)
library(org.Mm.eg.db)
library(gplots)
library(RColorBrewer)
library(NMF)
library(GO.db)

#Place data files into a folder called data in your working directory


# Read the data into R
seqdata <- read.delim("data/GSE60450_Lactation-GenewiseCounts.txt", stringsAsFactors = FALSE)
# Read the sample information into R
sampleinfo <- read.delim("data/SampleInfo.txt", stringsAsFactors = TRUE)

seqdata
head(seqdata)
dim(seqdata)

sampleinfo
head(sampleinfo)
dim(sampleinfo)

#Format the data

# Remove first two columns from seqdata
countdata <- seqdata[,-(1:2)]
# Look at the output
head(countdata)

# Store EntrezGeneID as rownames
rownames(countdata) <- seqdata[,1]
head(countdata)

#look at the column names
colnames(countdata)

# using substr, you extract the characters starting at position 1 and stopping at position 7 of the colnames
colnames(countdata) <- substr(colnames(countdata),start=1,stop=7)

head(countdata)

#Note that the column names are now the same as SampleName in the sampleinfo file. This is good because it means our sample information in sampleinfo is in the same order as the columns in countdata.
table(colnames(countdata)==sampleinfo$SampleName)


#Convert counts to DGEList object

y <- DGEList(countdata)
# have a look at y
y


# See what slots are stored in y
names(y)


# Library size information is stored in the samples slot
y$samples

#We can also store the groups for the samples in the DGEList object.

group <- paste(sampleinfo$CellType,sampleinfo$Status,sep=".")
# Take a look
group


# Convert to factor
group <- factor(group)
# Take another look.
group


# Add the group information into the DGEList
y$samples$group <- group
y$samples


#Adding annotation

#see what we can extract we can run the columns function on the annotation database.
columns(org.Mm.eg.db)

#We definitely want gene symbols and perhaps the full gene name. Let???s build up our annotation information in a separate data frame using the select function.
ann <- select(org.Mm.eg.db,keys=rownames(y$counts),columns=c("ENTREZID","SYMBOL","GENENAME"))

# Have a look at the annotation
head(ann)

#Let???s double check that the ENTREZID column matches exactly to our y$counts rownames.

table(ann$ENTREZID==rownames(y$counts))

#We can slot in the annotation information into the genes slot of y. (Please note that if the select function returns a 1:many mapping then you can???t just append the annotation to the y object. An alternative way to get annotation will be discussed during the analysis of the second dataset.)
y$genes <- ann

#Filtering lowly expressed genes. Genes with very low counts across all libraries provide little evidence for differential expression and they interfere with some of the statistical approximations that are used later in the pipeline.

# Obtain CPMs
myCPM <- cpm(countdata)
# Have a look at the output
head(myCPM)

# Which values in myCPM are greater than 0.5?
thresh <- myCPM > 0.5
# This produces a logical matrix with TRUEs and FALSEs
head(thresh)

# Summary of how many TRUEs there are in each row
# There are 11433 genes that have TRUEs in all 12 samples.
table(rowSums(thresh))

# we would like to keep genes that have at least 2 TRUES in each row of thresh
keep <- rowSums(thresh) >= 2
summary(keep)

# Let's have a look and see whether our threshold of 0.5 does indeed correspond to a count of about 10-15
# We will look at the first sample

plot(myCPM[,1],countdata[,1])
x11()

# Let us limit the x and y-axis so we can actually look to see what is happening at the smaller counts
plot(myCPM[,1],countdata[,1],ylim=c(0,50),xlim=c(0,3))
# Add a vertical line at 0.5 CPM
abline(v=0.5)
x11()

y <- y[keep, keep.lib.sizes=FALSE]

#Quality control
#Library size and distribution plots
#check how many reads we have for each sample in the y

y$samples$lib.size

#We can also plot the library sizes as a barplot to see whether there are any major discrepancies between the samples more easily
# The names argument tells the barplot to use the sample names on the x-axis
# The las argument rotates the axis names
barplot(y$samples$lib.size,names=colnames(y),las=2)
# Add a title to the plot
title("Barplot of library sizes")
x11()

# we can also adjust the labelling if we want
barplot(y$samples$lib.size/1e06, names=colnames(y), las=2, ann=FALSE, cex.names=0.75)
mtext(side = 1, text = "Samples", line = 4)
mtext(side = 2, text = "Library size (millions)", line = 3)
title("Barplot of library sizes")
x11()


#Count data is not normally distributed, so if we want to examine the distributions of the raw counts we need to log the counts
# Get log2 counts per million
logcounts <- cpm(y,log=TRUE)
# Check distributions of samples using boxplots
boxplot(logcounts, xlab="", ylab="Log2 counts per million",las=2)
# Let's add a blue horizontal line that corresponds to the median logCPM
abline(h=median(logcounts),col="blue")
title("Boxplots of logCPMs (unnormalised)")
x11()

#Multidimensional scaling plots
#By far, one of the most important plots we make when we analyse RNA-Seq data are MDSplots. An MDSplot is a visualisation of a principle components analysis, which determines the greatest sources of variation in the data. 

plotMDS(y)
x11()

# We specify the option to let us plot two plots side-by-side

par(mfrow=c(1,2))

# Let's set up colour schemes for CellType
# How many cell types and in what order are they stored?
levels(sampleinfo$CellType)

## Let's choose purple for basal and orange for luminal
col.cell <- c("purple","orange")[sampleinfo$CellType]
data.frame(sampleinfo$CellType,col.cell)

# Redo the MDS with cell type colouring
plotMDS(y,col=col.cell)
# Let's add a legend to the plot so we know which colours correspond to which cell type
legend("topleft",fill=c("purple","orange"),legend=levels(sampleinfo$CellType))
# Add a title
title("Cell type")

# Similarly for status
levels(sampleinfo$Status)

col.status <- c("blue","red","black")[sampleinfo$Status]
col.status

plotMDS(y,col=col.status)
legend("topleft",fill=c("blue","red","black"),legend=levels(sampleinfo$Status),cex=0.8)
title("Status")
x11()

# There is a sample info corrected file in your data directory
# Old sampleinfo
sampleinfo


# I'm going to write over the sampleinfo object with the corrected sample info
sampleinfo <- read.delim("data/SampleInfo_Corrected.txt", stringsAsFactors = TRUE)
sampleinfo

# We need to correct the info for the groups
group <- factor(paste(sampleinfo$CellType,sampleinfo$Status,sep="."))
y$samples$group <- group

# Redo the MDSplot with corrected information
par(mfrow=c(1,2))
col.cell <- c("purple","orange")[sampleinfo$CellType]
col.status <- c("blue","red","black")[sampleinfo$Status]
plotMDS(y,col=col.cell)
legend("topleft",fill=c("purple","orange"),legend=levels(sampleinfo$CellType))
title("Cell type")
plotMDS(y,col=col.status)
legend("topleft",fill=c("blue","red","black"),legend=levels(sampleinfo$Status),cex=0.8)
title("Status")
x11()

#Another alternative is to generate an interactive MDS plot using the Glimma package. This allows the user to interactively explore the different dimensions.
labels <- paste(sampleinfo$SampleName, sampleinfo$CellType, sampleinfo$Status)
glMDSPlot(y, labels=labels, groups=group, folder="mds")


#Hierarchical clustering with heatmaps

# We estimate the variance for each row in the logcounts matrix
var_genes <- apply(logcounts, 1, var)
head(var_genes)

# Get the gene names for the top 500 most variable genes
select_var <- names(sort(var_genes, decreasing=TRUE))[1:500]
head(select_var)

# Subset logcounts matrix
highly_variable_lcpm <- logcounts[select_var,]
dim(highly_variable_lcpm)

head(highly_variable_lcpm)

## Get some nicer colours
mypalette <- brewer.pal(11,"RdYlBu")
morecols <- colorRampPalette(mypalette)
# Set up colour vector for celltype variable
col.cell <- c("purple","orange")[sampleinfo$CellType]

# Plot the heatmap
heatmap.2(highly_variable_lcpm,col=rev(morecols(50)),trace="none", main="Top 500 most variable genes across samples",ColSideColors=col.cell,scale="row")
x11()

# Save the heatmap
png(file="High_var_genes.heatmap.png")
heatmap.2(highly_variable_lcpm,col=rev(morecols(50)),trace="none", main="Top 500 most variable genes across samples",ColSideColors=col.cell,scale="row")
dev.off()

#If we wanted to add more annotations
mypalette <- brewer.pal(11,"RdYlBu")
morecols <- colorRampPalette(mypalette)
aheatmap(highly_variable_lcpm,col=rev(morecols(50)),main="Top 500 most variable genes across samples",annCol=sampleinfo[, 3:4],labCol=group, scale="row")
x11()


#Normalisation for composition bias

# Apply normalisation to DGEList object
y <- calcNormFactors(y)

y$samples

par(mfrow=c(1,2))
plotMD(logcounts,column = 7)
abline(h=0,col="grey")
plotMD(logcounts,column = 11)
abline(h=0,col="grey")
x11()

par(mfrow=c(1,2))
plotMD(y,column = 7)
abline(h=0,col="grey")
plotMD(y,column = 11)
abline(h=0,col="grey")
x11()

#Differential expression with limma-voom
# load("day1objects.Rdata")
# objects()
#Create the design matrix
# Look at group variable again
group

# Specify a design matrix without an intercept term
design <- model.matrix(~ 0 + group)
design

## Make the column names of the design matrix a bit nicer
colnames(design) <- levels(group)
design

#Voom transform the data

par(mfrow=c(1,1))
v <- voom(y,design,plot = TRUE)
x11()
v

# What is contained in this object?
names(v)

par(mfrow=c(1,2))
boxplot(logcounts, xlab="", ylab="Log2 counts per million",las=2,main="Unnormalised logCPM")
## Let's add a blue horizontal line that corresponds to the median logCPM
abline(h=median(logcounts),col="blue")
boxplot(v$E, xlab="", ylab="Log2 counts per million",las=2,main="Voom transformed logCPM")
## Let's add a blue horizontal line that corresponds to the median logCPM
abline(h=median(v$E),col="blue")
x11()

#Testing for differential expression

# Fit the linear model
fit <- lmFit(v)
names(fit)

cont.matrix <- makeContrasts(B.PregVsLac=basal.pregnant - basal.lactate,levels=design)
cont.matrix


fit.cont <- contrasts.fit(fit, cont.matrix)

fit.cont <- eBayes(fit.cont)

dim(fit.cont)

summa.fit <- decideTests(fit.cont)
summary(summa.fit)

#Writing out the results
#Plots after testing for DE

# We want to highlight the significant genes. We can get this from decideTests.
par(mfrow=c(1,2))
plotMD(fit.cont,coef=1,status=summa.fit[,"B.PregVsLac"], values = c(-1, 1), hl.col=c("blue","red"))

# For the volcano plot we have to specify how many of the top genes to highlight.
# We can also specify that we want to plot the gene symbol for the highlighted genes.
# let's highlight the top 100 most DE genes
volcanoplot(fit.cont,coef=1,highlight=100,names=fit.cont$genes$SYMBOL, main="B.PregVsLac")
x11()


par(mfrow=c(1,3))
# Let's look at the first gene in the topTable, Wif1, which has a rowname 24117
stripchart(v$E["24117",]~group)
# This plot is ugly, let's make it better
stripchart(v$E["24117",]~group,vertical=TRUE,las=2,cex.axis=0.8,pch=16,col=1:6,method="jitter")
# Let's use nicer colours
nice.col <- brewer.pal(6,name="Dark2")
stripchart(v$E["24117",]~group,vertical=TRUE,las=2,cex.axis=0.8,pch=16,cex=1.3,col=nice.col,method="jitter",ylab="Normalised log2 expression",main="Wif1")
x11()


group2 <- group
levels(group2) <- c("basal.lactate","basal.preg","basal.virgin","lum.lactate", "lum.preg", "lum.virgin")
glXYPlot(x=fit.cont$coefficients[,1], y=fit.cont$lods[,1],
         xlab="logFC", ylab="B", main="B.PregVsLac",
         counts=v$E, groups=group2, status=summa.fit[,1],
         anno=fit.cont$genes, side.main="ENTREZID", folder="volcano")


#Testing relative to a threshold (TREAT)

# Let's decide that we are only interested in genes that have a absolute logFC of 1.
# This corresponds to a fold change of 2, or 0.5 (i.e. double or half).
# We can perform a treat analysis which ranks our genes according to p-value AND logFC.
# This is easy to do after our analysis, we just give the treat function the fit.cont object and specify our cut-off.

fit.treat <- treat(fit.cont,lfc=1)
res.treat <- decideTests(fit.treat)
summary(res.treat)


topTable(fit.treat,coef=1,sort.by="p")

# Notice that much fewer genes are highlighted in the MAplot
par(mfrow=c(1,2))
plotMD(fit.treat,coef=1,status=res.treat[,"B.PregVsLac"], values=c(-1,1), hl.col=c("blue","red"))
abline(h=0,col="grey")

plotMD(fit.treat,coef=2,status=res.treat[,"L.PregVsLac"], values=c(-1,1), hl.col=c("blue","red"))
abline(h=0,col="grey")
x11()

#An interactive version of the mean-difference plots is possible via the glMDPlot function in the Glimma package

glMDPlot(fit.treat, coef=1, counts=v$E, groups=group2,
        status=res.treat, side.main="ENTREZID", main="B.PregVsLac",
        folder="md")


#Gene Set Testing
#Gene ontology testing with goana

go <- goana(fit.cont, coef="B.PregVsLac",species = "Mm")
topGO(go, n=10)


colnames(seqdata)

m <- match(rownames(fit.cont),seqdata$EntrezGeneID)
gene_length <- seqdata$Length[m]
head(gene_length)

# Rerun goana with gene length information
go_length <- goana(fit.cont,coef="B.PregVsLac",species="Mm",
                   covariate=gene_length)
topGO(go_length, n=10)

#CAMERA gene set testing using the Broad???s curated gene sets

# Load in the mouse c2 gene sets as Mm.c2
Mm.c2 <- readRDS("data/Mm.c2.all.v7.1.entrez.rds")
# Have a look at the first few gene sets
names(Mm.c2)[1:5]

# Number of gene sets in C2
length(Mm.c2)


c2.ind <- ids2indices(Mm.c2, rownames(v))
gst.camera <- camera(v,index=c2.ind,design=design,contrast = cont.matrix[,1],inter.gene.cor=0.05)
gst.camera[1:5,]

table(gst.camera$FDR < 0.05)

#You can write out the camera results to a csv file to open in excel.
write.csv(gst.camera,file="gst_BPregVsLac.csv")

#ROAST gene set testing

H.camera[1:10,] #not working

grep("MYC_",names(c2.ind))

# Let's save these so that we can subset c2.ind to test all gene sets with MYC in the name
myc <- grep("MYC_",names(c2.ind))
# What are these pathways called?
names(c2.ind)[myc]


myc.rst <- roast(v,index=c2.ind[myc],design=design,contrast=cont.matrix[,1],nrot=999)
myc.rst[1:15,]

#Visualising gene set tests: Barcode and enrichment plots
# Have a look at the logFCs and t-statistics in fit.cont
names(fit.cont)

head(fit.cont$coefficients)

head(fit.cont$t)

par(mfrow=c(1,1))
# barcode plot with logFCs
barcodeplot(fit.cont$coeff[,1], index=c2.ind[["DANG_REGULATED_BY_MYC_UP"]], main="LogFC: DANG_REGULATED_BY_MYC_UP")
x11()

# barcode plot using t-statistics
barcodeplot(fit.cont$t[,1], index=c2.ind[["DANG_REGULATED_BY_MYC_UP"]], main="T-statistic: DANG_REGULATED_BY_MYC_UP")











