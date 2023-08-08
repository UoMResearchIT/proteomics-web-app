library(shiny)
library(ggplot2)
library(readxl)
library(tidyverse)

ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "darkly"),
  div(style = "height:50px"),
  titlePanel('Lennon Lab Proteomic data archive'),
  div(style = "height:50px"),
  sidebarLayout(
    sidebarPanel( 
      fileInput("upload", label = 'Dataset'),
    #  tableOutput("head"),
      uiOutput("toCol"),
      ),
  
  mainPanel(
    tabsetPanel(
      tabPanel('BoxPlot', 
       plotOutput("plot", click = "plot_click"),
      # verbatimTextOutput("info"),
       tableOutput("near_rows_data")
    ),
      tabPanel('PCA', 'Plot ot be added'),
      tabPanel('HeatMap', 'Plot to be added'),
      tabPanel('Correlation','Plot ot be added')
    )
  ),
  )
)

server <- function(input, output, session) {
  thematic::thematic_shiny()
  
  data <- reactive({
    req(input$upload)
    read_excel(input$upload$datapath)[,-1] |>
      pivot_longer(cols = !(UniprotID:gene.names),
                   names_to = "experiment", 
                   values_to = "expression")
  })

  output$head <- renderTable({
    head(data(), 5)
  })
  output$near_rows_data <- renderTable({
    req(input$plot_click)
    df <- data()
    nearPoints(df[df$gene.names == input$gene_dropdown,],
               input$plot_click,
               maxpoints = 5)
  })
  output$toCol <- renderUI({
    df <- data()
    items <- unique(df$gene.names)
    selectInput("gene_dropdown", "Gene:", items)
  })
  
  output$plot <- renderPlot({
    req(input$gene_dropdown)
    df <- data()
    df |>
      filter(gene.names == input$gene_dropdown) |>
      ggplot(aes(x = experiment, y = expression)) +
      geom_point()
  }, res = 96)
  
  output$info <- renderPrint({
    req(input$plot_click)
    x <- round(input$plot_click$x, 2)
    y <- round(input$plot_click$y, 2)
    cat("[", x, ", ", y, "]", sep = "")
  })
}

shinyApp(ui, server)
