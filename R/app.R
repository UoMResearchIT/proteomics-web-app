#### Load libraries ####
library(shiny)
library(shinyjs)
library(ggplot2)
library(readxl)
library(tidyverse)
library(plotly)
library(InteractiveComplexHeatmap)
library(ComplexHeatmap)
library(mixOmics)
library(markdown)

source("plot_functions.R")
source("save_as_button.R")

#### Front end ####
ui <- function(request) {
  fluidPage(
    #### Headers ####
    useShinyjs(),
    tags$head(
      # Hide modbar from plotly plots (PCA and BoxPlot)
      # Hide the control bar from heatmap and sub-heatmap
      # Hide the output wrapper from heatmap and sub-heatmap
      tags$style(HTML(
        "
        .modebar {display: none !important;}
        [id*='heatmap_control'] {display: none !important;}
        [id*='output_wrapper'] {display: none !important;}
        "
      )),
    ),
    #### Content ####
    navbarPage(
      id = "view",
      title = "proteinBASE",
      theme = bslib::bs_theme(bootswatch = "flatly"),
      #### Landing page ####
      tabPanel("Home",
               value = "home",
               div(includeMarkdown("../data/content/home.md"))
      ),
      #### Data Visualization Tool ####
      tabPanel("Data Visualization Tool",
               value = "data",
               div(style = "height:50px"),
               #### Dataset and gene selection dropdown menus ####
               fluidRow(
                 column(6,
                        selectInput(
                          inputId = 'dataset',
                          label = 'Choose a dataset:',
                          choices = gsub(
                            pattern = "\\.xlsx$",
                            "",
                            list.files(
                              path = "../data/datasets/",
                              pattern = "\\.xlsx$",
                              full.names = FALSE
                            ),
                          )
                        ),
                 ),
                 column(6,
                        # Only show gene dropdown if selected tab is BoxPlot
                        conditionalPanel(
                          condition = "input.tab == 'BoxPlot'",
                          selectizeInput("gene", "Gene:", choices = NULL)
                        )
                 )
               ),
               #### Plot tabs ####
               fluidRow(
                 tabsetPanel(
                   id = "tab",
                   #### PCA ####
                   tabPanel('PCA',
                            plotOutput('PCA_plot', width = 600, height = 450),
                            save_as_UI("pca_save_as", 600, 450)
                   ),
                   #### HeatMap ####
                   tabPanel('HeatMap',
                            InteractiveComplexHeatmapOutput()
                   ),
                   #### BoxPlot ####
                   tabPanel('BoxPlot',
                            fluidRow(
                              column(6,
                                     plotlyOutput("plot_bar"),
                                     save_as_UI("bar_save_as", 500, 400)
                              ),
                              column(6,
                                     plotlyOutput("plot_box"),
                                     save_as_UI("box_save_as", 500, 400)
                              ),
                            ),
                            tableOutput("near_rows_data")
                   ),
                   #### About the dataset ####
                   tabPanel('About the dataset',
                            uiOutput('dataset_info'),
                   ),
                 )
               ),
      ),
      #### Plot Description ####
      tabPanel("Plot Description",
               value = "plot_description",
               div(includeMarkdown("../data/content/plot_description.md"))
      ),
      #### Useful Links ####
      tabPanel("Useful Links",
               value = "useful_links",
               div(includeMarkdown("../data/content/useful_links.md"))
      ),
      #### Contact ####
      tabPanel("Contact",
               value = "contact",
               div(includeMarkdown("../data/content/contact.md"))
      )
    )
  )
}

#### Back end ####
server <- function(input, output, session) {
  thematic::thematic_shiny()

  #### Automatically get/write parameters from/to url ####
  selected_gene <- reactiveVal("")
  default_gene <- reactiveVal("")
  default_tab <- "PCA"
  observe({
    # Only set bookmarking non-default parameters
    if (input$view == "home") { bookmarkingParams <- c() }
    else { bookmarkingParams <- c("view") }
    if (input$view == "data") {
      bookmarkingParams <- union(bookmarkingParams, c("dataset","gene","tab"))
      if (input$tab == default_tab) {
        bookmarkingParams <- setdiff(bookmarkingParams, "tab")
      }
      if ((input$tab != "BoxPlot") || (input$gene == default_gene())) {
        bookmarkingParams <- setdiff(bookmarkingParams, "gene")
      }
    }
    toExclude <- setdiff(names(input), bookmarkingParams)
    setBookmarkExclude(toExclude)
    session$doBookmark()
  })
  onBookmarked(updateQueryString)
  onRestore(function(state){
    if (!is.null(state$input$gene)) {
      selected_gene(state$input$gene)
    }
  })

  #### Create data object from selected dataset ####
  data <- reactive({
    req(input$dataset)
    excel_ok <- tryCatch({
      read_excel(paste0('../data/datasets/',input$dataset, '.xlsx'))[,-1] |>
        pivot_longer(cols = !(UniprotID:gene.names),
                     names_to = "experiment",
                     values_to = "expression")
    }, error = function(e) {
      message("Error reading the Excel file:", conditionMessage(e))
      showNotification(
        "Error reading the selected dataset.",
        type = "error", duration = 10
      )
      return(tibble(gene.names = ""))
    })
    return(excel_ok)
  })
  dataset_info <- reactive({
    req(input$dataset)
    #find md info file in ../data/dataset-info
    file_path <- paste0("../data/dataset-info/", input$dataset, ".md",sep="")
    if (file.exists(file_path)) {
        return(file_path)
    } else {
        return(paste("Info for dataset", input$dataset, "not available."))
    }
  })
  output$dataset_info <- renderUI(includeMarkdown(dataset_info()))
  # The histogram is currently using temporary fixed data. It is pre-processed
  # specifically to make a heatmap.
  # TODO: Pre-processing of data should happen within app so it can be applied
  # to any selected dataset.
  heatmap_data <- openxlsx::read.xlsx("../data/heatmaps/PXDtemplate_heatmap.xlsx",
                                      sheet = 1, rowNames = TRUE)

  # The pca plot is currently using temporary fixed data. It is pre-processed
  # specifically to make the pca plot.
  # TODO: Pre-processing of data should happen within app so it can be applied
  # to any selected dataset.
  pca_data <- openxlsx::read.xlsx("../data/pcaplots/PXDtemplate_pca.xlsx",
                                  sheet = 1, rowNames = TRUE)

  #### Create gene drop-down menu ####
  observe({
    # Update the gene list on the server side
    items <- sort(unique(data()$gene.names))
    if (!(selected_gene() %in% items)) {
      if (!(selected_gene() == "") && (input$tab == "BoxPlot")) {
        showNotification(
          paste("Gene:", selected_gene(), "not available in",input$dataset,"dataset."),
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
  .pca_plot <- reactive(
    return(pca_plot(pca_data))
  )
  output$PCA_plot <- renderPlot(.pca_plot())

  #### Create heatmap ####
  ht <- function.heatmap(heatmap_data)
  makeInteractiveComplexHeatmap(input, output, session, ht)

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
  save_as_Server("pca_save_as", input$dataset, .pca_plot(), "PCA")
  save_as_Server("bar_save_as", input$dataset, .bar_plot(), "Bar")
  save_as_Server("box_save_as", input$dataset, .box_plot(), "Box")

}

#### Serve ####
enableBookmarking(store = "url")
shinyApp(ui, server)
