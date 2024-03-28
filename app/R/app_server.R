#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.

# Libraries
library(shiny)
library(shinyjs)
library(readxl)
library(tidyr)
library(plotly)
library(InteractiveComplexHeatmap)


source("R/plot_functions.R")
source("R/save_as_button.R")

app_server <- function(input, output, session) {
  thematic::thematic_shiny()

  #### Automatically get/write parameters from/to url ####
  selected_gene <- reactiveVal("")
  default_gene <- reactiveVal("")
  default_tab <- "PCA"
  observe({
    # Only set bookmarking non-default parameters
    if (input$view == "home") {
      bookmarking_params <- c()
    } else {
      bookmarking_params <- c("view")
    }
    if (input$view == "data") {
      bookmarking_params <- union(
        bookmarking_params,
        c("dataset", "gene", "tab")
      )
      if (input$tab == default_tab) {
        bookmarking_params <- setdiff(bookmarking_params, "tab")
      }
      if ((input$tab != "BoxPlot") || (input$gene == default_gene())) {
        bookmarking_params <- setdiff(bookmarking_params, "gene")
      }
    }
    to_exclude <- setdiff(names(input), bookmarking_params)
    setBookmarkExclude(to_exclude)
    session$doBookmark()
  })
  onBookmarked(updateQueryString)
  onRestore(function(state) {
    if (!is.null(state$input$gene)) {
      selected_gene(state$input$gene)
    }
  })

  #### Create data object from selected dataset ####
  data <- reactive({
    req(input$dataset)
    excel_ok <- tryCatch({
      read_excel(paste0("data/datasets/", input$dataset, ".xlsx")) |>
        pivot_longer(cols = !(Identifiers:Gene),
                     names_to = "experiment",
                     values_to = "expression")
    }, error = function(e) {
      message("Error reading the dataset file:", conditionMessage(e))
      showNotification(
        "Error reading the selected dataset.",
        type = "error", duration = 10
      )
      return(tibble(Gene = ""))
    })
    return(excel_ok)
  })
  dataset_info <- reactive({
    req(input$dataset)
    #find md info file in data/dataset-info
    file_paths <- c(
      paste0("data/dataset-info/", input$dataset, ".md", sep = ""),
      paste0("data/dataset-info/", input$dataset, "_info.md", sep = ""),
      paste0("data/dataset-info/", input$dataset, "-info.md", sep = "")
    )
    file_path <- NULL
    for (path in file_paths) {
      if (file.exists(path)) {
        file_path <- path
        break
      }
    }
    if (!is.null(file_path)) {
      return(file_path)
    } else {
      return(paste("Info for dataset", input$dataset, "not available."))
    }
  })
  output$dataset_info <- renderUI(includeMarkdown(dataset_info()))

  ht_colors <- reactiveVal(NULL)
  heatmap_data <- reactive({
    req(input$dataset)
    file_path <- paste0("data/heatmaps/", input$dataset,
                        "_heatmap.xlsx", sep = "")
    excel_ok <- tryCatch({
      openxlsx::read.xlsx(file_path, sheet = 1)
    }, error = function(e) {
      message("Error reading the heatmap file:", conditionMessage(e))
      showNotification(
        "Error reading the selected heatmap.",
        type = "error", duration = 10
      )
    })
    # Set row names
    row_names <- paste(excel_ok$Gene,
                       "   (",
                       excel_ok$Protein,
                       ")",
                       sep = "")
    # Update autocomplete choices for search bar
    updateSelectizeInput(
      session,
      "subh_gene",
      choices = sort(unique(unlist(row_names))),
      server = TRUE
    )
    # Check for duplicated row_names and add a number to make unique
    duplicates <- duplicated(row_names)
    if (any(duplicates)) {
      sequence <- ave(
        seq_along(row_names), row_names, FUN = function(x) seq_along(x) - 1
      )
      row_names[duplicates] <- paste(row_names[duplicates],
                                     sequence[duplicates],
                                     sep = " ")
    }
    rownames(excel_ok) <- row_names
    # Calculate colors used for heatmap and subheatmap
    ht_colors(generate_heatmap_colors(excel_ok))
    return(excel_ok)
  })

  pca_data <- reactive({
    req(input$dataset)
    file_path <- paste0(
      "data/pcaplots/",
      input$dataset,
      "_pca.xlsx",
      sep = ""
    )
    excel_ok <- tryCatch({
      openxlsx::read.xlsx(file_path, sheet = 1, rowNames = TRUE)
    }, error = function(e) {
      message("Error reading the pca file:", conditionMessage(e))
      showNotification(
        "Error reading the selected pca.",
        type = "error", duration = 10
      )
      return(NULL)
    })
    return(excel_ok)
  })

  #### Create gene drop-down menu ####
  observe({
    # Update the gene list on the server side
    items <- sort(unique(data()$Gene))
    if (!(selected_gene() %in% items)) {
      if (!(selected_gene() == "") && (input$tab == "BoxPlot")) {
        showNotification(
          paste(
            "Gene:",
            selected_gene(),
            "not available in",
            input$dataset,
            "dataset."
          ),
          type = "warning", duration = 5
        )
      }
      selected_gene(items[1])
    }
    updateSelectizeInput(session, "gene",
                         choices = items,
                         selected = selected_gene(),
                         server = TRUE)
    default_gene(items[1])
  })

  #### create PCA plot ####
  .pca_plot <- reactive({
    req(pca_data())
    return(pca_plot(pca_data()))
  })
  output$PCA_plot <- renderPlotly(.pca_plot())

  #### Create heatmap ####
  ht_obj <- reactiveVal(NULL)
  ht_pos_obj <- reactiveVal(NULL)
  .heatmap_plot <- reactive({
    ht <- make_heatmap(heatmap_data(), ht_colors())
    ht_pos <- htPositionsOnDevice(ht)
    ht_obj(ht)
    ht_pos_obj(ht_pos)
    return(ht)
  })
  output$heatmap <- renderPlot(.heatmap_plot())

  #### Create sub-heatmap ####
  sub_data <- reactiveVal(NULL)
  .subheat_plot <- reactiveVal(NULL)
  # From selection on heamap
  observeEvent(input$heatmap_brush, {
    lt <- getPositionFromBrush(input$heatmap_brush)
    selection <- selectArea(ht_obj(),
                            pos1 = lt[[1]],
                            pos2 = lt[[2]],
                            ht_pos = ht_pos_obj(),
                            mark = FALSE,
                            verbose = FALSE,
                            calibrate = FALSE)
    sub_rows <- unlist(selection$row_index)
    sub_cols <- unlist(selection$column_label)
    sub_data(heatmap_data()[sub_rows, sub_cols, drop = FALSE])
    if (nrow(sub_data()) == 0 || ncol(sub_data()) == 0) {
      .subheat_plot(NULL)
      shinyjs::hide("subheat_save_as-save_as_button")
      shinyjs::hide("subheat_save_as-save_as_options")
    } else {
      .subheat_plot(make_sub_heatmap(sub_data(), ht_colors()))
      shinyjs::show("subheat_save_as-save_as_button")
      updateSelectizeInput(session, "subh_gene", selected = "")
    }
    output$sub_heatmap <- renderPlot({
      .subheat_plot()
    })
  })
  # From search textbox
  observeEvent(input$subh_gene, {
    grep_str <- paste(input$subh_gene, collapse = "|")
    if (grep_str != "") {
      output$sub_heat_chosen_genes <- renderPrint(grep_str)
      sub_rows <- grep(grep_str, rownames(heatmap_data()), ignore.case = TRUE)
      sub_data(heatmap_data()[sub_rows, ])
      if (nrow(sub_data()) == 0) {
        .subheat_plot(NULL)
        shinyjs::hide("subheat_save_as-save_as_button")
        shinyjs::hide("subheat_save_as-save_as_options")
      } else {
        .subheat_plot(make_sub_heatmap(sub_data(), ht_colors()))
        shinyjs::show("subheat_save_as-save_as_button")
        shinyjs::hide("heatmap_brush")
      }
      output$sub_heatmap <- renderPlot({
        .subheat_plot()
      })
    } else {
      .subheat_plot(NULL)
      shinyjs::hide("subheat_save_as-save_as_button")
    }
  })
  output$sub_heat <- renderUI({
    if (is.null(.subheat_plot())) {
      return(HTML(
        '<div style="color: gray; margin: 100px auto; text-align: center;
        margin-left: 100px; border: 1px dashed gray; padding: 10px;">
          Use the search bar to find proteins,<br>
          or click and drag over the heatmap.
        </div>'
      ))
    } else {
      return(plotOutput("sub_heatmap", width = 600, height = 500))
    }
  })

  #### Create bar plot ####
  .bar_plot <- reactive({
    req(input$gene)
    return(bar_plot(input$gene, data()))
  })
  output$plot_bar <- renderPlotly(.bar_plot())

  #### Create box plot ####
  .box_plot <- reactive({
    req(input$gene)
    return(box_plot(input$gene, data()))
  })
  output$plot_box <- renderPlotly(.box_plot())

  #### Download buttons ####
  shinyjs::hide("subheat_save_as-save_as_button")
  save_as_server("pca_save_as", input$dataset, .pca_plot(), "PCA")
  save_as_server("heatmap_save_as", input$dataset, .heatmap_plot(),
                 "HeatMap")
  save_as_server("subheat_save_as", input$dataset, .subheat_plot(),
                 "SubHeatMap")
  save_as_server("bar_save_as", input$dataset, .bar_plot(), "Bar")
  save_as_server("box_save_as", input$dataset, .box_plot(), "Box")

}
