# Risk Map of Dengue Transmission in the Metropolitan Area of Mexico City

``` r
library(dengueriskcdmx)
#> Loading required package: sf
#> Warning: package 'sf' was built under R version 4.6.1
#> Linking to GEOS 3.13.0, GDAL 3.8.5, PROJ 9.5.1; sf_use_s2() is TRUE
```

## Step 1. load the pkgs

``` r
library(sf)
library(mapgl)
library(terra)
library(tidyterra)
```

## Step 2. load the risk layer

``` r
risk <- dengueriskcdmx::ae_raster(layer = "risk") |>
    dplyr::select(risk)
```

## Step 3. load the area of interest layers

``` r
aoi  <- dengueriskcdmx::aoi
cdmx <- rgeomex::AGEM_inegi19_mx |>
    dplyr::filter(CVE_ENT == "09") |>
    dplyr::select(-NOMGEO)
```

## Step 4. create the risk table

``` r
# tabla de riesgo: área y población (Censo 2020, ITER)
tab <- data.frame(
    nivel    = c("Very High", "High", "Mid", "Low", "Very Low"),
    color    = c("#BD0026", "#FEB24C", "#FED976", "#6BAE6B", "#2C7A3E"),
    km2      = c(170.5, 676.9, 210.1, 161.6, 873.8),
    pct_area = c(8.1, 32.3, 10.0, 7.7, 41.8),
    hab_M    = c(2.69, 9.66, 2.06, 1.26, 4.09),
    pct_pob  = c(13.6, 48.9, 10.4, 6.4, 20.7))

filas <- paste0(
    "<tr><td style='padding:2px 6px;'><span style='display:inline-block;width:10px;height:10px;background:",
    tab$color, ";margin-right:5px;'></span>", tab$nivel, "</td>",
    "<td style='text-align:right;padding:2px 6px;'>", formatC(tab$km2, format = "f", digits = 1, big.mark = ","), "</td>",
    "<td style='text-align:right;padding:2px 6px;'>", tab$pct_area, "</td>",
    "<td style='text-align:right;padding:2px 6px;'>", formatC(tab$hab_M, format = "f", digits = 2), "</td>",
    "<td style='text-align:right;padding:2px 6px;'>", tab$pct_pob, "</td></tr>", collapse = "")

tabla_html <- paste0(
    "<details open style='background:rgba(255,255,255,0.92);padding:5px 7px;border-radius:6px;",
    "font-family:sans-serif;font-size:10px;box-shadow:0 1px 4px rgba(0,0,0,.3);'>",
    "<summary style='cursor:pointer;font-weight:bold;'>Risk: area and population</summary>",
    "<table style='border-collapse:collapse;margin-top:4px;'>",
    "<tr style='border-bottom:1px solid #999;'><th style='padding:1px 4px;text-align:left;'>Level</th>",
    "<th style='padding:1px 4px;'>km&sup2;</th><th style='padding:1px 4px;'>% area</th>",
    "<th style='padding:1px 4px;'>Pop. (M)</th><th style='padding:1px 4px;'>% pop.</th></tr>",
    filas,
    "<tr style='border-top:1px solid #999;'><td style='padding:1px 4px;'><b>Total</b></td>",
    "<td style='text-align:right;padding:1px 4px;'>2,092.9</td><td style='text-align:right;padding:1px 4px;'>100</td>",
    "<td style='text-align:right;padding:1px 4px;'>19.76</td><td style='text-align:right;padding:1px 4px;'>100</td></tr>",
    "</table><div style='font-size:8px;color:#555;margin-top:3px;'>Population: 2020 Census (INEGI, ITER)</div></details>")
```

## Step 5. risk map

``` r
# define the color and levels
colores_hex <- c("#BD0026", "#FEB24C", "#FED976", "#6BAE6B", "#2C7A3E")
niveles     <- c("Very High", "High", "Mid", "Low", "Very Low")
levels(risk) <- NULL
risk <- terra::mask(risk, mask = aoi)

# map
mapgl::maplibre_view(risk,
                     palette = grDevices::colorRampPalette(colores_hex)) |>
    mapgl::add_categorical_legend(legend_title = "Risk",
                                  values = niveles,
                                  colors = colores_hex,
                                  position = "bottom-left",
                                  draggable = TRUE) |>
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
    mapgl::add_scale_control() |>
    mapgl::add_control(html = tabla_html, position = "top-right")
```
