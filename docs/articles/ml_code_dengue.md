# Species Distribution Model of Confirmed Imported Dengue Cases in the Metropolitan Area of Mexico City using Machine Learning (2023-2024)

## 1 Objective

Predict the probability of the presence of confirmed imported dengue
cases in the Mexico City Metropolitan Area using Machine Learning

## 2 Load the pkg

Code

``` r
## R
library(tidyverse) 
library(magrittr) 
library(tidymodels) 
library(skimr) 
library(bonsai) 
## Balanceo
library(themis) 
library(parallel)
library(doParallel)
library(discrim)
library(kknn)
source("metrics_class.R")
load("dengue_2025_layers_sfa_2k.RData")
data_2025 <- data_lyr; rm(data_lyr)
data_2025 <- data_2025 |>
  dplyr::select(-temperatura,  -tmin, -elevation)
```

## 3 Load the dengue dataset and the area of interes

Code

``` r
# Step 1.1 load the dataset ####
load("dengue_2023_2024_layers_sfa_2k.RData")
data <- data_lyr; rm(data_lyr)
data <- data |>
  dplyr::select(-temperatura, -tmin, -elevation)
# Step 1.2 load the area of interes ####
load("aoi.RData")
aoi <- mzmv; rm(mzmv)
```

### 3.1 map of the study area and the dataset

Code

``` r
library(mapgl)
maplibre(style = carto_style("positron"),
         zoom = 10,        # Initial zoom level
  minZoom = 5,      # Prevent zooming out too far
  maxZoom = 18,
         bounds = data) |>
    add_circle_layer(id = "dengue",
                     source = data,
                     circle_color = match_expr(
                         column = "class",
                         values = c("presence", "pseudoabs"), # reemplaza por tus valores
                         stops = c("#E01A59", "#0F9D58")),
                     circle_stroke_color = "white", # color = "white"
                     circle_stroke_width = 1, # lwd = 0.5
                     circle_radius = 5) |>
    #    Capa 2 — polígono aoi (sin leyenda)
    add_fill_layer(id = "aoi",
                   source = aoi,
                   fill_color = "#ECB32D",
                   fill_opacity = 0.3, # ajusta al gusto
                   fill_outline_color = "black") |>
    add_line_layer(id           = "aoi-borde",
                   source       = aoi,      # misma fuente
                   line_color   = "black",  # color = "black"
                   line_width   = 2,        # lwd = 2
                   line_opacity = 1) |>
    add_categorical_legend(legend_title = "Dengue",
                           position = "bottom-left",
                           values = c("presence", "pseudoabs"), 
                           colors = c("#E01A59", "#0F9D58")) |>
    add_fullscreen_control(position = "top-left") |> 
    add_navigation_control()
```

## 4 Exploratory Data Analysis

### 4.1 glimpse of your data

Code

``` r
data |>
    dplyr::glimpse()
```

### 4.2 Univariate EDA

Code

``` r
# EDA Univariado ####
skimr::skim(data |> sf::st_drop_geometry())
```

Code

``` r
gtExtras::gt_plt_summary(data |> sf::st_drop_geometry())
```

### 4.3 Multivariate EDA

Code

``` r
library(corrplot)
library(ggplot2)
#library(dplyr)
data |>
    sf::st_drop_geometry() |>
  dplyr::select_if(is.numeric) |>
  cor() |>
  corrplot(method= "number", 
           type="upper",
           order="hclust", 
           tl.col="black")
```

![](corrmat_data_dengue_2023_2024_sfa.png)

Code

``` r
library(see) # for plotting
library(ggraph) # needs to be loaded

dat <- data |> 
    sf::st_drop_geometry() |>
    dplyr::select_if(is.numeric) 
plot(correlation::correlation(dat,
                              partial = TRUE)) +
    ggraph::scale_edge_color_continuous(low = "#E01A59", 
                                        high = "#0F9D58")
```

### 4.4 Response Variable

#### 4.4.1 Table

Code

``` r
# Balanceo
data |>
    sf::st_drop_geometry() |>
    dplyr::group_by(class) |> 
    dplyr::count(name = 'frec') |>
    dplyr::ungroup() |>
    dplyr::mutate( Porc= frec/sum(frec)) |>
    gt::gt()
```

#### 4.4.2 Graph

Code

``` r
data |>
    sf::st_drop_geometry() |>
    dplyr::group_by(class) |> 
    dplyr::count(name = 'frec') |>
    dplyr::ungroup() |>
    dplyr::mutate(Porc= frec/sum(frec)) |>
    ggplot2::ggplot(ggplot2::aes(x= class, 
                                 y= Porc)) +
    ggplot2::geom_segment(ggplot2::aes(xend = class, 
                                       y = 0, 
                                       yend=Porc), 
                          color= c("#0F9D58","#E01A59"), 
                          linewidth= 1) +
    ggplot2::geom_point(size=5, 
                        color= c("#0F9D58","#E01A59")) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(labels = scales::percent_format()) +
    ggplot2::labs(title= 'Porcentaje de Registros de casos de dengue', 
                  y = "Porcentaje", 
                  x = "") +
    ggplot2::theme_bw()
```

## 5 Modeling

### 5.1 Train-Test Split

Initial split

Code

``` r
# . Train-Test Split ####
set.seed(12345) # Semilla para aleatorios
split <- data |>
    rsample::initial_split(prop = 0.8, 
                           strata = class)
```

Train

Code

``` r
train <- rsample::training(split)
dim(train)
```

Test

Code

``` r
test <- rsample::testing(split)
dim(test)
```

### 5.2 Preprocessing

#### 5.2.1 Without Balance

Code

``` r
receta <- train |>
    sf::st_drop_geometry() |>
    #dplyr::select(class, dplyr::starts_with("bio")) |>
    recipes::recipe(class ~ . ) |>## Crea la receta 
    ## Eliminar variables que no usaremos
    # step_rm() |>
    ## Crear nuevas variables (insight desde el EDA)
    #recipes::step_mutate(temperature = temperature/1000) |>
    ## Imputar los datos 
    # step_impute_mean()
    recipes::step_impute_knn(recipes::all_predictors() ) |>
    ## Estandarizacion/Normalizacion de numericas
    recipes::step_normalize(recipes::all_numeric(),
                            -recipes::all_outcomes()) |>
    ## Crear una categoría "otros" que agrupe a categorias pequeñas
    recipes::step_other(recipes::all_nominal(), 
                        -recipes::all_outcomes() , 
                        threshold = 0.07, 
                        other = "otros") |>
    ## Crear una categoría "new" para observaciones con labels "no muestreados"
    recipes::step_novel(recipes::all_nominal(), 
                        -recipes::all_outcomes(), 
                        new_level = "new") |>
    ## Crear variables indicadoras para cada categoría
    recipes::step_dummy(recipes::all_nominal(), 
                        -recipes::all_outcomes()) |>
  #recipes::step_pca(recipes::all_numeric(), threshold = 0.8) |>
    ## Eliminar automáticamente variables con alta correlacion 
    ## para evitar la multicolinealidad xi ~ xj
    recipes::step_corr(recipes::all_numeric(),
                       -recipes::all_outcomes(), 
                       threshold = 0.80) |>
    recipes::step_nzv(all_predictors())
```

Code

``` r
receta 
receta  |>
    recipes::prep() |>
    recipes::bake(new_data = NULL) |>
    dplyr::glimpse()
```

#### 5.2.2 Balance using Upsampling

Code

``` r
receta_upsamping <- train |>
    sf::st_drop_geometry() |>
    #dplyr::select(class, dplyr::starts_with("bio")) |>
    recipes::recipe(class ~ . ) |>## Crea la receta 
    ## Eliminar variables que no usaremos
    # step_rm() |>
    ## Crear nuevas variables (insight desde el EDA)
    #recipes::step_mutate(temperature = temperature/1000) |>
    ## Imputar los datos 
    # step_impute_mean()
    recipes::step_impute_knn(recipes::all_predictors() ) |>
    ## Estandarizacion/Normalizacion de numericas
    recipes::step_normalize(recipes::all_numeric(),
                            -recipes::all_outcomes()) |>
    ## Crear una categoría "otros" que agrupe a categorias pequeñas
    recipes::step_other(recipes::all_nominal(), 
                        -recipes::all_outcomes() , 
                        threshold = 0.07, 
                        other = "otros") |>
    ## Crear una categoría "new" para observaciones con labels "no muestreados"
    recipes::step_novel(recipes::all_nominal(), 
                        -recipes::all_outcomes(), 
                        new_level = "new") |>
    ## Crear variables indicadoras para cada categoría
    recipes::step_dummy(recipes::all_nominal(), 
                        -recipes::all_outcomes()) |>
  #recipes::step_pca(recipes::all_numeric(), threshold = 0.8) |>
    ## Eliminar automáticamente variables con alta correlacion 
    ## para evitar la multicolinealidad xi ~ xj
    recipes::step_corr(recipes::all_numeric(),
                       -recipes::all_outcomes(), 
                       threshold = 0.80) |>
    recipes::step_nzv(all_predictors()) |> # near zero variance
    ## Balancear usando upsampling
    ## over_ratio implica que vamos a llevar a la clase minoritaria a 
    ## alrededor de 90% de filas que la mayoritaria
    themis::step_upsample(class, 
                          over_ratio= 0.90, 
                          skip= TRUE, 
                          seed = 345)
```

Code

