#!/bin/echo Source me don't execute me 

if (!exists("gform"))            gform            <- "uneak"
if (!exists("genofile"))         genofile         <- "HapMap.hmc.txt"
if (!exists("sampdepth.thresh")) sampdepth.thresh <- 0.01
if (!exists("snpdepth.thresh"))  snpdepth.thresh  <- 0.01
if (!exists("hirel.thresh"))     hirel.thresh     <- 0.9
if (!exists("cex.pointsize"))    cex.pointsize    <- 1
if (!exists("functions.only"))   functions.only   <- FALSE
if (!exists("outlevel"))         outlevel         <- 9

readTD <- function(genofilefn = genofile) {
  havedt <- require("data.table")
  ghead <- scan(genofilefn, what = "", nlines = 1, sep = ",")
  nsnps <<- (length(ghead) - 1)/2
  SNP_Names <<- read.table(text=ghead[-1][2*seq(nsnps)],sep="_",fill=TRUE,stringsAsFactors=FALSE)[,1]
  if (havedt) {
   isgzfile <- grepl(".gz",genofilefn) #gz unzipping will only work on linux systemss
   if(isgzfile) genosin <- fread(paste("gunzip -c",genofilefn),sep=",",header=TRUE,showProgress=FALSE)
   if(!isgzfile) genosin <- fread(genofilefn,sep=",",header=TRUE)
   seqID <<- genosin$V1
   nind <<- length(seqID)
   alleles <<- as.matrix(genosin[,-1,with=FALSE])
   } else {
   genosin <- scan(genofilefn, skip = 1, sep = ",", what = c(list(seqID = ""), rep(list(0), 2*nsnps))) 
   seqID <<- genosin[[1]]
   nind <<- length(seqID)
   alleles <<- matrix(0, nrow = nind, ncol = 2 * nsnps)
   for (isnp in seq(2*nsnps)) alleles[, isnp] <<- genosin[[isnp+1]] 
   }
  NULL
}


