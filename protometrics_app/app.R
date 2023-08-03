library(shiny)
library(ggplot2)
library(readxl)
library(tidyverse)

ui <- fluidPage(

  fileInput("upload", NULL),
  tableOutput("head"),
  uiOutput("toCol"),
  plotOutput("plot", click = "plot_click"),
  verbatimTextOutput("info")

)

server <- function(input, output, session) {
  
  data <- reactive({
    req(input$upload)
    read_excel(input$upload$datapath)
  })

  output$head <- renderTable({
    head(data(), 5)
  })
  
  output$toCol <- renderUI({
    df <- data()
    items <- unique(df$gene.names)
    selectInput("gene_dropdown", "Gene:", items)
  })
  
  output$plot <- renderPlot({
    req(input$gene_dropdown)
    df <- data()
    df[,-1] |>
      pivot_longer(cols = !(UniprotID:gene.names), 
        names_to = "experiment", 
        values_to = "expression") |>
      filter(gene.names == input$gene_dropdown) |>
      ggplot(aes(x = experiment, y = expression)) +
      geom_point()
  }, res = 96)
  
 
}

shinyApp(ui, server)