``` r
receta_upsamping 

receta_upsamping  |>
    recipes::prep() |>
    recipes::bake(new_data = NULL) |>
    dplyr::glimpse()
```

#### 5.2.3 Balance with importance_weights

Code

``` r
# peso de las presencias = razon de clases del conjunto de entrenamiento
n_pres <- sum(train$class == "presence")
n_abs  <- sum(train$class == "pseudoabs")
w_pres <- n_abs / n_pres
w_pres

train_iw <- train |> 
    dplyr::mutate(## crear la variable con los pesos
        case_wts = ifelse(class == "presence", w_pres, 1),
        ## crea el vector de importancia ponderada
        case_wts = recipes::importance_weights(case_wts))
```

Code

``` r
receta_iw <- train_iw |>
  sf::st_drop_geometry() |>
  recipes::recipe(class ~ . ) |>## Crea la receta
  #recipes::step_indicate_na(urban, tree, ia) |>
    ## Eliminar variables que no usaremos
    # step_rm() |>
  
    ## Crear nuevas variables (insight desde el EDA)
    #recipes::step_mutate(temperature = temperature/1000) |>
    ## Imputar los datos 
    # step_impute_mean()
  recipes::step_impute_knn(recipes::all_predictors() ) |>
    ## Estandarizacion/Normalizacion de numericas
  recipes::step_normalize(recipes::all_numeric(), 
                             -recipes::all_outcomes()) |>
    ## Crear una categoría "otros" que agrupe a categorias pequeñas
  recipes::step_other(recipes::all_nominal(), 
                        -recipes::all_outcomes() , 
                        threshold = 0.07, 
                        other = "otros") |>
    ## Crear una categoría "new" para observaciones con labels "no muestreados"
  recipes::step_novel(recipes::all_nominal(), 
                        -recipes::all_outcomes() , 
                        new_level = "new") |>
  ## Crear variables indicadoras para cada categoría
    recipes::step_dummy(recipes::all_nominal(), 
                        -recipes::all_outcomes()) |>
  #recipes::step_pca(recipes::all_numeric(), threshold = 0.8) |>
    ## Crear variables indicadoras para cada categoría
    # recipes::step_dummy(all_nominal(), -all_outcomes() ) |># Dummy
    ## Eliminar automáticamente variables con alta correlacion 
    ## para evitar la multicolinealidad xi ~ xj
  recipes::step_corr(recipes::all_numeric(),
                       -recipes::all_outcomes(), 
                       threshold = 0.8) |>
  recipes::step_nzv(all_predictors())
    ## Tambien podemos eliminar variables con multicolinealidad "a mano"
    #recipes::step_rm(suhi_night, suhi_day,wordcover)
```

Code

``` r
receta_iw

receta_iw |>
    recipes::prep() |>
    recipes::bake(new_data = NULL) |>
    dplyr::glimpse()
```

### 5.3 Hyperparameter Optimization and Training

#### 5.3.1 Resamping (Cross Validation)

##### 5.3.1.1 upsampling

Code

``` r
set.seed(123456789)
library(tidysdm)
sp_block_cv  <- TRUE
if(sp_block_cv == TRUE){
  # Resampling with spatial block cross validation
cv <- spatialsample::spatial_block_cv(train,
                                      method = "random",
                                      repeats = 4,
                                      v = 5)
autoplot(cv) +
    ggplot2::geom_sf(data = aoi,
                     fill = NA,
                     col = "black",
                     lwd = 0.5)
} else{
  # # Resampling with stratify cross validation
cv <- rsample::vfold_cv(train |> sf::st_drop_geometry(), 
                        v = 5, 
                        repeats = 4, 
                        strata = class)
}
```

##### 5.3.1.2 Importancie Weigths

Code

``` r
set.seed(123456789)

library(tidysdm)
sp_block_cv  <- TRUE
if(sp_block_cv == TRUE){
  # Resampling with spatial block cross validation
cv_iw <- spatialsample::spatial_block_cv(train_iw,
                                      method = "random",
                                      repeats = 4,
                                      v = 5)
autoplot(cv_iw) +
    ggplot2::geom_sf(data = aoi,
                     fill = NA,
                     col = "black",
                     lwd = 0.5)
} else{
  # # Resampling with stratify cross validation
cv_iw <- rsample::vfold_cv(train_iw |> sf::st_drop_geometry(), 
                        v = 5, 
                        repeats = 4, 
                        strata = class)
}
```

#### 5.3.2 Metrics

Code

``` r
library(yardstick)
library(tidysdm)
metricas <- yardstick::metric_set(yardstick::sens, # 1a metrica: la que optimiza tune_bayes
                                  roc_auc,
                                  yardstick::spec,
                                  bal_accuracy,
                                  pr_auc, 
                                  accuracy, 
                                  boyce_cont, 
                                  tss_max, 
                                  kap)
metricas
```

#### 5.3.3 Activate Parallelization

Code

``` r
parallel::detectCores(logical=FALSE)

cl <- parallel::makePSOCKcluster(as.integer(Sys.getenv("N_CORES", "25")))
doParallel::registerDoParallel(cl)
```

### 5.4 Model specification

#### 5.4.1 Mexnet

Code

``` r
maxnet_ms <- tidysdm::maxent(feature_classes = tune::tune(),
                              regularization_multiplier = tune::tune())
```

#### 5.4.2 Logistic Regresion

Code

``` r
lr_ms <- parsnip::logistic_reg() |> 
  parsnip::set_engine("glm") |> 
  parsnip::set_mode("classification")
```

#### 5.4.3 Logistic Regresion With ElasticNet

Code

``` r
lre_ms <- parsnip::logistic_reg(penalty = tune(), 
                                 mixture = tune() ) |> 
  parsnip::set_engine("glmnet", 
             family = "binomial") |> 
  parsnip::set_mode("classification")
```

#### 5.4.4 Generalized Additive Model

Code

``` r
gam_ms <- parsnip::gen_additive_mod(select_features = FALSE,
                                     adjust_deg_free = tune::tune()) |>
  parsnip::set_engine("mgcv") |>
  parsnip::set_mode("classification")
```

#### 5.4.5 MARS

Code

``` r
mars_ms <- parsnip::mars(num_terms = tune(), 
                         prod_degree = tune(), 
                         prune_method= tune()) |>
  parsnip::set_engine("earth") |>
  parsnip::set_mode("classification")
```

#### 5.4.6 Naive Bayes

Code

``` r
nbay_ms <- parsnip::naive_Bayes(smoothness = tune::tune())  |>
  parsnip::set_engine("naivebayes") |>
  parsnip::set_mode("classification")
```

#### 5.4.7 K Nearest Neighbor

Code

``` r
knn_ms <- parsnip::nearest_neighbor(neighbors = tune(),
                                    weight_func = tune(),
                                    dist_power = tune()) |>
  parsnip::set_engine("kknn") |>
  parsnip::set_mode("classification")
```

#### 5.4.8 Decision Tree

Code

``` r
dt_ms <- parsnip::decision_tree(cost_complexity = parsnip::tune(),
                                tree_depth = parsnip::tune(),
                                min_n = parsnip::tune()) |>
  parsnip::set_engine("rpart") |>
  parsnip::set_mode("classification")

dt_ms
```

#### 5.4.9 Random Forest

https://www.tidymodels.org/find/parsnip/
https://parsnip.tidymodels.org//reference/details_rand_forest_ranger.html

Code

``` r
rf_ms <- parsnip::rand_forest(mtry = tune(), 
                              trees = tune(), 
                              min_n = tune() ) |>
    parsnip::set_engine("ranger", 
                        # opciones específicas del engine 
                        importance = "impurity") |>
    parsnip::set_mode("classification")

rf_ms
```

#### 5.4.10 LightGBM

Code

``` r
library(bonsai)
lgbm_ms <- parsnip::boost_tree(mtry = tune::tune(), 
                               trees = tune::tune(), 
                               tree_depth = tune::tune(),
                               loss_reduction = tune::tune(), 
                               learn_rate= tune::tune()) |>
    parsnip::set_engine("lightgbm") |>
    parsnip::set_mode("classification")
```

#### 5.4.11 XGBoost

Code

``` r
xgb_ms <- parsnip::boost_tree(mtry = tune::tune(), 
                              trees = tune::tune(), 
                              tree_depth = tune::tune(),
                              loss_reduction = tune::tune(), 
                              learn_rate= tune::tune()) |>
    parsnip::set_engine("xgboost",
                        nthread= 2) |>
    parsnip::set_mode("classification")
```

#### 5.4.12 Multilayer Perceptron (Neural Network)

Code

``` r
library(nnet)
mlp_ms <- parsnip::mlp(hidden_units = tune::tune(),
                       penalty = tune::tune(),
                       epochs = tune::tune()) |>
    parsnip::set_engine("nnet") |>
    parsnip::set_mode("classification")
```

### 5.5 Workflow

#### 5.5.1 Without data balancing

##### 5.5.1.1 MaxNet

Code

``` r
maxnet_wflow    <- workflows::workflow() |> 
  workflows::add_recipe(receta) |> 
  workflows::add_model(maxnet_ms)
```

##### 5.5.1.2 Logistic Regression

Code

``` r
lr_wflow    <- workflows::workflow() |> 
  workflows::add_recipe(receta) |> 
  workflows::add_model(lr_ms)
```

##### 5.5.1.3 Logistic Regresion With ElasticNet

Code

``` r
rle_wflow <- workflows::workflow() |>
    workflows::add_recipe(receta) |>
    workflows::add_model(lre_ms)
rle_wflow
```

