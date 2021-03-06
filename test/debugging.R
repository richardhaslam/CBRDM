
if(!require(devtools)) install.packages("devtools")

devtools::install_local(path = "/media/huber/Elements/UNIBAS/software/codeR/package_CBRDM/CBRDM")
library(CBRDM)

para <- list(nF   = c(10, 3, 30),      # nF cross-beds
             rpos = c(0, 0.75, 1),     # 0 <= rpos <=1
             phi  = c(0, -1, 2.2))     # orientation angle
TF <- crossBedding(TF, para)




para <- list("L"      = list(type = "runif", min = 40, max = 70),
             "rLW"    = list(type = "runif", min = 3, max = 4),
             "rLH"    = list(type = "runif", min = 10, max = 20),
             "theta"  = list(type = "runif", min = -20 * pi / 180,
                             max = 20 * pi / 180),
             "rH"     = 2,
             "vpp"    = list(type = "poisson",
                             lambda = 0.1),
             "hpp"    = list(type = "strauss",
                             bet = 1e-4,
                             gam = 0.2,
                             d = 100,
                             fd = c(5, 1),
                             nit = 1000, n0 = 3),
             "nF"     = list(type = "rint", min = 2, max = 10),
             "rpos"   = list(type = "runif", min = 0.65, max = 1),
             "phi"    = list(type = "runif", min = -1.5, max = 1.5)
)

modbox <- list("x" = c(0,100),
               "y" = c(0,200),
               "z" = c(0,10)
)


mod <- sim(modbox, hmodel = "strauss", para)  # takes some times...

plotTopView(mod, border = "red", col = "grey", asp = 1)
lv <- c(1, 0,  -50)
lh <- c(0, 1,  -50)
l  <- c(1, 2, -250)
RConics::addLine(lv, col = "blue",  lwd = 3)
RConics::addLine(lh, col = "black", lwd = 4)
RConics::addLine(l,  col = "green", lwd = 4)


smod <- section(mod, l)
plotSection(smod, border = "red", col = "grey", asp = 2, ylim = c(0, 10),
            xlim = c(0,100), ylab = "z (m)", xlab = "x (m)")
title("Vertical section along 'lv' (blue line)")


slotNames(mod@layers[[1]]$obj@id)

class(mod@layers[[4]]$obj)

x <- NULL
i <- 0
while(is.null(x)){
  i <- i + 1
  y <- mod@layers[[i]]$obj
  x <- section(y, l)
}

plotTopView(y)
RConics::addLine(l,  col = "green", lwd = 4)
plotSection(x)

class(x)




mbox <- list(x = modbox$x, y = modbox$y, z = modbox$z,
             dx = 1,
             dy = 1,
             dz = 0.1)

PIX <- pixelise(mod, mbox)
FAC <- setProp(PIX$XYZ, type = c("facies"))

# horizontal section
plot3D::image2D(FAC[,, 50], x = PIX$x, y = PIX$y, asp = 1)
plot3D::image2D(FAC[which(PIX$x == 50.5),,], x = PIX$y, y = PIX$z,
                asp = 5)






# mod <- sim(modbox, hmodel = "strauss", para)  # takes some times...

sim <- function(modbox, hmodel = c("poisson", "strauss", "straussMH"), para,
                crossbeds = TRUE){
  hmodel <- match.arg(tolower(hmodel), c("poisson", "strauss"))
  #--- 1. vertical distribution layers: Poisson process
  dz <- diff(modbox$z)
  lambdaz <- dz/para$vpp$lambda
  nZ <- rpois(1, lambdaz)
  zLevel <- sort(modbox$z[1] + dz*runif(nZ))
  #--- 2. horizontal distribution scour fill: Poisson|Strauss model
  L   <- .rsim(para$L,   n = 500)
  rLW <- .rsim(para$rLW, n = 500)
  rLH <- .rsim(para$rLH, n = 500)
  W <- L/rLW
  # position
  maxL <- max(L, W) * 1.5
  modboxXL <- modbox
  modboxXL$x <- c(modbox$x[1]  - maxL, modbox$x[2]  + maxL)
  modboxXL$y <- c(modbox$y[1]  - maxL, modbox$y[2]  + maxL)
  if(hmodel == "poisson"){
    # number of objects is Poisson distributed
    lays <- Map(function(zl, id){
      .simLayPois(zl, id, para = para, modbox = modbox,
                  modboxXL = modboxXL)
    }, zLevel, seq_along(zLevel))
  }else if(hmodel == "strauss"){
    lays <- Map(function(zl, id){
      .simLayStrauss(zl, id, para , modbox ,
                     modboxXL )
    }, zLevel, seq_along(zLevel))
  }
  x <- new("Deposits",
           version = "0.1",
           id = 1L,
           layers  = lays,
           bbox = modbox
  )
  if(isTRUE(crossbeds)){
    x <- crossBedding(x, para)
  }
  return(x)
}





































x <- TF
n <- length(x@id)
if(is.null(para)){
  nF   <- rep(6, n)
  rpos <- rep(0.75, n)
  phi  <- rep(2.2, n)
}else{
  nF <- para$nF         #round(x@W / .rsim(para$nF, n)) +1
  if(length(nF) == 1){
    nF <- rep(nF, n)
  }else{
    nF <- .rsim(para$nF, n)
  }
  x <- para$nF
  function (x, n = 1)
  {
    arg <- x[-1]
    arg[["n"]] <- n
    return(do.call(x$type, arg))
  }

  rpos <- para$rpos     #.rsim(para$rpos, n)
  if(length(rpos) == 1){
    rpos <- rep(rpos, n)
  }else{
    rpos <- .rsim(para$rpos, n)
  }
  phi  <- para$phi      #.rsim(para$phi, n)
  if(length(phi) == 1){
    phi <- rep(phi, n)
  }else{
    phi <- .rsim(para$phi, n)
  }
}
xbed <- list()
for( i in seq_len(n)){
  xbed[[x@id[i]]] <- .regCrossBedding(x[i], nF = nF[i],
                                      rpos = rpos[i], phi = phi[i])
}
x@fill <- xbed
