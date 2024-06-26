# script: scr_baseline
# author: Serkan Korkmaz, serkor1@duck.com
# date: 2024-05-15
# objective: Generate Baseline table
# script start;

rm(list = ls()); invisible(gc()); devtools::load_all()


DT <- extract_data(
  DB_connection = DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = "inst/extdata/db.sqlite"
  ),
  table = "model1_baseline",
  k_disease = c("Epilepsi", "Undervægt/underernæring (blandt ældre)"),
  c_type    = "Prævalent"
)

DT <- prepare_data(
  DT = DT,
  recipe = recipe(
    treatment = list(
      k_disease = "Epilepsi"
    ),
    control   = list(
      k_disease = "Undervægt/underernæring (blandt ældre)"
    )
  )
)



total_obs <- aggregate_data(
  unique(DT[,.(v_obs = sum((v_obs))), by = .(k_allocator, k_assignment)])
  ,
  calc = expression(
    .(
      k_allocator       = "Total",
      v_characteristics = unique((v_obs))
    )
  ),
  by = c(
    "k_assignment"
  )
)

grouped_obs <- data.table::rbindlist(
  lapply(
    grep("^c", colnames(DT), value = TRUE),
    function(x) {

      aggregate_data(
        DT,
        calc = expression(
          .(

            v_characteristics = sum(unique(v_obs))
          )
        ),
        by = c(
          "k_assignment",
          "k_allocator" = x
        )
      )

    }
  )
)

grouped_vals <- aggregate_data(
  DT = DT,
  calc = expression(
    .(
      v_characteristics = round(
        weighted.mean(
          x     = v_characteristics,
          w     = v_weights,
          na.rm = TRUE
        ),
        digits = 2
      )
    )
  ),
  by =  c(
    "k_assignment",
    "k_allocator"
  )

)


DT_ <- merge(
  grouped_vals,
  grouped_obs,
  by = c("k_assignment", "k_allocator"),
  all.x = TRUE
)


data.table::rbindlist(
  list(
    total_obs,
    DT_
  ),
  fill = TRUE
)


# script end;
