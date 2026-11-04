# Aedes aegypti training partition, 2017-2024

The 80% of
[ae_aegypti_2017_2024](https://fdzul.github.io/dengueriskcdmx/reference/ae_aegypti_2017_2024.md)
used to train the models.

## Usage

``` r
ae_aegypti_2017_2024_train
```

## Format

An `sf` object with the same columns as
[ae_aegypti_2017_2024](https://fdzul.github.io/dengueriskcdmx/reference/ae_aegypti_2017_2024.md)
(except `split`).

## Details

All predictors were harmonised to a common grid of about 500 m. The
partition is 80/20, stratified by `class`, with `set.seed(12345)`
(`rsample::initial_split(prop = 0.8, strata = class)`).
