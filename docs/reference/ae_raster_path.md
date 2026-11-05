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
#> [1] "/private/var/folders/jn/bfwcn2ls0sdclpxn9r_gkbz00000gn/T/RtmpSfaQWI/temp_libpath615e5d4228b3/dengueriskcdmx/extdata/epidemiological_risk.tif"
```
