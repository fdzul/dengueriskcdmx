# Path to a raster shipped with the package

Path to a raster shipped with the package

## Usage

``` r
ae_raster_path(layer = c("aedes", "dengue", "risk"))
```

## Arguments

- layer:

  One of `"aedes"` (probability of *Aedes aegypti* occurrence),
  `"dengue"` (probability of confirmed imported dengue cases) or
  `"risk"` (five-level epidemiological risk).

## Value

Character path to the GeoTIFF in `inst/extdata`.

## Examples

``` r
ae_raster_path("risk")
#> [1] "/private/var/folders/jn/bfwcn2ls0sdclpxn9r_gkbz00000gn/T/RtmpQT93Gr/temp_libpath4fa8326828d0/dengueriskcdmx/extdata/epidemiological_risk.tif"
```
