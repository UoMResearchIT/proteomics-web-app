library(shiny)
library(ggplot2)
library(readxl)
library(tidyverse)
library(plotly)
library(InteractiveComplexHeatmap)
library(ComplexHeatmap)



matrix <- openxlsx::read.xlsx("../data/PXDtemplate_heatmap.xlsx",
                                      rowNames = TRUE)
x <- as.matrix(matrix)
x.trunc <- as.vector(unique(x))
x.trim <- x.trunc[x.trunc>=quantile(x.trunc, probs = 0.01, na.rm = T) &
                    x.trunc<=quantile(x.trunc, probs = 0.99, na.rm = T)]
x.max <- which.max(x.trim)
x.min <- which.min(x.trim)
# create a color function for the heatmap
col_fun <- circlize::colorRamp2(c(x.trim[x.min], 0, x.trim[x.max]),
                                c("blue", "white", "red"),
                                space = "sRGB")
# create labels for the heatmap
rowlab <- gsub(".*,\\s*", "", rownames(x)) # UniProt ID for row labels
col_lab <- gsub("_", " ", colnames(x)) # for sample annotation
col_group <- gsub("_\\d+", "", colnames(x)) |> # for group annotation
  unlist() |> 
  as.factor()
# draw a heatmap
set.seed(3)
ht <- ComplexHeatmap::Heatmap(x,
                             name = "Protein level",
                             col = col_fun,
                             show_row_names = T,
                             row_labels = rowlab,
                             show_column_names = F,
                             row_title = "Proteins",
                             row_title_gp = grid::gpar(fontsize = 12,
                                                       fontface = "bold"),
                             column_title = "",
                             row_dend_width = unit(2, "cm"),
                             row_names_gp = gpar(fontsize = 1),
                             top_annotation = HeatmapAnnotation(Samples = col_lab,
                                                                Groups = col_group,
                                                                show_annotation_name = FALSE))

ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "flatly"),
  div(style = "height:50px"),
  titlePanel('Lennon Lab Proteomic data archive'),
  div(style = "height:50px"),
  fluidRow(
    column(6, 
      fileInput("upload", label = 'Dataset')),
    column(6,
      uiOutput("toCol")),
      ),
  
  fluidRow(
    tabsetPanel(
      tabPanel('BoxPlot', 
       plotlyOutput("plot_bar"),#, click = "plot_click", hover = 'plot_bar_hover'),
      # verbatimTextOutput("info"),
       plotlyOutput("plot_box"),
       tableOutput("near_rows_data")
    ),
      tabPanel('PCA',
               plotOutput('PCA_plot')),
      tabPanel('HeatMap', 
               InteractiveComplexHeatmapOutput()
      ),
      tabPanel('Correlation','Plot ot be added')
    )
  ),
  )


server <- function(input, output, session) {
  thematic::thematic_shiny()
  
  makeInteractiveComplexHeatmap(input, output, session, ht)

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
    req(input$plot_bar_hover)
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
      mutate(experiment_type = str_extract(experiment, "[A-Z]+")) |>
      ggplot(aes(x = experiment_type, y = expression)) +
      geom_boxplot()
  }, res = 96)

  output$plot_bar <- renderPlotly({
    req(input$gene_dropdown)
    df <- data()
    df.plot <- df |>
      filter(gene.names == input$gene_dropdown) |>
      mutate(experiment_type = str_extract(experiment, "[A-Z]+"))
      p <- ggplot(data = df.plot, aes(x = experiment, y = expression)) 
      p <- p + geom_bar(mapping = aes(x = experiment,
                             y = expression,
                             fill = experiment_type),
               stat = "identity",
               col = "black") +
      xlab("") +
      scale_y_continuous(name = "Normalized Log2-protein intensity") +
      # ggtitle(paste("Template data set", plot.data$Gene.symbol[1], sep = ", ")) +
      theme_light() +
      theme(axis.text = element_text(size = 10,
                                     colour = "black"),
            legend.text = element_text(size = 10),
            legend.position = "right",
            legend.box.just = "center") +
      labs(NULL)
      ggplotly(p)
  })
  output$PCA_plot <- renderPlot({
    #req(input&upload)
    df <- openxlsx::read.xlsx("../data/PXDtemplate_pca.xlsx",
                              rowNames = TRUE)
    # create the group design
    design <- data.frame("Samples" = seq(1:nrow(df)),
                         "Group" = seq(1:nrow(df)))
    
    design$Samples <- rownames(df)
    design$Group <- gsub("_\\d+", "", design$Samples)
    
    # Perform a PCA with data pre-processed
    pca <- pca(X = df,
               ncomp = nrow(df),
               center = TRUE,
               scale = TRUE)
    
    # Create a 2D Sample Plot
    plotIndiv(object = pca,
                    comp = c(1,2),
                    ind.names = FALSE,
                    group = design$Group,
                    title = "Template data set",
                    legend = TRUE,
                    cex = 0.8,
                    ellipse = TRUE)
    
  })
  
  
  output$plot_box <- renderPlotly({
    req(input$gene_dropdown)
    df <- data()
    df.plot <- df |>
      filter(gene.names == input$gene_dropdown) |>
      mutate(experiment_type = str_extract(experiment, "[A-Z]+"))
      p <- ggplot(data = df.plot, aes(x = experiment_type, y = expression)) 
      p <- p + geom_boxplot(mapping = aes(x = experiment_type,
                                          y = expression,
                                          fill = experiment_type),
                            col = "black") +
        #geom_point(data = meanvalues,
         #          aes(x = experiment_type,
          #             y = Mean),
           #        pch = 18, size = 3,) +
        geom_point(mapping = aes(x = experiment_type,
                                 y = expression),
                   pch = 20, size = 1.5) +
        xlab("") +
        scale_y_continuous(name = "Normalized Log2-protein intensity") +
        theme_light() +
        theme(axis.text = element_text(size = 10,
                                       colour = "black"),
              legend.text = element_text(size = 10),
              legend.position = "none")
      ggplotly(p)
    
  })
  
  
  output$info <- renderPrint({
    req(input$plot_click)
    x <- round(input$plot_click$x, 2)
    y <- round(input$plot_click$y, 2)
    cat("[", x, ", ", y, "]", sep = "")
  })
}

shinyApp(ui, server)