##### 5.5.1.4 Generalized Additive Model

Code

``` r
pred_vars   <- recipes::prep(receta) |> 
  recipes::bake(new_data = NULL) |>
  dplyr::select(-class) |> 
  names()
gam_formula <- reformulate(paste0("s(", pred_vars, ", k = 3)"), 
                           response = "class")
gam_wflow <- workflows::workflow() |> 
  workflows::add_recipe(receta) |> 
  workflows::add_model(gam_ms, formula = gam_formula)
```

##### 5.5.1.5 MARS

Code

``` r
mars_wflow <- workflows::workflow() |>
    workflows::add_recipe(receta) |>
    workflows::add_model(mars_ms)
mars_wflow
```

##### 5.5.1.6 Naive Bayes

Code

``` r
nbay_wflow <- workflows::workflow() |>
    workflows::add_recipe(receta) |>
    workflows::add_model(nbay_ms)
nbay_wflow
```

##### 5.5.1.7 K Nearest Neighbor

Code

``` r
knn_wflow <- workflows::workflow() |>
    workflows::add_recipe(receta |> 
                              step_sample(size = 10000)) |>
    workflows::add_model(knn_ms)
knn_wflow
```

##### 5.5.1.8 Decision Tree

Code

``` r
dt_wflow <- workflows::workflow() |>
  workflows::add_recipe(receta) |>
  workflows::add_model(dt_ms) 
dt_wflow
```

##### 5.5.1.9 Random Forest

Code

``` r
rf_wflow <- workflows::workflow() |>
  workflows::add_recipe(receta) |>
  workflows::add_model(rf_ms) 
rf_wflow 
```

##### 5.5.1.10 LightGBM

Code

``` r
lgbm_wflow <- workflows::workflow() |>
    workflows::add_recipe(receta) |>
    workflows::add_model(lgbm_ms) 
lgbm_wflow
```

##### 5.5.1.11 XGBoost

Code

``` r
xgb_wflow <- workflows::workflow() |> 
    workflows::add_recipe(receta) |> 
    workflows::add_model(xgb_ms) 

xgb_wflow
```

##### 5.5.1.12 Multilayer Perceptron (Neural Network)

Code

``` r
mlp_wflow <- workflows::workflow() |>
    workflows::add_recipe(receta) |>
    workflows::add_model(mlp_ms)
mlp_wflow
```

#### 5.5.2 With data balancing

##### 5.5.2.1 MaxNet

Code

``` r
maxnet_wflow_up    <- workflows::workflow() |> 
  workflows::add_recipe(receta_upsamping) |> 
  workflows::add_model(maxnet_ms)
```

##### 5.5.2.2 Logistic Regresion

Code

``` r
lr_wflow_up    <- workflows::workflow() |> 
  workflows::add_recipe(receta_upsamping) |> 
  workflows::add_model(lr_ms)
```

##### 5.5.2.3 Logistic Regresion With ElasticNet

Code

``` r
rle_wflow_up <- workflows::workflow() |>
    workflows::add_recipe(receta_upsamping) |>
    workflows::add_model(lre_ms)
rle_wflow_up
```

##### 5.5.2.4 Generalized Additive Model

Code

``` r
pred_vars   <- recipes::prep(receta) |> 
  recipes::bake(new_data = NULL) |>
  dplyr::select(-class) |> 
  names()
gam_formula <- reformulate(paste0("s(", pred_vars, ", k = 3)"), 
                           response = "class")
gam_wflow_up <- workflows::workflow() |>
  workflows::add_recipe(receta_upsamping) |> 
  workflows::add_model(gam_ms, formula = gam_formula)
```

##### 5.5.2.5 MARS

Code

``` r
mars_wflow_up <- workflows::workflow() |>
    workflows::add_recipe(receta_upsamping) |>
    workflows::add_model(mars_ms)
mars_wflow_up
```

##### 5.5.2.6 Naive Bayes

Code

``` r
nbay_wflow_up <- workflows::workflow() |>
    workflows::add_recipe(receta_upsamping) |>
    workflows::add_model(nbay_ms)
nbay_wflow_up
```

##### 5.5.2.7 K Nearest Neighbor

Code

``` r
knn_wflow_up <- workflows::workflow() |>
    workflows::add_recipe(receta_upsamping |> 
                              step_sample(size = 10000)) |>
    workflows::add_model(knn_ms)
knn_wflow_up
```

##### 5.5.2.8 Decision Tree

Code

``` r
dt_wflow_iw <- workflows::workflow() |>
  workflows::add_recipe(receta_iw) |>
  workflows::add_model(dt_ms) |>
  workflows::add_case_weights(case_wts)
dt_wflow_iw
```

##### 5.5.2.9 Random Forest

Code

``` r
rf_wflow_iw <- workflows::workflow() |>
  workflows::add_recipe(receta_iw) |>
  workflows::add_model(rf_ms) |>
  workflows::add_case_weights(case_wts)
rf_wflow_iw 
```

##### 5.5.2.10 LightGBM

Code

``` r
lgbm_wflow_up <- workflows::workflow() |>
    workflows::add_recipe(receta_upsamping) |>
    workflows::add_model(lgbm_ms) 
lgbm_wflow_up
```

##### 5.5.2.11 XGBoost

Code

``` r
xgb_wflow_iw <- workflows::workflow() |> 
    workflows::add_recipe(receta_iw) |> 
    workflows::add_model(xgb_ms) |> 
    workflows::add_case_weights(case_wts) ## Aquí agregamos los pesos

xgb_wflow_iw 
```

##### 5.5.2.12 Multilayer Perceptron (Neural Network)

Code

``` r
mlp_wflow_up <- workflows::workflow() |>
    workflows::add_recipe(receta_upsamping) |>
    workflows::add_model(mlp_ms)
mlp_wflow_up
```

### 5.6 Hyperparameter tuning

#### 5.6.1 Search Grid

##### 5.6.1.1 MaxNet

Code

``` r
set.seed(12345789)
maxnet_grid <- maxnet_ms |>
  workflowsets::extract_parameter_set_dials() |>
  recipes::update(feature_classes = tidysdm::feature_classes(values = c("l",
                                                                        "lq",
                                                                        "lqp",
                                                                        "lqph",
                                                                        "lqpht")),
                  regularization_multiplier = tidysdm::regularization_multiplier(range = c(0.5,4))) |>
  dials::grid_space_filling(size = 100)
```

##### 5.6.1.2 Logistic Regresion

##### 5.6.1.3 Logistic Regresion with Elasticnet (LRE)

Code

``` r
set.seed(12345789)
lre_grid <- crossing(penalty = c(0.1, 0.01, 0.001),
                     mixture = c(0.1, 0.3, 0.6, 0.9))

lre_grid 
```

##### 5.6.1.4 Generalized Additive Model

Code

``` r
set.seed(12345789)
gam_grid <- gam_ms |>
  workflowsets::extract_parameter_set_dials() |>
  dials::grid_space_filling(size = 100)
```

##### 5.6.1.5 Multivariate Adaptative Regresion Splines (MARS)

Code

``` r
set.seed(12345789)
mars_grid <- tidyr::crossing(num_terms= 3:7, 
                             prod_degree= 1:2, 
                             prune_method= c('backward', 'forward'))


mars_grid 
```

##### 5.6.1.6 Naive Bayes

Code

``` r
set.seed(12345789)
library(discrim)
nbay_grid <- tibble::tibble(smoothness= seq(from = 0.5, to = 2, by = 0.1))

nbay_grid 
```

##### 5.6.1.7 K Nearest Neighbor

Code

``` r
set.seed(12345789)
knn_grid <- knn_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(weight_func = dials::weight_func(c("biweight",
                                                       "rectangular"))) |>
    dials::grid_space_filling(size = 100)

knn_grid 
```

##### 5.6.1.8 Decision Tree

Code

``` r
set.seed(12345789)
dt_grid <- dt_ms |>
  workflowsets::extract_parameter_set_dials() |>
  recipes::update(
                  #tree_depth = dials::tree_depth(range= c(1, 8)),
                  # 
                  #tree_depth= dials::tree_depth(range= c(3, 8)),
                  # porcentajes de un dígito (1% o 2% a 5%)
                  min_n = dials::min_n(range = c(3, 15))
                  ) |>
  dials::grid_space_filling(size = 100)
dt_grid
```

##### 5.6.1.9 Random Forest

Code

``` r
set.seed(12345789)
rf_grid <- rf_ms |>
  workflowsets::extract_parameter_set_dials() |>
  recipes::update(# porcentajes de las filas (0.5% min y 5% max)
                  min_n = dials::min_n(range =  c(3, 15)),
                  ## 18 columnas sqrt(10, 11) = 3 aprox 4, min = 3-1 = 2, max = 3 +3
                  mtry = dials::mtry(range = c(2, 6)),
                  ##
                  trees = dials::trees(range = c(100, 1000))) |>
  dials::grid_space_filling(size = 100)
rf_grid
```

##### 5.6.1.10 LightGBM

Code

