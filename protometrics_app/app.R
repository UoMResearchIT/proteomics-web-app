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
           selectInput(inputId = 'dataset_file',
                       label = 'Choose a dataset:',
                       choices = gsub(pattern = "\\.xlsx$",
                                      "",
                                      list.files(path = "./data"),
                                      )
                       ),
           ),
    column(6, uiOutput("GeneList")),
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
      tabPanel('PCA', plotOutput('PCA_plot', width = "60%")),
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
    req(input$dataset_file)
    read_excel(paste0('./data/',input$dataset_file, '.xlsx'))[,-1] |>
      pivot_longer(cols = !(UniprotID:gene.names),
                   names_to = "experiment", 
                   values_to = "expression")
  })

  #### Create gene drop-down menu ####
  output$GeneList <- renderUI({
    selectizeInput("gene_dropdown", "Gene:", choices = NULL)
  })
  observe({
    # Update the selectizeInput on the server side
    items <- sort(unique(data()$gene.names))
    updateSelectizeInput(session, "gene_dropdown", choices = items, server = TRUE)
  })

  #### Create bar plot ####
  output$plot_bar <- renderPlotly({
    req(input$gene_dropdown)
    bar_plot(input$gene_dropdown, data())
  })

  #### Create box plot ####
  output$plot_box <- renderPlotly({
    req(input$gene_dropdown)
    box_plot(input$gene_dropdown, data())
  })

  #### create PCA plot ####
  output$PCA_plot <- renderPlot({
    #req(input&upload)
    pca_plot() # this is hard coded with template data at the moment
  })

  #### Create heatmap ####
  ht <- function.heatmap() # this is hard coded with template data at the moment
  makeInteractiveComplexHeatmap(input, output, session, ht)

  ####  render Print ####
#  output$info <- renderPrint({
 #   req(input$plot_click)
  #  x <- round(input$plot_click$x, 2)
   # y <- round(input$plot_click$y, 2)
    #cat("[", x, ", ", y, "]", sep = "")
#  })

}

#### Serve ####
shinyApp(ui, server)
