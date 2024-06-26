#' model2 UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_model2_ui <- function(id){
  ns <- NS(id)
  tagList(

    bslib::layout_columns(
      col_widths = 12,
      row_heights = c("auto", "auto"),
      min_height = "100%",
      bslib::layout_columns(
        col_widths = c(4,8),

        # 1) Parameter-card
        card(

          header = list(
            title = span(bsicons::bs_icon(name = "gear"), "Parametre"),
            content =list(
              bslib::popover(
                id = ns("choice_popover"),
                trigger = span(bsicons::bs_icon("gear"), "Menu"),
                options = list(
                  popoverMaxWidth = "400px"
                ),
                title = span(bsicons::bs_icon("gear"), "Menu"),

                bslib::layout_columns(
                  col_widths = 12,
                  shiny::sliderInput(
                    inputId = ns("effect"),
                    label   = "Sygedage",
                    width   = "300px",
                    value   = 1,
                    min     = 1,
                    max     = 28
                  ),

                  shinyWidgets::downloadBttn(
                    outputId = ns("downloader"),
                    label = "Eksporter",
                    size = "s",
                    style = "simple",
                    color = "primary"

                  )
                )

              )
            )
          ),

          bslib::card_body(
            picker_input(
              inputid = ns("k_sector"),
              label   = "Aldersgruppe",
              choices = model2_parameters$k_sector,
              multiple = TRUE,
              selected = model2_parameters$k_sector,
              search = TRUE,
              placeholder_text = "Intet valgt"

            ),
            picker_input(
              inputid = ns("k_education"),
              label   = "Udannelsesniveau",
              choices = model2_parameters$k_education,
              multiple = TRUE,
              selected = model2_parameters$k_education,
              search = FALSE,
              placeholder_text = "Intet valgt"

            ),

            picker_input(
              inputid = ns("k_allocator"),
              label   = "Hvem tager sygedagen?",
              choices = model2_parameters$k_allocator,
              multiple = TRUE,
              selected = model2_parameters$k_allocator,
              search = FALSE,
              placeholder_text = "Intet valgt"

            )

          )


        ),

        # 2) table-card
        # for the tabular output
        card(
          header = list(
            title = span(bsicons::bs_icon("table"), "Resultater"),
            content = list(
              tooltip(
                msg = c(
                  "Viser resultaterne i Tableform. Samme som forneden"
                )
              )
            )
          ),
          DT::dataTableOutput(
            outputId = ns("table")
          )

        )
      ),


      # 3) plot-card
      # for the plotly output
      # 2) table-card
      # for the tabular output
      card(
        header = list(
          title = span(bsicons::bs_icon("table"), "Resultater"),
          content = list(
            tooltip(
              msg = c(
                "Viser resultaterne i Tableform. Samme som forneden"
              )
            )
          )
        ),
        plotly::plotlyOutput(
          outputId = ns("plot")
        )
      )

    )


  )
}

#' model2 Server Functions
#'
#' @noRd
mod_model2_server <- function(id, theme){
  moduleServer( id, function(input, output, session){
    ns <- session$ns

    # 1) Extract base
    # data
    DT <- reactive(
      {

        extract_data(
          DB_connection = DB_connection,
          table         = "model2"
        )

      }
    )


    # 1) Aggregate the
    # data
    DT_aggregate <- reactive(
      {

        # 1) filter data
        # accordingly
        DT <- DT()[
          k_allocator %chin% input$k_allocator &
            k_education %chin% input$k_education &
            k_sector %chin% input$k_sector
        ]

        DT <- DT[
          ,
          .(
            v_cost = round(sum(
              v_cost,
              na.rm = TRUE
            )/sum(v_weight, na.rm = TRUE)
            ) * input$effect)
          ,
          by = .(
            k_sector,
            k_allocator
          )
        ]

        DT[
          ,
          k_allocator := data.table::fcase(
            default = "Delt",
            k_allocator %chin% 'low', "Lavest Uddannede",
            k_allocator %chin% "high", "Højest Uddannede"
          )
          ,
        ]


        return(
          DT
        )

      }
    )


    output$downloader <- shiny::downloadHandler(
      filename = function() {
        paste('workbook.xlsx', sep="")
      },
      content = function(file) {

        # 1) start download indicator
        # after user clicks downlaod
        showNotification(
          ui = shiny::span(bsicons::bs_icon("download"), "Downloader..."),
          action = NULL,
          duration = NULL,
          closeButton = FALSE,
          id = "download_indicator",
          type = c("default"),
          session = getDefaultReactiveDomain()
        )


        wb <- create_workbook(
          DT = DT_aggregate()
        )


        openxlsx::saveWorkbook(
          wb = wb,
          file = file,
          overwrite = TRUE
        )




        # 6) Close notification
        removeNotification("download_indicator", session = getDefaultReactiveDomain())




      }
    )


    output$table <- DT::renderDataTable(
      {

        table_DT <- data.table::dcast(
          data = DT_aggregate(),
          formula = k_allocator ~ k_sector,
          value.var = 'v_cost'
        )

        order_columns <- c("0-2 år", "3-6 år", "7-11 år", "12-17 år")

        # Find the columns that actually exist in the data.table
        existing_columns <- order_columns[order_columns %in% colnames(table_DT)]

        data.table::setcolorder(
          table_DT,
          c("k_allocator",existing_columns)
        )

        data.table::setnames(
          table_DT,
          old = "k_allocator",
          new = "Uddannelse"
        )


        table_DT[
          ,
          group:= "Hvem tager sygedagene?"
          ,
        ]
        generate_table(
          DT = table_DT,
          header = NULL
        )



      }
    )




    output$plot <- plotly::renderPlotly(
      {

        layout(
          plot = plot(
            data = DT_aggregate(),
            y     = setNames("factor(
              k_sector,
              levels = c('0-2 år', '3-6 år', '7-11 år', '12-17 år')
            )",
            nm = "Aldersgruppe"),
            x     = setNames(
              object = "v_cost",
              nm = "Ugentlig produktionstab pr. forældre (kr.)"
            ),
            color = ~k_allocator,
            type = "bar",
            orientation = "h",
            alpha = 0.7,
            marker = list(
              line = list(
                color = 'black',
                width = 1.5))
          ),
          title = "title",
          dark = as.logical(
            theme() == "dark"
          )
        )
      }
    )



  })
}

## To be copied in the UI
# mod_model2_ui("model2_1")

## To be copied in the server
# mod_model2_server("model2_1")