``` r
set.seed(12345789)
lgbm_grid <- lgbm_ms |>
    ## preguntamos los parametros tuneables del modelo
    workflowsets::extract_parameter_set_dials() |>
    ## Vamos a definir un rango para el min_n y mtry
    recipes::update(
        ## 17 columnas sqrt(10, 11) = 4 aprox 4, min = 3-1 = 2, max = 3 +3
        mtry = dials::mtry(range= c(2, 6)),
        ## Cantidad de árboles en el proceso de boosting
        ### Cantidad de arboles (suele ser cantidades grandes)
        trees= dials::trees(range = c(100, 1000)),
        ## Profundidad de cada arbol
        tree_depth= dials::tree_depth(range= c(3, 6))
        ## Los otros hiperparam los dejamos por default
    ) |>
    ## En Boosting se suelen tener mallas grandes, porque estos modelos
    ## son muy sensibles a los hiperparametros y ademas tienen una 
    ## gran cantidad de hiperparametros
    #grid_latin_hypercube(size = 40)
    dials::grid_space_filling(size = 100)

lgbm_grid 
```

##### 5.6.1.11 XGBoost

Code

``` r
set.seed(12345)
xgb_grid <- xgb_ms |>
    ## preguntamos los parametros tuneables del modelo
    workflowsets::extract_parameter_set_dials() |>
    ## Vamos a definir un rango para el min_n y mtry
    recipes::update(
        ## 18 columnas sqrt(10, 11) = 3 aprox 4, min = 3-1, max = 3 +3
        mtry = dials::mtry(range= c(2, 6)),
        ## Cantidad de árboles en el proceso de boosting
        trees= dials::trees(range = c(100, 1000)),
        ## Profundidad de cada arbol
        tree_depth= dials::tree_depth(range= c(3, 6))
        ## Los otros hiperparam los dejamos por default
    ) |> 
    ## En Boosting se suelen tener mallas grandes, porque estos modelos
    ## son muy sensibles a los hiperparametros y ademas tienen una 
    ## gran cantidad de hiperparametros
    #grid_latin_hypercube(size = 40)
    dials::grid_space_filling(size = 100)

xgb_grid 
```

##### 5.6.1.12 Multilayer Perceptron (Neural Network)

Code

``` r
set.seed(12345789)
mlp_grid <- mlp_ms |>
    workflowsets::extract_parameter_set_dials() |>
    ## mismo rango que en el modelo de Ae. aegypti
    recipes::update(
        hidden_units = dials::hidden_units(range = c(1, 8)),
        penalty = dials::penalty(range = c(-4, 0)),
        epochs = dials::epochs(range = c(50, 300))
    ) |>
    dials::grid_space_filling(size = 100)

mlp_grid 
```

#### 5.6.2 Search Mesh Training with Cross Validation

##### 5.6.2.1 Without data balancing

###### 5.6.2.1.1 Maxnet

Code

``` r
maxnet_pset <- maxnet_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(
        feature_classes = tidysdm::feature_classes(values = c("l","lq",
                                                              "lqp",
                                                              "lqph","lqpht")),
        regularization_multiplier = tidysdm::regularization_multiplier(range = c(0.5, 4))
    )

tictoc::tic(); set.seed(12345)
maxnet_tuned <- tune::tune_bayes(maxnet_wflow, 
                                 resamples = cv, 
                                 param_info = maxnet_pset,
                                 initial = 15,
                                 iter = 25,
                                 metrics = metricas, 
                                 control = tune::control_bayes(allow_par = T, 
                                                               save_pred = T,
                                                               no_improve = 10, 
                                                               verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.2 Logistic Regresion

Code

``` r
tictoc::tic(); set.seed(12345)
#lr_res <- tune::tune_grid(lr_wflow, 
#                              resamples = cv, 
#                              metrics = metricas,
#                              control = tune::control_resamples(
#                                                                 save_pred = T))
lr_tuned <- tune::fit_resamples(lr_wflow, 
                              resamples = cv, 
                              metrics = metricas,
                              control = tune::control_resamples(save_pred = T))
tictoc::toc()
```

###### 5.6.2.1.3 Logistic Regresion ElasticNet

Code

``` r
## penalty en escala log10: 0.001-0.1 -> range log10 = c(-3, -1)
lre_pset <- dials::parameters(
    dials::penalty(range = c(-3, -1)),
    dials::mixture(range = c(0.1, 0.9))
)

