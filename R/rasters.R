#' Path to a raster shipped with the package
#'
#' @param layer One of `"aedes"` (probability of *Aedes aegypti* occurrence),
#'   `"dengue"` (probability of confirmed imported dengue cases) or `"risk"`
#'   (five-level epidemiological risk).
#' @return Character path to the GeoTIFF in `inst/extdata`.
#' @examples
#' ae_raster_path("risk")
#' @export
ae_raster_path <- function(layer = c("aedes", "dengue", "risk")) {
  layer <- match.arg(layer)
  f <- c(aedes  = "ae_aegypti_probability.tif",
         dengue = "dengue_probability.tif",
         risk   = "epidemiological_risk.tif")[[layer]]
  p <- system.file("extdata", f, package = "dengueriskcdmx")
  if (!nzchar(p)) stop("file not found in the installed package: ", f)
  p
}

#' Read a raster shipped with the package
#'
#' @inheritParams ae_raster_path
#' @return A [terra::SpatRaster] of about 500 m. `"aedes"` and `"dengue"` hold
#'   the probability (0-1), the mean of the Random Forest, LightGBM and XGBoost
#'   models. `"risk"` has two layers: `cluster` (k-means cluster) and `risk` (the five-level epidemiological risk).
#' @examples
#' \dontrun{
#' terra::plot(ae_raster("aedes"))
#' }
#' @export
ae_raster <- function(layer = c("aedes", "dengue", "risk")) {
  if (!requireNamespace("terra", quietly = TRUE))
    stop("Package 'terra' is required to read the rasters.")
  terra::rast(ae_raster_path(layer))
}
