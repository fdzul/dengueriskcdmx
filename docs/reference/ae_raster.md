# Read a raster shipped with the package

Read a raster shipped with the package

## Usage

``` r
ae_raster(layer = c("aedes", "dengue", "risk"))
```

## Arguments

- layer:

  One of `"aedes"` (probability of *Aedes aegypti* occurrence),
  `"dengue"` (probability of confirmed imported dengue cases) or
  `"risk"` (five-level epidemiological risk).

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
of about 500 m. `"aedes"` and `"dengue"` hold the probability (0-1), the
mean of the Random Forest, LightGBM and XGBoost models. `"risk"` has two
layers: `cluster` (k-means cluster) and `risk` (the five-level
epidemiological risk).

## Examples

``` r
if (FALSE) { # \dontrun{
terra::plot(ae_raster("aedes"))
} # }
```