if(!functions.only) {
if (gform == "chip") {
  ghead <- scan(genofile,what="",nlines=1,sep=",")
  genost <- scan(genofile,what="",skip=1,sep=",") # read as text ... easier to pull out elements than list of nsnps+1
  SNP_Names <- ghead[-1]
  nsnps <- length(SNP_Names)
  snpnums <- ((1:length(genost))-1) %% (nsnps+1)
  genon <- matrix(as.numeric(genost[which(snpnums !=0)]) ,ncol=nsnps,byrow=TRUE)
  seqID <-  genost[which(snpnums ==0)]
  nind <- length(seqID)
  rm(genost)
  depth <- matrix(Inf, nrow = nind, ncol = nsnps)
  depth[is.na(genon)] <- 0
  p <- colMeans(genon, na.rm = TRUE)/2 # same as pg further down
 } else {
  if(gform=="TagDigger") {
   readTD()
   } else {
   gsep <- switch(gform, uneak = "|", Tassel = ",")
   ghead <- scan(genofile, what = "", nlines = 1, sep = "\t")
   nind <- length(ghead) - switch(gform, uneak = 6, Tassel = 2)
   seqID <- switch(gform, uneak = ghead[2:(nind + 1)], Tassel = ghead[-(1:2)])
   if (gform == "Tassel") 
     genosin <- scan(genofile, skip = 1, sep = "\t", what = c(list(chrom = "", coord = 0), rep(list(""), nind)))
   if (gform == "uneak") 
     genosin <- scan(genofile, skip = 1, sep = "\t", what = c(list(chrom = ""), rep(list(""), nind), list(hetc1 = 0, hetc2 = 0, acount1 = 0, acount2 = 0, p = 0)))
   SNP_Names <- genosin[[1]]
   nsnps <- length(SNP_Names)
   alleles <- matrix(0, nrow = nind, ncol = 2 * nsnps)
   for (iind in 1:nind) alleles[iind, ] <- matrix(as.numeric(unlist(strsplit(genosin[[iind + switch(gform, uneak = 1, Tassel = 2)]], split = gsep, 
                                                  fixed = TRUE))), nrow = 1)
   }
  depth <- alleles[, seq(1, 2 * nsnps - 1, 2)] + alleles[, seq(2, 2 * nsnps, 2)]
  sampdepth.max <- apply(depth, 1, max)
  sampdepth <- rowMeans(depth)
  
  u0 <- which(sampdepth.max == 0)
  u1 <- setdiff(which(sampdepth.max == 1 | sampdepth < sampdepth.thresh), u0)
  nmax0 <- length(u0)
  nmax1 <- length(u1)
  if (nmax0 > 0) {
   cat(nmax0, "samples with no calls (maximum depth = 0) removed:\n")
   print(data.frame(indnum = u0, seqID = seqID[u0]))
   }
  if (nmax1 > 0) {
   cat(nmax1, "additional samples with maximum depth of 1 and/or mean depth <", sampdepth.thresh, "removed:\n")
   print(data.frame(indnum = u1, seqID = seqID[u1]))
   }
  u0 <- union(u0, u1)
  if (length(u0) > 0) {
    alleles <- alleles[-u0, ]
    depth <- depth[-u0, ]
    sampdepth <- sampdepth[-u0]
    seqID <- seqID[-u0]
    nind <- nind - length(u0)
  }
  write.csv(data.frame(seqID = seqID), "seqID.csv", row.names = FALSE)
  if (gform == "uneak") AFrq <- genosin[[length(genosin)]]
  allelecounts <- colSums(alleles)
  RAcounts <- matrix(allelecounts, ncol = 2, byrow = TRUE)  # 1 row per SNP, ref and alt allele counts
  p <- RAcounts[, 1]/rowSums(RAcounts)  # p for ref allele - based on # reads, not on inferred # alleles
  acountmin <- 1
  acountmax <- max(rowSums(RAcounts))
  if(exists("genosin")) rm(genosin)
 }  #end GBS-specific

snpdepth <- colMeans(depth)
uremove <- which(p == 0 | p == 1 | is.nan(p) | snpdepth < snpdepth.thresh)
if (length(uremove) > 0) {
  cat(length(uremove), "SNPs with MAF=0 or depth <", snpdepth.thresh, "removed\n")
  p <- p[-uremove]
  nsnps <- length(p)
  depth <- depth[, -uremove]
  SNP_Names <- SNP_Names[-uremove]
  if (gform == "chip") {
   genon <- genon[, -uremove]
  } else {
    uremovea <- sort(c(2 * uremove, 2 * uremove - 1))  # allele positions
    RAcounts <- RAcounts[-uremove, ]
    alleles <- alleles[, -uremovea]
    allelecounts <- allelecounts[uremovea]
    if (gform == "uneak") AFrq <- AFrq[-uremove]
  }
 }

cat("Analysing", nind, "individuals and", nsnps, "SNPs\n")

if (!gform == "chip") {
  genon <- alleles[, seq(1, 2 * nsnps - 1, 2)]/depth
  uhet <- which(!genon^2 == genon)
  genon <- 2*genon
  genon[uhet] <- 1
  samples <- genon
  samples[uhet] <- 2* (sample.int(2, length(uhet), replace = TRUE) - 1)
  rm(uhet)
}
gc()

###### compare allele frequency estimates from allele counts and from genotype calls (& from input file, if uneak format)
pg <- colMeans(genon, na.rm = TRUE)/2  # allele freq assuming genotype calls
if(outlevel > 4) {
 png("AlleleFreq.png", width = 960, height = 960, pointsize = cex.pointsize *  18)
  p.lab <- "Allele frequency from allele counts"
  pg.lab <- "Allele frequency from genotype calls"
  AF.lab <- "Allele frequency given"
  if (gform == "uneak") pairs(cbind(pg, p, AFrq), col = "#80808020", pch = 16, cex = 0.8, labels = c(pg.lab, p.lab, AF.lab))
  if (gform != "uneak") plot(pg ~ p, col="#80808020", pch=16, cex=0.8, xlab=p.lab, ylab=pg.lab)
  dev.off()
 }

# calc some overall snp stats
naa <- colSums(genon == 2, na.rm = TRUE)
nab <- colSums(genon == 1, na.rm = TRUE)
nbb <- colSums(genon == 0, na.rm = TRUE)
n1 <- 2 * naa + nab
n2 <- nab + 2 * nbb
n <- n1 + n2  #n alleles
p1 <- n1/n
p2 <- 1 - p1
HWdis <- naa/(naa + nab + nbb) - p1 * p1
x2 <- (naa + nab + nbb) * HWdis^2/(p1^2 * p2^2)
LRT <- 2 * (n * log(n) + naa * log(pmax(1, naa)) + nab * log(pmax(1, nab)) + nbb * log(pmax(1, nbb)) - (n/2) * log(n/2) - n1 * log(n1) - n2 * 
             log(n2) - nab * log(2))  # n is # alleles = 2* n obs
maf <- ifelse(p1 > 0.5, p2, p1)
l10p <- -log10(exp(1)) * pchisq(x2, 1, lower.tail = FALSE, log.p = TRUE)
l10LRT <- -log10(exp(1)) * pchisq(LRT, 1, lower.tail = FALSE, log.p = TRUE)

sampdepth <- rowMeans(depth)  # recalc after removing SNPs and samples
if(outlevel > 4) sampdepth.med <- apply(depth, 1, median)
depth0 <- rowSums(depth == 0)
snpdepth <- colMeans(depth)
cat("Proportion of missing genotypes: ", sum(depth == 0)/nrow(depth)/ncol(depth), "\n")

callrate <- 1 - rowSums(depth == 0)/nsnps  # after removing SNPs, samples 
SNPcallrate <- 1 - colSums(depth == 0)/nind  
png("CallRate.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
 hist(callrate, 50, col = "cornflowerblue", border = "cornflowerblue", main = "Histogram of sample call rates", xlab = "Call rate (proportion of SNPs scored)")
 dev.off()
png("SNPCallRate.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
 # suggested by Jaroslav Klapste (Scion) 
 hist(SNPcallrate, 50, col = "cornflowerblue", border = "cornflowerblue", main = "Histogram of SNP call rates", xlab = "Call rate (proportion of samples scored)")
 dev.off()

if (gform == "chip") write.csv(data.frame(seqID, callrate), "SampleStats.csv", row.names = FALSE)
if (!gform == "chip") {
  write.csv(data.frame(seqID, callrate, sampdepth), "SampleStats.csv", row.names = FALSE)
  sampdepth.scored <- sampdepth * nsnps/(nsnps - depth0)
  cat("Mean sample depth:", mean(sampdepth), "\n")
  if(outlevel > 4) {
   png("SampDepth.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
    plot(sampdepth ~ sampdepth.med, col = "#80808080", pch = 16, cex = 1.2, main = "Sample Depth", xlab = "Median", ylab = "Mean")
    dev.off()
   }
  png("SampDepth-scored.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
   plot(sampdepth.scored ~ sampdepth, col = "#80808080", pch = 16, cex = 1.2, main = "Sample Depth", xlab = "Mean", ylab = "Mean with depth>0")
   dev.off()
  png("SampDepthHist.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
   hist(sampdepth, 100, col = "cornflowerblue", border = "cornflowerblue", main = "Histogram of mean sample depth", xlab = "Mean sample depth")
   dev.off()
  png("SampDepthCR.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
   plot(sampdepth ~ callrate, col = "#80808080", pch = 16, cex = 1.2, main = "Sample Depth v Call rate", xlab = "Sample call rate", ylab = "Mean sample depth")
   dev.off()
  png("SNPDepthHist.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
   hist(snpdepth, 100, col = "cornflowerblue", border = "cornflowerblue", main = "Histogram of mean SNP depth", xlab = "Mean SNP depth")
   dev.off()
  png("SNPDepth.png", width = 640, height = 640, pointsize = cex.pointsize * 15)
   plot(SNPcallrate ~ snpdepth, log="x", col = "#80808080", pch = 16, cex = 1, main = "SNP Depth", ylab = "SNP Call rate (proportion of samples scored)", 
        xlab = "Mean SNP depth (log scale)")
   dev.off()
}


# -----fin plot --------
finpalette <- colorRampPalette(c(rgb(200, 200, 200, max = 255), "blue"))(50)  # grey to blue (a possible alternative is finpalette <- terrain.colors(50))
depthtrans <- function(x) round(20 * log(-log(1/(x + 0.9)) + 1.05))  # to compress colour scale at higher depths
depthpoints <- c(0.5, 5, 50, 250)  # legend points
transpoints <- depthtrans(depthpoints)
mindepthplot <- 0.1
maxdepthplot <- 256
maxtrans <- depthtrans(maxdepthplot)
legend_image <- as.raster(matrix(rev(finpalette[1:maxtrans]), ncol = 1))
png("finplot.png", width = 960, height = 960, pointsize = cex.pointsize *  18)
plot(HWdis ~ maf, col = finpalette[depthtrans(pmax(mindepthplot, pmin(snpdepth, maxdepthplot)))], cex = 0.8, xlim = c(0, 0.5), xlab = "MAF", 
     ylab = "Hardy-Weinberg disequilibrium", cex.lab = 1.5)
rasterImage(legend_image, 0.05, -0.2, 0.07, -0.1)
text(x = 0.1, y = -0.2 + 0.1 * transpoints/maxtrans, labels = format(depthpoints))
text(x = 0.075, y = -0.075, labels = "SNP Depth", cex = 1.2)
dev.off()

if(outlevel > 4) {
 sigtrans <- function(x) round(sqrt(x) * 40/max(sqrt(x))) + 1  # to compress colour scale at higher LRT
 sigpoints <- c(0.5, 5, 50, 100)  # legend points
 transpoints <- sigtrans(sigpoints)
 maxtrans <- sigtrans(max(l10LRT))
 legend_image <- as.raster(matrix(rev(finpalette[1:maxtrans]), ncol = 1))
 png("HWdisMAFsig.png", width = 640, height = 640, pointsize = cex.pointsize *  15)
 plot(HWdis ~ maf, col = finpalette[sigtrans(l10LRT)], cex = 0.8, xlim = c(0, 0.5), xlab = "MAF", ylab = "Hardy-Weinberg disequilibrium", 
     cex.lab = 1.5)
 rasterImage(legend_image, 0.05, -0.2, 0.07, -0.1)
 text(x = 0.1, y = -0.2 + 0.1 * transpoints/maxtrans, labels = format(sigpoints))
 text(x = 0.075, y = -0.075, labels = "log10 LRT", cex = 1.2)
 dev.off()

 png("LRT-QQ.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
 qqplot(qchisq(ppoints(nsnps), df = 1), LRT, main = "Hardy-Weinberg LRT Q-Q Plot", xlab = parse(text = "Theoretical ~~ (chi[1]^2) ~~  Quantiles"), 
        ylab = "Sample Quantiles")
 dev.off()
 png("LRT-hist.png", width = 480, height = 480, pointsize = cex.pointsize * 12)
 hist(LRT, breaks = 50, col = "grey", xlab = "Hardy Weinberg likelihood ratio test statistic")
 dev.off()
}

png("MAF.png", pointsize = cex.pointsize * 12)
hist(maf, breaks = 50, xlab = "MAF", col = "grey")
dev.off()

depth.orig <- depth  # see next, but actually need original depths for plots, summaries etc
depth[depth < 2] <- 1.1  # not using depth values <2 after this so set to >1 to avoid 0 divisor note do not use depth.max <2 though
fcolo <- rep("black", nind)  # modify this to specify colours for individuals in the plots
} # !functions.only


################## functions
 depth2K <- function(depthvals)  1/2^depthvals   # convert depth to K value assuming binomial 

 depth2Kbb <- function(depthvals, alph=Inf) {
  # convert depth to K value assuming beta-binomial with parameters alpha=beta=alph. Inf gives binomial
  if (alph==Inf) 1/2^depthvals else beta(alph,depthvals+alph)/beta(alph,alph)
  }

# convert depth to K value modp model. prob of seeing same allele as last time is modp (usually >= 0.5)
 depth2Kmodp <- function(depthvals, modp=0.5 ) {
  Kvals <- 0.5*modp^(depthvals-1)
  Kvals[which(depthvals==0)] <- 1
  Kvals
  }

depth2Kchoose <- function(dmodel="bb",param) {  # function to choose redefine depth2K
 if (!dmodel=="modp") dmodel <- "bb"
 if (missing(param) & dmodel=="bb") param <- Inf
 if (missing(param) & dmodel=="modp") param <- 0.5
 if (dmodel=="bb") depth2K <- function(depthvals) depth2Kbb(depthvals,alph=param)
 if (dmodel=="modp") depth2K <- function(depthvals) depth2Kmodp(depthvals,modp=param)
 depth2K
 }


upper.vec <- function(sqMatrix) as.vector(sqMatrix[upper.tri(sqMatrix)])

posCreport <- function(mergeIDs,Guse,sfx = "") {
 csvout <- paste0("posCreport", sfx, ".csv")
 cat("Positive Control Checks (also see", csvout, ")\n")
 seqIDtemp <- seqID
 multiIDs <- unique(mergeIDs[which(duplicated(mergeIDs))])
 posCstats <- data.frame(mergeID=character(0),nresults=integer(0),selfrel=numeric(0),meanrel=numeric(0),minrel=numeric(0))
 sink(paste0("posCchecks",sfx,".txt"),split=TRUE)
 for (i in seq_along(multiIDs)) {
  thisID <- multiIDs[i]
  thispos <- which(mergeIDs==thisID)
  thisG <- Guse[thispos,thispos]
  selfrel <- mean(diag(thisG))
  meanrel <- mean(upper.vec(thisG))
  minrel <- min(upper.vec(thisG))
  posCstats <- rbind(posCstats, data.frame(mergeID=thisID,nresults=length(thispos),selfrel=selfrel,meanrel=meanrel,minrel=minrel))
  ulorel <- which(thisG <= hirel.thresh & upper.tri(thisG), arr.ind = TRUE)
  if (nrow(ulorel) > 0) print(data.frame(Indiv1 = seqIDtemp[thispos[ulorel[, 1]]], Indiv2 = seqIDtemp[thispos[ulorel[, 2]]], rel = thisG[ulorel]))
  }
 sink()
 write.csv(posCstats,file=csvout,row.names=FALSE,quote=FALSE)
 if(nrow(posCstats) > 0) {
  png(paste0("SelfRel",sfx,".png"), width = 960, height = 960, pointsize = cex.pointsize *  18)
   with(posCstats,plot(meanrel~selfrel,xlab="Mean within run",ylab="Mean between run",main="Self-relatedness"))
   abline(a=0,b=1,col="red")
   dev.off()
   }
 posCstats
 }

mergeSamples <- function(mergeIDs, indsubset) {  
 # doesn't do samples0, so cant do G3 
 if (missing(indsubset)) indsubset <- 1:nind
 mergeIDs <- mergeIDs[indsubset]
 aggr.msum <- rowsum(genon[indsubset,,drop=FALSE],mergeIDs,na.rm=TRUE)   # rowsum very fast
 aggr.mn <- rowsum(1 * !is.na(genon[indsubset,,drop=FALSE]),mergeIDs) 
 genon.m <- aggr.msum/aggr.mn
 genon.m[which(genon.m>0 & genon.m<0)] <- 1
 ID.m <- rownames(aggr.msum)
 depth.m <- rowsum(depth.orig[indsubset,,drop=FALSE],mergeIDs,na.rm=TRUE)
 nind.m <- nrow(genon.m)
 nseq <- rowsum(rep(1,length(indsubset)),mergeIDs) # results being merged
 seqID.m <- seqID[indsubset][match(ID.m,mergeIDs)]
 seqinfo <- read.table(text=seqID[indsubset][match(ID.m,mergeIDs)],sep="_",fill=TRUE,stringsAsFactors=FALSE)
 if(ncol(seqinfo)==5) { #Assume formated as ID_Flowcell_Lane_plate_X and return ID_merged_nsamples_0_X
  umerged <- which(nseq>1)
  seqinfo[umerged,2] <- "merged"
  seqinfo[umerged,3] <- nseq[umerged]
  seqinfo[umerged,4] <- 0
  seqID.m <- paste(seqinfo[,1],seqinfo[,2],seqinfo[,3],seqinfo[,4],seqinfo[,5],sep="_")
  }
 sampdepth.m <- rowMeans(depth.m)
 snpdepth.m <- colMeans(depth.m)
 pg.m <- colMeans(genon.m, na.rm = TRUE)/2  # allele freq assuming genotype calls
 list(mergeIDs=ID.m, nind=nind.m, seqID=seqID.m, genon=genon.m, depth.orig = depth.m, sampdepth=sampdepth.m, snpdepth=snpdepth.m, pg=pg.m, nmerged=nseq)
 }

calcp <- function(indsubset, pmethod="A") {
 if(!pmethod == "G") pmethod <- "A"
 if (missing(indsubset))   indsubset <- 1:nind
 if (pmethod == "A") {
  RAcountstemp <- matrix(colSums(alleles[indsubset,]), ncol = 2, byrow = TRUE)  # 1 row per SNP, ref and alt allele counts
  afreqs <- RAcountstemp[, 1]/rowSums(RAcountstemp)  # p for ref allele - based on # reads, not on inferred # alleles
  }
 if (pmethod == "G") afreqs <- colMeans(genon[indsubset,], na.rm = TRUE)/2  # allele freq assuming genotype calls
 afreqs
 }

calcG <- function(snpsubset, sfx = "", puse, indsubset, depth.min = 0, depth.max = Inf, npc = 0, calclevel = 9, cocall.thresh = 0) {
  # sfx is text to add to GGBS5 as graph name, puse is allele freqs (all snps) to use
  # calclevel: 1: G5 only, 2: G5 + reports using G5, 3: all G, 9: all
  if (missing(snpsubset))   snpsubset <- 1:nsnps
  if (missing(indsubset))   indsubset <- 1:nind
  if (missing(puse))        puse <- p
  nsnpsub <- length(snpsubset)
  nindsub <- length(indsubset)
  depthsub <- depth.orig[indsubset, snpsubset]
  cat("Calculating G matrix, analysis code:", sfx, "\n")
  cat("# SNPs: ", nsnpsub, "\n")
  cat("# individuals: ", nindsub, "\n")
  genon0 <- genon[indsubset, snpsubset]
  usegeno <- !is.na(genon[indsubset, snpsubset])
  if (depth.min > 1 | depth.max < Inf) {
    genon0[depth[indsubset, snpsubset] < depth.min] <- NA
    genon0[depth[indsubset, snpsubset] > depth.max] <- NA
    depthsub[depthsub < depth.min] <- 0
    depthsub[depthsub > depth.max] <- 0
    usegeno[depth[indsubset, snpsubset] < depth.min] <- FALSE
    usegeno[depth[indsubset, snpsubset] > depth.max] <- FALSE
    }
  cocall <- tcrossprod(usegeno)
  cat("Mean co-call rate (for sample pairs):", mean(upper.vec(cocall)/nsnpsub), "\n")
  cat("Min  co-call rate (for sample pairs):", min(upper.vec(cocall)/nsnpsub), "\n")
  png(paste0("Co-call-", sfx, ".png"), pointsize = cex.pointsize * 12)
   hist(upper.vec(cocall)/nsnpsub, breaks = 50, xlab = "Co-call rate (for sample pairs)", main="", col = "grey")
   dev.off()
  lowpairs <- which(cocall/nsnpsub <= cocall.thresh & upper.tri(cocall),arr.ind=TRUE)
  sampdepth.max <- apply(depthsub, 1, max)
  samp.removed <- NULL
  if(cocall.thresh >= 0) {  # remove samples which wont get self-rel
   samp.removed <- which(sampdepth.max < 2)
   lowpairs <- lowpairs[-(which(lowpairs[,1] %in% samp.removed | lowpairs[,2] %in% samp.removed)),,drop=FALSE]
   }   
  while(nrow(lowpairs) > 0) {
   lowsamptab <- table(as.vector(lowpairs))
   lowsamp <- as.numeric(names(which.max(lowsamptab)))
   samp.removed <- c(samp.removed,lowsamp)
   lowpairs <- lowpairs[-(which(lowpairs[,1] == lowsamp | lowpairs[,2] == lowsamp)),,drop=FALSE]
   }

  if ((nsnpsub < nsnps | depth.min > 1 | depth.max < Inf) & calclevel %in% c(2,9)) {
    naa <- colSums(genon0 == 2, na.rm = TRUE)
    nab <- colSums(genon0 == 1, na.rm = TRUE)
    nbb <- colSums(genon0 == 0, na.rm = TRUE)
    p1 = (naa + nab/2)/(naa + nab + nbb)
    maf <- ifelse(p1 > 0.5, 1 - p1, p1)
    png(paste0("MAF", sfx, ".png"), pointsize = cex.pointsize * 12)
    hist(maf, breaks = 50, xlab = "MAF", col = "grey")
    dev.off()
    }
  if (!gform == "chip" & calclevel > 2) {
   samples0 <- samples[indsubset, snpsubset] - rep.int(2 * puse[snpsubset], rep(nindsub, nsnpsub))
   samples0[is.na(genon0)] <- 0
   }
  genon0 <- genon0 - rep.int(2 * puse[snpsubset], rep(nindsub, nsnpsub))
  genon0[is.na(genon0)] <- 0     # equivalent to using 2p for missing genos
  
  sampdepthsub <- rowMeans(depthsub)
  # depth0sub <- rowSums(depthsub==0) snpdepthsub <- colMeans(depthsub) snpdepthsub.non0 <- colSums(depthsub>0)/nrow(depthsub)
  cat("Proportion of missing genotypes: ", sum(depthsub == 0)/nrow(depthsub)/ncol(depthsub), "\n")
  # callratesub <- 1-rowSums(depthsub==0)/nsnpsub
  cat("Mean sample depth:", mean(sampdepthsub), "\n")
  
  P0 <- matrix(puse[snpsubset], nrow = nindsub, ncol = nsnpsub, byrow = T)
  P1 <- 1 - P0
  P0[!usegeno] <- 0
  P1[!usegeno] <- 0
  div0 <- 2 * tcrossprod(P0, P1)
  
  if (!gform == "chip" & calclevel > 2) {
    GGBS3top <- tcrossprod(samples0)
    GGBS3bot <- (div0 + diag(diag(div0)))
    GGBS3 <- GGBS3top/GGBS3bot  # faster in 3 steps
  } else {
    GGBS3 <- NULL
  }
  
  GGBS4top <- tcrossprod(genon0)
  GGBS4 <- GGBS4top/div0
  GGBS1 <- GGBS4top/2/sum(puse[snpsubset] * (1 - puse[snpsubset]))  
  
  genon01 <- genon0
  genon01[depth[indsubset, snpsubset] < 2] <- 0
  P0 <- matrix(puse[snpsubset], nrow = nindsub, ncol = nsnpsub, byrow = T)
  P1 <- 1 - P0
  P0[!usegeno | depth[indsubset, snpsubset] < 2] <- 0
  P1[!usegeno | depth[indsubset, snpsubset] < 2] <- 0
  div0 <- 2 * tcrossprod(P0, P1)
#old (delete if new OK)  GGBS5d <- 1 + rowSums((genon01^2 - 2 * P0 * P1 * (1 + 2/2^depth[indsubset, snpsubset]))/(1 - 2/2^depth[indsubset, snpsubset]))/diag(div0)
  GGBS5d <- 1 + rowSums((genon01^2 - 2 * P0 * P1 * (1 + 2*depth2K(depth[indsubset, snpsubset])))/(1 - 2*depth2K(depth[indsubset, snpsubset])))/diag(div0)
  GGBS5 <- GGBS4
  diag(GGBS5) <- GGBS5d
  cat("Mean self-relatedness (G5 diagonal):", mean(GGBS5d), "\n")
  
  uhirel <- which(GGBS5 > hirel.thresh & upper.tri(GGBS5), arr.ind = TRUE)
  if (nrow(uhirel) > 0 & nsnpsub >= 999) 
    write.csv(data.frame(Indiv1 = seqID[uhirel[, 1]], Indiv2 = seqID[uhirel[, 2]], G5rel = GGBS5[uhirel]), paste0("HighRelatedness", sfx, ".csv"), row.names = FALSE)
  if (!npc == 0 ) {
   # check for missing elements and subset to remove
   pcasamps <- 1:nindsub
   if(length(samp.removed) > 0) {
    pcasamps <- pcasamps[-samp.removed]
    cat("SeqIDs removed for PCA and/or heatmap\n"); print(seqID[indsubset][samp.removed])
    }
   if (npc > 0) {
    png(paste0("Heatmap-G5", sfx, ".png"), width = 2000, height = 2000, pointsize = cex.pointsize *  18)
    temp <- sqrt(GGBS5[pcasamps,pcasamps] - min(GGBS5[pcasamps,pcasamps], na.rm = T))
    heatmap(temp, col = rev(heat.colors(50)))
    dev.off()
    }
   }
  if (calclevel %in% c(2,9)) {
   png(paste0("G", sfx, "-diag.png"), width = 480, height = 480, pointsize = cex.pointsize * 12)
    plot(diag(GGBS4) ~ diag(GGBS5), col = fcolo[indsubset], main = "Self-relatedness estimates", xlab = "Using G5", ylab = "Using G4")
    dev.off()
   }
  if (!gform == "chip") {
    png(paste0("G", sfx, "diagdepth.png"), width = 480, height = 480, pointsize = cex.pointsize * 12)
    plot(diag(GGBS5) ~ log(sampdepthsub + 1), col = fcolo[indsubset], ylab = "Self-relatedness estimate using G5", xlab = "Sample depth (log(x)+1)")
    dev.off()
  }
  if (calclevel %in% c(2,9)) {
   png(paste0("Gcompare", sfx, ".png"), width = 960, height = 960, pointsize = cex.pointsize *  18)
   if (gform == "chip") 
     plot(upper.vec(GGBS1) ~ upper.vec(GGBS5), col = "#80808060", pch = 16, main = "Off-diagonal comparisons", xlab = "Using G5", ylab = "Using G1")
   if (!gform == "chip" & calclevel > 2)  
     pairs(cbind(upper.vec(GGBS1), upper.vec(GGBS3), upper.vec(GGBS5)), col = "#80808060", pch = 16, main = "Off-diagonal comparisons", 
           labels = paste0("Using G", c("1", "3", "5")))
   dev.off()
   }
  npc <- abs(npc)
  if (npc >= 1) {
    ### PCA analysis on GGBS5
    PC <- svd(GGBS5[pcasamps,pcasamps] - matrix(colMeans(GGBS5[pcasamps,pcasamps]), nrow = length(pcasamps), ncol = length(pcasamps), byrow = TRUE), nu = npc)
    eval <- PC$d^2/sum(PC$d^2)
    PC$x <- PC$u %*% diag(PC$d[1:npc],nrow=npc)  # nrow to get correct behaviour when npc=1
    cat("minimum eigenvalue: ", min(eval), "\n")  #check for +ve def
    if (npc > 2) {
      pdf(paste0("PCG5", sfx, ".pdf"), pointsize = cex.pointsize * 12)
      pairs(PC$x[,1:npc], cex=0.6, label=paste(dimnames(PC$x)[[2]],round(eval,3),sep="\n")[1:npc], col=fcolo[indsubset])
      dev.off()
    }
    png(paste0("PC1v2G5", sfx, ".png"), width = 640, height = 640, pointsize = cex.pointsize *  15)
    if(npc > 1) {
      plot(PC$x[, 2] ~ PC$x[, 1], cex = 0.6, col = fcolo[indsubset], xlab = "Principal component 1", ylab = "Principal component 2")
      } else {
      hist(PC$x[, 1], 50)
      }
    dev.off()
    list(G1 = GGBS1, G4d = diag(GGBS4), G5 = GGBS5, samp.removed = samp.removed, PC = PC)  # add G3=GGBS3, if needed
  } else {
    list(G1 = GGBS1, G4d = diag(GGBS4), G5 = GGBS5, samp.removed = samp.removed)  # add G3=GGBS3, if needed
  }
}

# example calls Gfull <- calcG(npc=4) GHWdgm.05 <- calcG(which(HWdis > -0.05),'HWdgm.05') # recalculate using Hardy-Weinberg
# disequilibrium cut-off at -0.05
