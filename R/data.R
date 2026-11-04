#' Study area
#'
#' Polygon of the study area (Mexico City Metropolitan Area) used to crop the
#' predictors and the risk maps.
#'
#' @format An `sf` object with one feature (POLYGON, WGS 84) and the columns
#'   `id` and `geometry`.
"aoi"

#' Aedes aegypti ovitrap data, 2017-2024 (full database)
#'
#' Ovitrap presences and pseudo-absences used to fit the *Ae. aegypti* occurrence
#' models (primary scenario: no environmental filter on pseudo-absences, 2 km
#' buffer, no circular predictors). The `split` column records which rows belong
#' to the training and to the test partition (see [ae_aegypti_2017_2024_train] and
#' [ae_aegypti_2017_2024_test]).
#'
#' @format An `sf` object with one row per point and the columns:
#' \describe{
#'   \item{class}{Factor: `presence` or `pseudoabs`.}
#'   \item{built}{Built-up area probability (Dynamic World V1).}
#'   \item{tree}{Tree-cover probability (Dynamic World V1).}
#'   \item{ndvi}{NDVI (Sentinel-2, complemented with Landsat 8 for 2017).}
#'   \item{prcp}{Annual precipitation (MexHiResClimDB).}
#'   \item{ia}{CONAPO Accessibility Index, interpolated with SPDE-INLA.}
#'   \item{ice}{CONAPO Environmental Quality Index, interpolated with SPDE-INLA.}
#'   \item{im}{CONAPO Marginalization Index, interpolated with SPDE-INLA.}
#'   \item{pop}{Population (LandScan Global).}
#'   \item{hfp}{Human footprint.}
#'   \item{split}{Partition: `train` or `test`.}
#'   \item{geometry}{Point geometry (EPSG:4326).}
#' }
#' @details All predictors were harmonised to a common grid of about 500 m.
#'   The partition is 80/20, stratified by `class`, with `set.seed(12345)`
#'   (`rsample::initial_split(prop = 0.8, strata = class)`).
#' @source Ovitrap surveillance of the Mexican Ministry of Health (CENAPRECE);
#'   predictors as listed above.
"ae_aegypti_2017_2024"

#' Aedes aegypti training partition, 2017-2024
#'
#' The 80% of [ae_aegypti_2017_2024] used to train the models.
#'
#' @format An `sf` object with the same columns as [ae_aegypti_2017_2024]
#'   (except `split`).
#' @inherit ae_aegypti_2017_2024 details
"ae_aegypti_2017_2024_train"

#' Aedes aegypti test partition, 2017-2024
#'
#' The 20% of [ae_aegypti_2017_2024] held out to test the models.
#'
#' @format An `sf` object with the same columns as [ae_aegypti_2017_2024_train].
#' @inherit ae_aegypti_2017_2024 details
"ae_aegypti_2017_2024_test"

#' Aedes aegypti external validation data, 2025
#'
#' Ovitrap presences and pseudo-absences from 2025, not used to fit or tune the
#' models. Used for the external validation. Temperature and elevation, which
#' are not predictors of the primary scenario, are not included.
#'
#' @format An `sf` object with the same columns as [ae_aegypti_2017_2024_train].
"ae_aegypti_2025"