tictoc::tic()
set.seed(12345)
lre_tuned <- tune::tune_bayes(rle_wflow, ## Modelo
                              resamples = cv, ## Crossvalidation
                              param_info = lre_pset, ## Espacio de búsqueda
                              initial = 15,
                              iter = 25,
                              metrics = metricas, ## Metricas
                              control = tune::control_bayes(allow_par = T, save_pred = T,
                                                            no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.4 Generalized Additive Model

Code

``` r
gam_pset <- gam_ms |>
    workflowsets::extract_parameter_set_dials()

tictoc::tic(); set.seed(12345)
gam_tuned <- tune::tune_bayes(gam_wflow, 
                              resamples = cv, 
                              param_info = gam_pset,
                              initial = 15,
                              iter = 25,
                              metrics = metricas, 
                              control = tune::control_bayes(allow_par = T, save_pred = T,
                                                            no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.5 Multivariate Adaptative Regresion Splines (MARS)

Code

``` r
mars_pset <- dials::parameters(
    dials::num_terms(range = c(3, 12)),
    dials::prod_degree(range = c(1, 2)),
    dials::prune_method(values = c('backward', 'forward'))
)

tictoc::tic()
set.seed(12345)
mars_tuned <- tune::tune_bayes(mars_wflow, ## Modelo
                               resamples = cv, ## Crossvalidation
                               param_info = mars_pset, ## Espacio de búsqueda
                               initial = 15,
                               iter = 25,
                               metrics = metricas, ## Metricas
                               control = tune::control_bayes(allow_par = T, save_pred = T,
                                                             no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.6 Naive Bayes

Code

``` r
#nbay_pset <- dials::parameters(dials::Laplace(range = c(0.5, 3)))
nbay_pset <- dials::parameters(dials::smoothness(range = c(0.5, 2)))
tictoc::tic()
set.seed(12345)
nbay_tuned <- tune::tune_bayes(nbay_wflow, ## Modelo
                               resamples = cv, ## Crossvalidation
                               param_info = nbay_pset, ## Espacio de búsqueda
                               initial = 15,
                               iter = 25,
                               metrics = metricas, ## Metricas
                               control = tune::control_bayes(allow_par = T, save_pred = T,
                                                             no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.7 K Nearest Neighbor

Code

``` r
knn_pset <- knn_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(weight_func = dials::weight_func(c("biweight", "rectangular")))

tictoc::tic()
set.seed(12345)
library(kknn)
knn_tuned <- tune::tune_bayes(knn_wflow, ## Modelo
                              resamples = cv, ## Crossvalidation
                              param_info = knn_pset, ## Espacio de búsqueda
                              initial = 15,
                              iter = 25,
                              metrics = metricas, ## Metricas
                              control = tune::control_bayes(allow_par = T, save_pred = T,
                                                            no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.8 Decision Tree

Code

``` r
dt_pset <- dt_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(min_n = dials::min_n(range = c(2, 15)))

tictoc::tic()
set.seed(12345)
dt_tuned <- tune::tune_bayes(dt_wflow, ## Modelo
                             resamples = cv, ## Crossvalidation
                             param_info = dt_pset, ## Espacio de búsqueda
                             initial = 15,
                             iter = 25,
                             metrics = metricas, ## Metricas
                             control = tune::control_bayes(allow_par = T, save_pred = T,
                                                           no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.9 Random Forest

Code

``` r
rf_pset <- rf_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(
        min_n = dials::min_n(range = c(2, 20)),
        mtry = dials::mtry(range = c(2, 6)),
        trees = dials::trees(range = c(100, 1000))
    )

tictoc::tic()
set.seed(12345)
rf_tuned <- tune::tune_bayes(rf_wflow, ## Modelo
                             resamples = cv, ## Crossvalidation
                             param_info = rf_pset, ## Espacio de búsqueda
                             initial = 15,
                             iter = 25,
                             metrics = metricas, ## Metricas
                             control = tune::control_bayes(allow_par = T, save_pred = T,
                                                           no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.10 LightGBM

Code

``` r
lgbm_pset <- lgbm_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(
        mtry = dials::mtry(range = c(2, 9)),
        trees = dials::trees(range = c(100, 1000)),
        tree_depth = dials::tree_depth(range = c(1, 8))
    )

tictoc::tic()
set.seed(12345)
lgbm_tuned <- tune::tune_bayes(lgbm_wflow, ## Modelo
                               resamples = cv, ## Crossvalidation
                               param_info = lgbm_pset, ## Espacio de búsqueda
                               initial = 15,
                               iter = 25,
                               metrics = metricas, ## Metricas
                               control = tune::control_bayes(allow_par = T, save_pred = T,
                                                             no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.11 XGBoost

Code

``` r
xgb_pset <- xgb_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(
        mtry = dials::mtry(range = c(2, 6)),
        trees = dials::trees(range = c(20, 1000)),
        tree_depth = dials::tree_depth(range = c(1, 6)),
        learn_rate = dials::learn_rate(range = c(-3, 0))
    )

tictoc::tic()
set.seed(12345)
xgb_tuned <- tune::tune_bayes(xgb_wflow, ## Modelo
                              resamples = cv, ## Crossvalidation
                              param_info = xgb_pset, ## Espacio de búsqueda
                              initial = 15,
                              iter = 25,
                              metrics = metricas, ## Metricas
                              control = tune::control_bayes(allow_par = T, save_pred = T,
                                                            no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.1.12 Multilayer Perceptron (Neural Network)

Code

``` r
## Espacio de búsqueda (mismo rango que mlp_grid, sin fijar la malla)
mlp_pset <- mlp_ms |>
    workflowsets::extract_parameter_set_dials() |>
    recipes::update(
        hidden_units = dials::hidden_units(range = c(1, 8)),
        penalty = dials::penalty(range = c(-4, 0)),
        epochs = dials::epochs(range = c(50, 300))
    )

tictoc::tic()
set.seed(12345)
mlp_tuned <- tune::tune_bayes(mlp_wflow, ## Modelo
                              resamples = cv, ## Crossvalidation
                              param_info = mlp_pset, ## Espacio de búsqueda
                              initial = 15, ## Puntos iniciales (space-filling)
                              iter = 25, ## Iteraciones de optimización bayesiana
                              metrics = metricas, ## Metricas
                              control = tune::control_bayes(allow_par = T,
                                                            save_pred = T,
                                                            no_improve = 10,
                                                            verbose = FALSE))
tictoc::toc()
```

##### 5.6.2.2 With data balancing

###### 5.6.2.2.1 Maxnet

Code

``` r
tictoc::tic(); set.seed(12345)
maxnet_tuned_wdb <- tune::tune_bayes(maxnet_wflow_up, 
                                     resamples = cv, 
                                     param_info = maxnet_pset,
                                     initial = 15,
                                     iter = 25,
                                     metrics = metricas, 
                                     control = tune::control_bayes(allow_par = T, save_pred = T,
                                                                   no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.2 Logistic Regresion

Code

``` r
tictoc::tic(); set.seed(12345)
lr_tuned_wdb <- tune::fit_resamples(lr_wflow_up, 
                                  resamples = cv,
                                  metrics = metricas,
                                  control = tune::control_resamples(save_pred = T))
tictoc::toc()
```

###### 5.6.2.2.3 Generalized Additive Model

Code

``` r
tictoc::tic(); set.seed(12345)
gam_tuned_wdb <- tune::tune_bayes(gam_wflow_up, 
                                  resamples = cv, 
                                  param_info = gam_pset,
                                  initial = 15,
                                  iter = 25,
                                  metrics = metricas, 
                                  control = tune::control_bayes(allow_par = T, save_pred = T,
                                                                no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.4 Logistic Regresion ElasticNet

Code

``` r
tictoc::tic()
set.seed(12345)
lre_tuned_wdb <- tune::tune_bayes(rle_wflow_up, ## Modelo
                                  resamples = cv, ## Crossvalidation
                                  param_info = lre_pset, ## mismo espacio de búsqueda
                                  initial = 15,
                                  iter = 25,
                                  metrics = metricas, ## Metricas
                                  control = tune::control_bayes(allow_par = T, save_pred = T,
                                                                no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.5 Multivariate Adaptative Regresion Splines (MARS)

Code

``` r
tictoc::tic()
set.seed(12345)
mars_tuned_wdb <- tune::tune_bayes(mars_wflow_up, ## Modelo
                                   resamples = cv, ## Crossvalidation
                                   param_info = mars_pset, ## mismo espacio de búsqueda
                                   initial = 15,
                                   iter = 25,
                                   metrics = metricas, ## Metricas
                                   control = tune::control_bayes(allow_par = T, save_pred = T,
                                                                 no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.6 Naive Bayes

Code

``` r
tictoc::tic()
set.seed(12345)
nbay_tuned_wdb <- tune::tune_bayes(nbay_wflow_up, ## Modelo
                                   resamples = cv, ## Crossvalidation
                                   param_info = nbay_pset, ## mismo espacio de búsqueda
                                   initial = 15,
                                   iter = 25,
                                   metrics = metricas, ## Metricas
                                   control = tune::control_bayes(allow_par = T, 
                                                                 save_pred = T,
                                                                 no_improve = 10, 
                                                                 verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.7 K Nearest Neighbor

Code

``` r
tictoc::tic()
set.seed(12345)
library(kknn)
knn_tuned_wdb <- tune::tune_bayes(knn_wflow_up, ## Modelo
                                  resamples = cv, ## Crossvalidation
                                  param_info = knn_pset, ## mismo espacio de búsqueda
                                  initial = 15,
                                  iter = 25,
                                  metrics = metricas, ## Metricas
                                  control = tune::control_bayes(allow_par = T, save_pred = T,
                                                                no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.8 Decision Tree

Code

``` r
tictoc::tic()
set.seed(12345)
dt_tuned_wdb <- tune::tune_bayes(dt_wflow_iw, ## Modelo
                                 resamples = cv_iw, ## Crossvalidation
                                 param_info = dt_pset, ## mismo espacio de búsqueda
                                 initial = 15,
                                 iter = 25,
                                 metrics = metricas, ## Metricas
                                 control = tune::control_bayes(allow_par = T, save_pred = T,
                                                               no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.9 Random Forest

Code

``` r
tictoc::tic()
set.seed(12345)
rf_tuned_wdb <- tune::tune_bayes(rf_wflow_iw, ## Modelo
                                 resamples = cv_iw, ## Crossvalidation
                                 param_info = rf_pset, ## mismo espacio de búsqueda
                                 initial = 15,
                                 iter = 25,
                                 metrics = metricas, ## Metricas
                                 control = tune::control_bayes(allow_par = T, save_pred = T,
                                                               no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.10 LightGBM

Code

``` r
tictoc::tic()
set.seed(12345)
lgbm_tuned_wdb <- tune::tune_bayes(lgbm_wflow_up, ## Modelo
                                   resamples = cv, ## Crossvalidation
                                   param_info = lgbm_pset, ## mismo espacio de búsqueda
                                   initial = 15,
                                   iter = 25,
                                   metrics = metricas, ## Metricas
                                   control = tune::control_bayes(allow_par = T, save_pred = T,
                                                                 no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.11 XGBoost

Code

``` r
tictoc::tic()
set.seed(12345)
xgb_tuned_wdb <- tune::tune_bayes(xgb_wflow_iw, ## Modelo
                                  resamples = cv_iw, ## Crossvalidation
                                  param_info = xgb_pset, ## mismo espacio de búsqueda
                                  initial = 15,
                                  iter = 25,
                                  metrics = metricas, ## Metricas
                                  control = tune::control_bayes(allow_par = T, save_pred = T,
                                                                no_improve = 10, verbose = FALSE))
tictoc::toc()
```

###### 5.6.2.2.12 Multilayer Perceptron (Neural Network)

Code

``` r
tictoc::tic()
set.seed(12345)
mlp_tuned_wdb <- tune::tune_bayes(mlp_wflow_up, ## Modelo
                                  resamples = cv, ## Crossvalidation
                                  param_info = mlp_pset, ## mismo espacio de búsqueda
                                  initial = 15, ## Puntos iniciales (space-filling)
                                  iter = 25, ## Iteraciones de optimización bayesiana
                                  metrics = metricas, ## Metricas
                                  control = tune::control_bayes(allow_par = T,
                                                                save_pred = T,
                                                                no_improve = 10,
                                                                verbose = FALSE))
tictoc::toc()
```

#### 5.6.3 Best Metrics

##### 5.6.3.1 MaxNet

Code

``` r
tune::show_best(maxnet_tuned, 
                metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(maxnet_tuned_wdb, 
                metric = 'spec', 
                n = 10)
```

##### 5.6.3.2 Logistic Regresion

Code

``` r
tune::show_best(lr_tuned)
```

Code

``` r
tune::show_best(lr_tuned_wdb)
```

##### 5.6.3.3 Logistic Regresion with ElasticNet

Code

``` r
tune::show_best(lre_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(lre_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.4 Generalized Additive Model

Code

``` r
tune::show_best(gam_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(gam_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.5 Multivariate Adaptative Regresion Spline

Code

``` r
tune::show_best(mars_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(mars_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.6 Naive Bayes

Code

``` r
tune::show_best(nbay_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(nbay_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.7 K Nearest Neighbor

Code

``` r
tune::show_best(knn_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(knn_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.8 Decision Tree

Code

``` r
tune::show_best(dt_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(dt_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.9 Random Forest

Code

``` r
tune::show_best(rf_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(rf_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.10 LightGBM

Code

``` r
tune::show_best(lgbm_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(lgbm_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.11 XGBoost

Code

``` r
tune::show_best(xgb_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(xgb_tuned_wdb, metric = 'spec', n = 10)
```

##### 5.6.3.12 Multilayer Perceptron (Neural Network)

Code

``` r
tune::show_best(mlp_tuned, metric = 'spec', n = 10)
```

Code

``` r
tune::show_best(mlp_tuned_wdb, metric = 'spec', n = 10)
```

## 6 Final Model

### 6.1 Defining the Best Hyperparameter Combination

In this workflow, the best hyperparameter combination was defined using
sensitivity, since the goal is to predict more accurately where
confirmed imported dengue cases occur.

#### 6.1.1 MaxNet

Code

``` r
maxnet_pars_fin <- tune::select_best(maxnet_tuned, 
                                   metric = "sens")
maxnet_pars_fin
```

Code

``` r
maxnet_pars_fin_wdb <- tune::select_best(maxnet_tuned_wdb, 
                                         metric = "sens")
maxnet_pars_fin_wdb
```

#### 6.1.2 Logistic Regresion

Code

``` r
lr_pars_fin <- tune::select_best(lr_tuned, 
                                   metric = "sens")
lr_pars_fin
```

Code

``` r
lr_pars_fin_wdb <- tune::select_best(lr_tuned_wdb, 
                                   metric = "sens")
lr_pars_fin_wdb
```

#### 6.1.3 Logistic Regresion ElasticNet

Code

``` r
lre_pars_fin <- tune::select_best(lre_tuned, 
                                   metric = "sens")
lre_pars_fin
```

Code

``` r
lre_pars_fin_wdb <- tune::select_best(lre_tuned_wdb, 
                                   metric = "sens")
lre_pars_fin_wdb
```

#### 6.1.4 Generalized Additive Model

Code

``` r
gam_pars_fin <- tune::select_best(gam_tuned, 
                                   metric = "sens")
gam_pars_fin
```

Code

``` r
gam_pars_fin_wdb <- tune::select_best(gam_tuned_wdb, 
                                   metric = "sens")
gam_pars_fin_wdb
```

#### 6.1.5 Multivariate Adaptative Regresion Splines (MARS)

Code

``` r
mars_pars_fin <- tune::select_best(mars_tuned, 
                                   metric = "sens")
mars_pars_fin
```

Code

``` r
mars_pars_fin_wdb <- tune::select_best(mars_tuned_wdb, 
                                   metric = "sens")
mars_pars_fin_wdb
```

#### 6.1.6 Naive Bayes

Code

``` r
nbay_pars_fin <- tune::select_best(nbay_tuned, 
                                   metric = "sens")
nbay_pars_fin
```

Code

``` r
nbay_pars_fin_wdb <- tune::select_best(nbay_tuned_wdb, 
                                   metric = "sens")
nbay_pars_fin_wdb
```

#### 6.1.7 K Nearest Neighbor

Code

``` r
knn_pars_fin <- tune::select_best(knn_tuned, 
                                   metric = "sens")
knn_pars_fin
```

Code

``` r
knn_pars_fin_wdb <- tune::select_best(knn_tuned_wdb, 
                                   metric = "sens")
knn_pars_fin_wdb
```

#### 6.1.8 Decision Tree

Code

``` r
dt_pars_fin <- tune::select_best(dt_tuned, 
                                 metric = "sens")
dt_pars_fin
```

Code

``` r
dt_pars_fin_wdb <- tune::select_best(dt_tuned_wdb, 
                                 metric = "sens")
dt_pars_fin_wdb
```

#### 6.1.9 Random Forest

Code

``` r
rf_pars_fin <- tune::select_best(rf_tuned, 
                                 metric = "sens")
rf_pars_fin
```

Code

``` r
rf_pars_fin_wdb <- tune::select_best(rf_tuned_wdb, 
                                     metric = "sens")
rf_pars_fin_wdb
```

#### 6.1.10 LightGBM

Code

``` r
lgbm_pars_fin <- tune::select_best(lgbm_tuned, 
                                   metric = "sens")
lgbm_pars_fin
```

Code

``` r
lgbm_pars_fin_wdb <- tune::select_best(lgbm_tuned_wdb, 
                                   metric = "sens")
lgbm_pars_fin_wdb
```

#### 6.1.11 XGBoost

Code

``` r
xgb_pars_fin <- tune::select_best(xgb_tuned, 
                                   metric = "sens")
xgb_pars_fin
```

Code

``` r
xgb_pars_fin_wdb <- tune::select_best(xgb_tuned_wdb, 
                                   metric = "sens")
xgb_pars_fin_wdb
```

#### 6.1.12 Multilayer Perceptron (Neural Network)

Code

``` r
mlp_pars_fin <- tune::select_best(mlp_tuned, 
                                   metric = "sens")
mlp_pars_fin
```

Code

``` r
mlp_pars_fin_wdb <- tune::select_best(mlp_tuned_wdb, 
                                   metric = "sens")
mlp_pars_fin_wdb
```

### 6.2 Finalize (assign values to tunable parameters) the workflow

#### 6.2.1 Maxnet

Code

``` r
maxnet_wflow_fin <- maxnet_wflow |>
    tune::finalize_workflow(maxnet_pars_fin)
maxnet_wflow_fin
```

Code

``` r
maxnet_wflow_fin_wdb <- maxnet_wflow_up |>
    tune::finalize_workflow(maxnet_pars_fin_wdb)
maxnet_wflow_fin_wdb
```

#### 6.2.2 Logistic Regresion

Code

``` r
lr_wflow_fin <- lr_wflow |>
    tune::finalize_workflow(lr_pars_fin)
lr_wflow_fin
```

Code

``` r
lr_wflow_fin_wdb <- lr_wflow_up |>
    tune::finalize_workflow(lr_pars_fin_wdb)
lr_wflow_fin_wdb
```

#### 6.2.3 Generalized Additive Model

Code

``` r
gam_wflow_fin <- gam_wflow |>
    tune::finalize_workflow(gam_pars_fin)
gam_wflow_fin
```

Code

``` r
gam_wflow_fin_wdb <- gam_wflow_up |>
    tune::finalize_workflow(gam_pars_fin_wdb)
gam_wflow_fin_wdb
```

#### 6.2.4 Logistic Regresion ElasticNet

Code

``` r
lre_wflow_fin <- rle_wflow |>
    tune::finalize_workflow(lre_pars_fin)
lre_wflow_fin
```

Code

``` r
lre_wflow_fin_wdb <- rle_wflow_up |>
    tune::finalize_workflow(lre_pars_fin_wdb)
lre_wflow_fin_wdb
```

#### 6.2.5 Multivariate Adaptative Regresion Splines (MARS)

Code

``` r
mars_wflow_fin <- mars_wflow |>
    tune::finalize_workflow(mars_pars_fin)
mars_wflow_fin
```

Code

``` r
mars_wflow_fin_wdb <- mars_wflow_up |>
    tune::finalize_workflow(mars_pars_fin_wdb)
mars_wflow_fin_wdb
```

#### 6.2.6 Naive Bayes

Code

``` r
nbay_wflow_fin <- nbay_wflow |>
    tune::finalize_workflow(nbay_pars_fin)
nbay_wflow_fin
```

Code

``` r
nbay_wflow_fin_wdb <- nbay_wflow_up |>
    tune::finalize_workflow(nbay_pars_fin_wdb)
nbay_wflow_fin_wdb
```

#### 6.2.7 K Nearest Neighbor

Code

``` r
knn_wflow_fin <- knn_wflow |>
    tune::finalize_workflow(knn_pars_fin)
knn_wflow_fin
```

Code

``` r
knn_wflow_fin_wdb <- knn_wflow_up |>
    tune::finalize_workflow(knn_pars_fin_wdb)
knn_wflow_fin_wdb
```

#### 6.2.8 Decision Tree

Code

``` r
dt_wflow_fin <- dt_wflow |>
    tune::finalize_workflow(dt_pars_fin)
dt_wflow_fin
```

Code

``` r
dt_wflow_fin_wdb <- dt_wflow_iw |>
    tune::finalize_workflow(dt_pars_fin_wdb)
dt_wflow_fin_wdb
```

#### 6.2.9 Random Forest

Code

``` r
rf_wflow_fin <- rf_wflow |>
    tune::finalize_workflow(rf_pars_fin)
rf_wflow_fin
```

Code

``` r
rf_wflow_fin_wdb <- rf_wflow_iw |>
    tune::finalize_workflow(rf_pars_fin_wdb)
rf_wflow_fin_wdb
```

#### 6.2.10 LightGBM

Code

``` r
lgbm_wflow_fin <- lgbm_wflow |>
    tune::finalize_workflow(lgbm_pars_fin)
lgbm_wflow_fin
```

Code

``` r
lgbm_wflow_fin_wdb <- lgbm_wflow_up |>
    tune::finalize_workflow(lgbm_pars_fin_wdb)
lgbm_wflow_fin_wdb
```

#### 6.2.11 XGBoost

Code

``` r
xgb_wflow_fin <- xgb_wflow |>
    tune::finalize_workflow(xgb_pars_fin)
xgb_wflow_fin
```

Code

``` r
xgb_wflow_fin_wdb <- xgb_wflow_iw |>
    tune::finalize_workflow(xgb_pars_fin_wdb)
xgb_wflow_fin_wdb
```

#### 6.2.12 Multilayer Perceptron (Neural Network)

Code

``` r
mlp_wflow_fin <- mlp_wflow |>
    tune::finalize_workflow(mlp_pars_fin)
mlp_wflow_fin
```

Code

``` r
mlp_wflow_fin_wdb <- mlp_wflow_up |>
    tune::finalize_workflow(mlp_pars_fin_wdb)
mlp_wflow_fin_wdb
```

### 6.3 Train the final model

#### 6.3.1 MaxNet

Code

``` r
maxnet_fitted <- fit(maxnet_wflow_fin, train)
maxnet_fitted
```

Code

``` r
maxnet_fitted_wdb <- fit(maxnet_wflow_fin_wdb, train)
maxnet_fitted_wdb
```

#### 6.3.2 Logistic Regresion

Code

``` r
lr_fitted <- fit(lr_wflow_fin, train)
lr_fitted
```

Code

``` r
lr_fitted_wdb <- fit(lr_wflow_fin_wdb, train)
lr_fitted_wdb
```

#### 6.3.3 Logistic Regresion ElasticNet

Code

``` r
lre_fitted <- fit(lre_wflow_fin, train)
lre_fitted
```

Code

``` r
lre_fitted_wdb <- fit(lre_wflow_fin_wdb, train)
lre_fitted_wdb
```

#### 6.3.4 Generalized Additive Model

Code

``` r
gam_fitted <- fit(gam_wflow_fin, train)
gam_fitted
```

Code

``` r
gam_fitted_wdb <- fit(gam_wflow_fin_wdb, train)
gam_fitted_wdb
```

#### 6.3.5 Multivariate Adaptative Regresion Splines (MARS)

Code

``` r
mars_fitted <- fit(mars_wflow_fin, train)
mars_fitted
```

Code

``` r
mars_fitted_wdb <- fit(mars_wflow_fin_wdb, train)
mars_fitted_wdb
```

#### 6.3.6 Naive Bayes

Code

``` r
nbay_fitted <- fit(nbay_wflow_fin, train)
nbay_fitted
```

Code

``` r
nbay_fitted_wdb <- fit(nbay_wflow_fin_wdb, train)
nbay_fitted_wdb
```

#### 6.3.7 K Nearest Neighbor

Code

``` r
knn_fitted <- fit(knn_wflow_fin, train)
knn_fitted
```

Code

``` r
knn_fitted_wdb <- fit(knn_wflow_fin_wdb, train)
knn_fitted_wdb
```

#### 6.3.8 Decision Tree

Code

``` r
dt_fitted <- fit(dt_wflow_fin, train_iw)
dt_fitted
```

Code

``` r
dt_fitted_wdb <- fit(dt_wflow_fin_wdb, train_iw)
dt_fitted_wdb
```

#### 6.3.9 Random Forest

Code

``` r
rf_fitted <- fit(rf_wflow_fin, train_iw)
rf_fitted
```

Code

``` r
rf_fitted_wdb <- fit(rf_wflow_fin_wdb, train_iw)
rf_fitted_wdb
```

#### 6.3.10 LightGBM

Code

``` r
lgbm_fitted <- fit(lgbm_wflow_fin, train)
lgbm_fitted
```

Code

``` r
lgbm_fitted_wdb <- fit(lgbm_wflow_fin_wdb, train)
lgbm_fitted_wdb
```

#### 6.3.11 XGBoost

Code

``` r
xgb_fitted <- fit(xgb_wflow_fin, train_iw)
xgb_fitted
```

Code

``` r
xgb_fitted_wdb <- fit(xgb_wflow_fin_wdb, train_iw)
xgb_fitted_wdb
```

#### 6.3.12 Multilayer Perceptron (Neural Network)

Code

``` r
mlp_fitted <- fit(mlp_wflow_fin, train)
mlp_fitted
```

Code

``` r
mlp_fitted_wdb <- fit(mlp_wflow_fin_wdb, train)
mlp_fitted_wdb
```

### 6.4 Evaluate the model

#### 6.4.1 MaxNet

##### 6.4.1.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              ml = maxnet_fitted,
              train = train,
              ml_title = "MaxNet",
              metrics_data = FALSE)
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = maxnet_fitted_wdb,
              train = train,
              ml_title = "Logistic Regresion ElasticNet (WDB)")
```

##### 6.4.1.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = maxnet_fitted,
              train = train,
              ml_title = "MaxNet 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test =  data_2025,
              metrics_data = FALSE,
              ml = maxnet_fitted_wdb,
              train = train,
              ml_title = "MaxNet 2023-2024 (WDB) versus 2025")
```

#### 6.4.2 Logistic Regresion

##### 6.4.2.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = lr_fitted,
              train = train,
              ml_title = "Logistic Regresion")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = lr_fitted_wdb,
              train = train,
              ml_title = "Logistic Regresion (WDB)")
```

##### 6.4.2.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = lr_fitted,
              train = train,
              ml_title = "Logistic Regresion 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = lr_fitted_wdb,
              train = train,
              ml_title = "Logistic Regresion 2023-2024 (WDB) versus 2025")
```

#### 6.4.3 Logistic Regresion ElasticNet

##### 6.4.3.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = lre_fitted,
              train = train,
              ml_title = "Logistic Regresion ElasticNet")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = lre_fitted_wdb,
              train = train,
              ml_title = "Logistic Regresion ElasticNet (WDB)")
```

##### 6.4.3.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = lre_fitted,
              train = train,
              ml_title = "LR ElasticNet 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = lre_fitted_wdb,
              train = train,
              ml_title = "LR ElasticNet 2023-2024 (WDB) versus 2025")
```

#### 6.4.4 Generalized Additive Model

##### 6.4.4.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = gam_fitted,
              train = train,
              ml_title = "Generalized Additive Model")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = gam_fitted_wdb,
              train = train,
              ml_title = " Generalized Additive Model (WDB)")
```

##### 6.4.4.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = gam_fitted,
              train = train,
              ml_title = "Generalized Additive Model 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = gam_fitted_wdb,
              train = train,
              ml_title = "Generalized Additive Model 2023-2024 (WDB) versus 2025")
```

#### 6.4.5 Multivariate Adaptative Regresion Splines (MARS)

##### 6.4.5.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = mars_fitted,
              train = train,
              ml_title = "Multivariate Adaptative Regresion Splines (MARS)")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = mars_fitted_wdb,
              train = train,
              ml_title = "Multivariate Adaptative Regresion Splines (MARS) WDB")
```

##### 6.4.5.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = mars_fitted,
              train = train,
              ml_title = "MARS 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = mars_fitted_wdb,
              train = train,
              ml_title = "MARS 2023-2024 (WDB) versus 2025")
```

#### 6.4.6 Naive Bayes

##### 6.4.6.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = nbay_fitted,
              train = train,
              ml_title = "Naive Bayes")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = nbay_fitted_wdb,
              train = train,
              ml_title = "Naive Bayes (wdb)")
```

##### 6.4.6.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = nbay_fitted,
              train = train,
              ml_title = "Naive Bayes 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = nbay_fitted_wdb,
              train = train,
              ml_title = "Naive Bayes 2023-2024 (WDB) versus 2025")
```

#### 6.4.7 K Nearest Neighbor

##### 6.4.7.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = knn_fitted,
              train = train,
              ml_title = "K Nearest Neighbor")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = knn_fitted_wdb,
              train = train,
              ml_title = "K Nearest Neighbor (wdb)")
```

##### 6.4.7.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = knn_fitted,
              train = train,
              ml_title = "K Nearest Neighbor 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = knn_fitted_wdb,
              train = train,
              ml_title = "K Nearest Neighbor 2023-2024 (WDB) versus 2025")
```

#### 6.4.8 Decision Tree

##### 6.4.8.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = dt_fitted,
              train = train_iw,
              ml_title = "Decision Tree")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = dt_fitted_wdb,
              train = train_iw,
              ml_title = "Decision Tree (wdb)")
```

##### 6.4.8.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = dt_fitted,
              train = train,
              ml_title = "Decision Tree 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = dt_fitted_wdb,
              train = train,
              ml_title = "Decision Tree 2023-2024 (WDB) versus 2025")
```

#### 6.4.9 Random Forest

##### 6.4.9.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = rf_fitted,
              train = train_iw,
              ml_title = "Random_Forest")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = rf_fitted_wdb,
              train = train_iw,
              ml_title = "Random_Forest (wdb)")
```

##### 6.4.9.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = rf_fitted,
              train = train,
              ml_title = "Random Forest 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = rf_fitted_wdb,
              train = train,
              ml_title = "Random Forest 2023-2024 (WDB) versus 2025")
```

#### 6.4.10 LightGBM

##### 6.4.10.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = lgbm_fitted,
              train = train,
              ml_title = "LigthGBM")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = lgbm_fitted_wdb,
              train = train,
              ml_title = "LigthGBM (wdb)")
```

##### 6.4.10.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = lgbm_fitted,
              train = train,
              ml_title = "LigthGBM 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = lgbm_fitted_wdb,
              train = train,
              ml_title = "LigthGBM 2023-2024 (WDB) versus 2025")
```

#### 6.4.11 XGBoost

##### 6.4.11.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = xgb_fitted,
              train = train_iw,
              ml_title = "XGBoost")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = xgb_fitted_wdb,
              train = train_iw,
              ml_title = "XGBoost (wdb)")
```

##### 6.4.11.2 External 2025

Code

``` r
library(magrittr)




metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = xgb_fitted,
              train = train,
              ml_title = "XGBoost 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = xgb_fitted_wdb,
              train = train,
              ml_title = "XGBoost 2023-2024 (WDB) versus 2025")
```

#### 6.4.12 Multilayer Perceptron (Neural Network)

##### 6.4.12.1 Internal

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = mlp_fitted,
              train = train,
              ml_title = "Multilayer Perceptron (Neural Network)")
```

Code

``` r
library(magrittr)


metrics_class(test = test,
              metrics_data = FALSE,
              ml = mlp_fitted_wdb,
              train = train,
              ml_title = "Multilayer Perceptron (Neural Network) (WDB)")
```

##### 6.4.12.2 External 2025

Code

``` r
library(magrittr)
metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = mlp_fitted,
              train = train,
              ml_title = "Neural Network 2023-2024 versus 2025")
```

Code

``` r
library(magrittr)


metrics_class(test = data_2025,
              metrics_data = FALSE,
              ml = mlp_fitted_wdb,
              train = train,
              ml_title = "Neural Network 2023-2024 (WDB) versus 2025")
```

### 6.5 Stop the parallelization

Code

``` r
parallel::stopCluster(cl)
```

## 7 Youden thresholds and fold metrics (out-of-fold)

Code

``` r
# Umbral de Youden por modelo con las predicciones fuera de muestra de la CV
# (nunca con 2025). Se calcula aqui porque los objetos *_tuned no se guardan.
youden_threshold <- function(tuned, pars_fin = NULL, pos = "presence", n_grid = 501) {
  preds <- if (is.null(pars_fin)) tune::collect_predictions(tuned) else
    tune::collect_predictions(tuned, parameters = pars_fin)
  prob <- preds[[paste0(".pred_", pos)]]
  y    <- as.integer(as.character(preds$class) == pos)
  grid <- unique(stats::quantile(prob, probs = seq(0, 1, length.out = n_grid), names = FALSE))
  j <- vapply(grid, function(th) {
    pred <- prob >= th
    mean(pred[y == 1]) + mean(!pred[y == 0]) - 1
  }, numeric(1))
  stats::median(grid[j >= max(j) - 1e-9])
}

metricas_cv_fold <- function(tuned, pars_fin = NULL, ml_title, threshold = NULL, pos = "presence") {
  preds <- if (is.null(pars_fin)) tune::collect_predictions(tuned) else
    tune::collect_predictions(tuned, parameters = pars_fin)
  id_cols <- intersect(c("id", "id2"), names(preds))
  preds |>
    dplyr::group_by(dplyr::across(dplyr::all_of(id_cols))) |>
    dplyr::group_modify(~ {
      prob <- .x[[paste0(".pred_", pos)]]
      y    <- as.character(.x$class) == pos
      auc  <- yardstick::roc_auc_vec(.x$class, prob, event_level = "first")
      s05  <- mean(prob[y] >= 0.5); e05 <- mean(prob[!y] < 0.5)
      out  <- tibble::tibble(.metric = c("auc", "sens_0.5", "spec_0.5", "TSS_0.5"),
                             .estimate = c(auc, s05, e05, s05 + e05 - 1))
      if (!is.null(threshold)) {
        sy <- mean(prob[y] >= threshold); ey <- mean(prob[!y] < threshold)
        out <- dplyr::bind_rows(out, tibble::tibble(
          .metric = c("sens_youden", "spec_youden", "TSS_youden"),
          .estimate = c(sy, ey, sy + ey - 1)))
      }
      out
    }) |>
    dplyr::ungroup() |>
    dplyr::mutate(modelo = ml_title, umbral = if (is.null(threshold)) NA_real_ else threshold)
}

tuned_models <- list(
  "MaxNet"                    = list(tuned = maxnet_tuned, pars = maxnet_pars_fin),
  "MaxNet (wdb)"              = list(tuned = maxnet_tuned_wdb, pars = maxnet_pars_fin_wdb),
  "Logistic Regression"       = list(tuned = lr_tuned, pars = NULL),
  "Logistic Regression (wdb)" = list(tuned = lr_tuned_wdb, pars = NULL),
  "LRE"                       = list(tuned = lre_tuned, pars = lre_pars_fin),
  "LRE (wdb)"                 = list(tuned = lre_tuned_wdb, pars = lre_pars_fin_wdb),
  "GAM"                       = list(tuned = gam_tuned, pars = gam_pars_fin),
  "GAM (wdb)"                 = list(tuned = gam_tuned_wdb, pars = gam_pars_fin_wdb),
  "MARS"                      = list(tuned = mars_tuned, pars = mars_pars_fin),
  "MARS (wdb)"                = list(tuned = mars_tuned_wdb, pars = mars_pars_fin_wdb),
  "Naive Bayes"               = list(tuned = nbay_tuned, pars = nbay_pars_fin),
  "Naive Bayes (wdb)"         = list(tuned = nbay_tuned_wdb, pars = nbay_pars_fin_wdb),
  "KNN"                       = list(tuned = knn_tuned, pars = knn_pars_fin),
  "KNN (wdb)"                 = list(tuned = knn_tuned_wdb, pars = knn_pars_fin_wdb),
  "Decision Tree"             = list(tuned = dt_tuned, pars = dt_pars_fin),
  "Decision Tree (wdb)"       = list(tuned = dt_tuned_wdb, pars = dt_pars_fin_wdb),
  "Random Forest"             = list(tuned = rf_tuned, pars = rf_pars_fin),
  "Random Forest (wdb)"       = list(tuned = rf_tuned_wdb, pars = rf_pars_fin_wdb),
  "LightGBM"                  = list(tuned = lgbm_tuned, pars = lgbm_pars_fin),
  "LightGBM (wdb)"            = list(tuned = lgbm_tuned_wdb, pars = lgbm_pars_fin_wdb),
  "XGBoost"                   = list(tuned = xgb_tuned, pars = xgb_pars_fin),
  "XGBoost (wdb)"             = list(tuned = xgb_tuned_wdb, pars = xgb_pars_fin_wdb),
  "MLP"                       = list(tuned = mlp_tuned, pars = mlp_pars_fin),
  "MLP (wdb)"                 = list(tuned = mlp_tuned_wdb, pars = mlp_pars_fin_wdb)
)

# Un modelo que falle no detiene al resto (queda NA)
umbrales <- purrr::map_dbl(tuned_models, function(x)
  tryCatch(youden_threshold(x$tuned, x$pars), error = function(e) NA_real_))
umbrales

metricas_cv_long <- purrr::imap_dfr(tuned_models, function(x, nombre)
  tryCatch(metricas_cv_fold(x$tuned, x$pars, nombre,
                            threshold = if (is.na(umbrales[[nombre]])) NULL else umbrales[[nombre]]),
           error = function(e) NULL))
```

## 8 Save the results

Code

``` r
save(train, test, train_iw, umbrales, metricas_cv_long,
     maxnet_fitted,
     maxnet_fitted_wdb,
     maxnet_pars_fin,
     maxnet_pars_fin_wdb,
     lr_fitted,
     lr_fitted_wdb,
     lre_fitted,
     lre_fitted_wdb,
     lre_pars_fin,
     lre_pars_fin_wdb,
     gam_fitted,
     gam_fitted_wdb,
     gam_pars_fin,
     gam_pars_fin_wdb,
     mars_fitted,
     mars_fitted_wdb,
     mars_pars_fin,
     mars_pars_fin_wdb,
     nbay_fitted,
     nbay_fitted_wdb,
     nbay_pars_fin, 
     nbay_pars_fin_wdb,
     knn_fitted_wdb,
     knn_fitted,
     knn_pars_fin,
     knn_pars_fin_wdb,
     dt_fitted,
     dt_fitted_wdb,
     dt_pars_fin,
     dt_pars_fin_wdb,
     rf_fitted,
     rf_fitted_wdb, rf_pars_fin_wdb, rf_pars_fin,
     lgbm_fitted,
     lgbm_fitted_wdb,
     lgbm_pars_fin,
     lgbm_pars_fin_wdb,
     xgb_fitted,
     xgb_fitted_wdb,
     xgb_pars_fin,
     xgb_pars_fin_wdb,
     mlp_fitted,
     mlp_fitted_wdb,
     mlp_pars_fin,
     mlp_pars_fin_wdb, 
     file = "enm_ml_dengue_2023_2024_tune_bayes_scv5_sfa_2k_sin_cir.RData")
```

Code

``` r
ensemble_models <- list(
  "MaxNet"                     = list(wflow = maxnet_wflow_fin,     data = train),
  "MaxNet (wdb)"                = list(wflow = maxnet_wflow_fin_wdb, data = train),
  "Logistic Regression"         = list(wflow = lr_wflow,             data = train),
  "Logistic Regression (wdb)"   = list(wflow = lr_wflow_up,          data = train),
  "LRE"                         = list(wflow = lre_wflow_fin,        data = train),
  "LRE (wdb)"                   = list(wflow = lre_wflow_fin_wdb,    data = train),
  "GAM"                         = list(wflow = gam_wflow_fin,        data = train),
  "GAM (wdb)"                   = list(wflow = gam_wflow_fin_wdb,    data = train),
  "MARS"                        = list(wflow = mars_wflow_fin,       data = train),
  "MARS (wdb)"                  = list(wflow = mars_wflow_fin_wdb,   data = train),
  "Naive Bayes"                 = list(wflow = nbay_wflow_fin,       data = train),
  "Naive Bayes (wdb)"           = list(wflow = nbay_wflow_fin_wdb,   data = train),
  "KNN"                         = list(wflow = knn_wflow_fin,        data = train),
  "KNN (wdb)"                   = list(wflow = knn_wflow_fin_wdb,    data = train),
  "Decision Tree"               = list(wflow = dt_wflow_fin,         data = train),
  "Decision Tree (wdb)"         = list(wflow = dt_wflow_fin_wdb,     data = train_iw),
  "Random Forest"               = list(wflow = rf_wflow_fin,         data = train),
  "Random Forest (wdb)"         = list(wflow = rf_wflow_fin_wdb,     data = train_iw),
  "LightGBM"                    = list(wflow = lgbm_wflow_fin,       data = train),
  "LightGBM (wdb)"              = list(wflow = lgbm_wflow_fin_wdb,   data = train),
  "XGBoost"                     = list(wflow = xgb_wflow_fin,        data = train),
  "XGBoost (wdb)"               = list(wflow = xgb_wflow_fin_wdb,    data = train_iw),
  "MLP"                         = list(wflow = mlp_wflow_fin,        data = train),
  "MLP (wdb)"                   = list(wflow = mlp_wflow_fin_wdb,    data = train)
)

save(ensemble_models,
     file = "ensemble_models_enm_ml_dengue_2023_2024_tune_bayes_scv5_sfa_2k_sin_cir.RData")
```

## 9 Session Info

Code

``` r
sessioninfo::session_info()
```
