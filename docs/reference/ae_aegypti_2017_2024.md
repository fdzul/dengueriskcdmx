# Aedes aegypti ovitrap data, 2017-2024 (full database)

Ovitrap presences and pseudo-absences used to fit the *Ae. aegypti*
occurrence models (primary scenario: no environmental filter on
pseudo-absences, 2 km buffer, no circular predictors). The `split`
column records which rows belong to the training and to the test
partition (see
[ae_aegypti_2017_2024_train](https://fdzul.github.io/dengueriskcdmx/reference/ae_aegypti_2017_2024_train.md)
and
[ae_aegypti_2017_2024_test](https://fdzul.github.io/dengueriskcdmx/reference/ae_aegypti_2017_2024_test.md)).

## Usage

``` r
ae_aegypti_2017_2024
```

## Format

An `sf` object with one row per point and the columns:

- class:

  Factor: `presence` or `pseudoabs`.

- built:

  Built-up area probability (Dynamic World V1).

- tree:

  Tree-cover probability (Dynamic World V1).

- ndvi:

  NDVI (Sentinel-2, complemented with Landsat 8 for 2017).

- prcp:

  Annual precipitation (MexHiResClimDB).

- ia:

  CONAPO Accessibility Index, interpolated with SPDE-INLA.

- ice:

  CONAPO Environmental Quality Index, interpolated with SPDE-INLA.

- im:

  CONAPO Marginalization Index, interpolated with SPDE-INLA.

- pop:

  Population (LandScan Global).

- hfp:

  Human footprint.

- split:

  Partition: `train` or `test`.

- geometry:

  Point geometry (EPSG:4326).

## Source

Ovitrap surveillance of the Mexican Ministry of Health (CENAPRECE);
predictors as listed above.

## Details

All predictors were harmonised to a common grid of about 500 m. The
partition is 80/20, stratified by `class`, with `set.seed(12345)`
(`rsample::initial_split(prop = 0.8, strata = class)`).
