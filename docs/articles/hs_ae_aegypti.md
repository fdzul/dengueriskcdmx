# Habitat Suitability of Aedes aegypti

``` r
library(dengueriskcdmx)
#> Loading required package: sf
#> Warning: package 'sf' was built under R version 4.6.1
#> Linking to GEOS 3.13.0, GDAL 3.8.5, PROJ 9.5.1; sf_use_s2() is TRUE
```

## Step 1. load the pkgs

``` r
library(terra)
library(tidyterra)
library(mapgl)
```

## Step 2. load the aedes aegypti prediction layer

``` r
pred <- dengueriskcdmx::ae_raster(layer = "aedes")
```

## Step 3. load the area of interest layers

``` r
aoi <- dengueriskcdmx::aoi
cdmx <- rgeomex::AGEM_inegi19_mx |>
    dplyr::filter(CVE_ENT == "09") |>
    dplyr::select(-NOMGEO)
```

## Step 4. map the aedes aegypti prediction

``` r
mapgl::maplibre_view(pred, 
                     palette = viridis::turbo) |>
    mapgl::add_continuous_legend(legend_title = "Probability",
                                 position = "bottom-left",
                                 draggable = TRUE,
                                 values = c(0, 0.25, 0.50, 0.75, 1),
                                 colors = viridis::turbo(n = 10)) |>
    mapgl::add_source("aoi", aoi) |>
    mapgl::add_layer(id = "aoi_outline",
                     source = "aoi",
                     type = "line",
                     paint = list("line-color" = "blue",
                                  "line-width" = 1,
                                  "line-opacity" = 0.8)) |>
    mapgl::add_source("cdmx", cdmx) |>
    mapgl::add_layer(id = "cdmx_outline",
                     source = "cdmx",
                     type = "line",
                     paint = list("line-color" = "white",
                                  "line-width" = 0.5,
                                  "line-opacity" = 0.8)) |>
    mapgl::add_fullscreen_control(position = "top-left") |> 
    mapgl::add_navigation_control() |>
    mapgl::add_globe_control() |>
    mapgl::add_scale_control()
```
