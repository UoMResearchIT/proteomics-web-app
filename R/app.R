library(shiny)
library(ggplot2)
library(readxl)
library(tidyverse)
library(plotly)
library(InteractiveComplexHeatmap)
library(ComplexHeatmap)
library(mixOmics)

source("plot_functions.R")

#### Front end ####
ui <- function(request) {
  fluidPage(
    navbarPage(
      id = "view",
      title = "proteinBASE",
      theme = bslib::bs_theme(bootswatch = "flatly"),
      tabPanel("Home",
               value = "home",
               h1('About proteinBASE'),
               p(
                 "Lennon Lab Proteomic data archive ... Some info here"
               )
      ),
      tabPanel("Data Visualization Tool",
               value = "data",
               div(style = "height:50px"),
               fluidRow(
                 column(6,
                        selectInput(
                          inputId = 'dataset',
                          label = 'Choose a dataset:',
                          choices = gsub(
                            pattern = "\\.xlsx$",
                            "",
                            list.files(
                              path = "../data",
                              pattern = "\\.xlsx$",
                              full.names = FALSE
                            ),
                          )
                        ),
                 ),
                 column(6, selectizeInput("gene", "Gene:", choices = NULL)),
               ),
               fluidRow(
                 tabsetPanel(
                   id = "tab",
                   tabPanel('PCA', plotOutput('PCA_plot', width = "80%")),
                   tabPanel('HeatMap', InteractiveComplexHeatmapOutput()),
                   tabPanel('BoxPlot',
                            fluidRow(
                              column(6, plotlyOutput("plot_bar")),
                              column(6, plotlyOutput("plot_box")),
                            ),
                            tableOutput("near_rows_data")
                   ),
                   tabPanel('About the dataset','Info here'),
                 )
               ),
      ),
      tabPanel("Contact",
               value = "contact",
               h1('Contact'),
               p(
                 "Contact info here"
               )
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
      if (input$gene == default_gene()) {
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
      read_excel(paste0('../data/',input$dataset, '.xlsx'))[,-1] |>
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
  # The histogram is currently using temporary fixed data. It is pre-processed
  # specifically to make a heatmap.
  # TODO: Pre-processing of data should happen within app so it can be applied
  # to any selected dataset.
  heatmap_data <- openxlsx::read.xlsx("../data/Heatmap/PXDtemplate_heatmap.xlsx",
                                      sheet = 1, rowNames = TRUE)

  # The pca plot is currently using temporary fixed data. It is pre-processed
  # specifically to make the pca plot.
  # TODO: Pre-processing of data should happen within app so it can be applied
  # to any selected dataset.
  pca_data <- openxlsx::read.xlsx("../data/PCA/PXDtemplate_pca.xlsx",
                                  sheet = 1, rowNames = TRUE)

  #### Create gene drop-down menu ####
  observe({
    # Update the gene list on the server side
    items <- sort(unique(data()$gene.names))
    if (!(selected_gene() %in% items)) {
      if(!(selected_gene() == "")){
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

  #### Create bar plot ####
  output$plot_bar <- renderPlotly({
    req(input$gene)
    bar_plot(input$gene, data())
  })

  #### Create box plot ####
  output$plot_box <- renderPlotly({
    req(input$gene)
    box_plot(input$gene, data())
  })

  #### create PCA plot ####
  output$PCA_plot <- renderPlot({
    pca_plot(pca_data)
  })

  #### Create heatmap ####
  ht <- function.heatmap(heatmap_data)
  makeInteractiveComplexHeatmap(input, output, session, ht)

}

#### Serve ####
enableBookmarking(store = "url")
shinyApp(ui, server)
