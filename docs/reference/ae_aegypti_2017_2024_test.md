# Aedes aegypti test partition, 2017-2024

The 20% of
[ae_aegypti_2017_2024](https://fdzul.github.io/dengueriskcdmx/reference/ae_aegypti_2017_2024.md)
held out to test the models.

## Usage

``` r
ae_aegypti_2017_2024_test
```

## Format

An `sf` object with the same columns as
[ae_aegypti_2017_2024_train](https://fdzul.github.io/dengueriskcdmx/reference/ae_aegypti_2017_2024_train.md).

## Details

All predictors were harmonised to a common grid of about 500 m. The
partition is 80/20, stratified by `class`, with `set.seed(12345)`
(`rsample::initial_split(prop = 0.8, strata = class)`).
