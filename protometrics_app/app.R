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
ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "flatly"),
  div(style = "height:50px"),
  titlePanel('Lennon Lab Proteomic data archive'),
  div(style = "height:50px"),
  fluidRow(
    column(6,
           selectInput(inputId = 'dataset',
                       label = 'Choose a dataset:',
                       choices = gsub(pattern = "\\.xlsx$",
                                      "",
                                      list.files(path = "./data"),
                                      )
                       ),
           ),
    column(6, selectizeInput("gene", "Gene:", choices = NULL)),
    ),

  fluidRow(
    tabsetPanel(
      tabPanel('BoxPlot', 
               fluidRow(
                 column(6, plotlyOutput("plot_bar")),
                 column(6, plotlyOutput("plot_box")),
                 ),
               tableOutput("near_rows_data")
               ),
      tabPanel('PCA', plotOutput('PCA_plot', width = "80%")),
      tabPanel('HeatMap', InteractiveComplexHeatmapOutput()),
      tabPanel('Correlation','Plot ot be added'),
      )
    ),
  )

#### Back end ####
server <- function(input, output, session) {
  thematic::thematic_shiny()

  #### Create data object from selected dataset ####
  data <- reactive({
    req(input$dataset)
    read_excel(paste0('./data/',input$dataset, '.xlsx'))[,-1] |>
      pivot_longer(cols = !(UniprotID:gene.names),
                   names_to = "experiment", 
                   values_to = "expression")
  })
  # The histogram is currently using temporary fixed data. It is pre-processed
  # specifically to make a heatmap.
  # TODO: Pre-processing of data should happen within app so it can be applied
  # to any selected dataset.
  heatmap_data <- openxlsx::read.xlsx("./data/Heatmap/PXDtemplate_heatmap.xlsx",
                                      sheet = 1, rowNames = TRUE)

  # The pca plot is currently using temporary fixed data. It is pre-processed
  # specifically to make the pca plot.
  # TODO: Pre-processing of data should happen within app so it can be applied
  # to any selected dataset.
  pca_data <- openxlsx::read.xlsx("./data/PCA/PXDtemplate_pca.xlsx",
                                  sheet = 1, rowNames = TRUE)

  #### Create gene drop-down menu ####
  observe({
    # Update the gene list on the server side
    items <- sort(unique(data()$gene.names))
    updateSelectizeInput(session, "gene", choices = items, server = TRUE)
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
shinyApp(ui, server)
