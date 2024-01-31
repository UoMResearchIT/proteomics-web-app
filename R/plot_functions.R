#### Settings ####
font_family <- 'Courier'

##### Plotting scripts ####

#### TAB 1 ####
bar_plot <- function(gene_dropdown, df){
  ## TODO: Sort out Warning: Removed x rows containing missing values
  if (!(gene_dropdown %in% df$gene.names)) {
    return()
  }
  df.plot <- df |>
    filter(gene.names == gene_dropdown) |>
    mutate(experiment_type = str_extract(experiment, "[A-Z]+")) |>
    filter(!is.na(expression))
  p <- ggplot(data = df.plot, aes(x = experiment, y = expression)) 
  p <- p +
    geom_bar(mapping = aes(x = experiment,
                           y = expression,
                           fill = experiment_type),
             stat = "identity",
             col = "black") +
    xlab("") +
    scale_y_continuous(name = "Normalized Log2-protein intensity") +
    # ggtitle(paste("Template data set", plot.data$Gene.symbol[1], sep = ", ")) +
    theme_light() +
    theme(text = element_text(family = font_family),
          axis.text.x = element_text(size = 10,
                                     colour = "black",
                                     family = font_family,
                                     angle = 45),
          axis.text.y = element_text(size = 10,
                                     colour = "black",
                                     family = font_family),
          legend.text = element_text(size = 10, family = font_family),
          legend.position = "none",
          legend.box.just = "center") +
    labs(NULL)
  return(p)
}
box_plot <- function(gene_dropdown, df){
  if (!(gene_dropdown %in% df$gene.names)) {
    return()
  }
  df.plot <- df |>
    filter(gene.names == gene_dropdown) |>
    mutate(experiment_type = str_extract(experiment, "[A-Z]+")) |>
    filter(!is.na(expression))
  p <- ggplot(data = df.plot, aes(x = experiment_type, y = expression)) 
  p <- p +
    geom_boxplot(mapping = aes(x = experiment_type,
                               y = expression,
                               fill = experiment_type),
                 col = "black") +
    geom_point(mapping = aes(x = experiment_type,
                             y = expression),
               pch = 20, size = 1.5) +
    xlab("") +
    scale_y_continuous(name = "Normalized Log2-protein intensity") +
    theme_light() +
    theme(text = element_text(family = font_family),
          axis.text.x = element_text(size = 10,
                                     colour = "black",
                                     family = font_family),
          axis.text.y = element_text(size = 10,
                                     colour = "black",
                                     family = font_family),
          legend.text = element_text(size = 10, family = font_family),
          legend.position = "right ")
  return(p)
}

#### TAB 2 ####
pca_plot <- function(df){
  # create the group design
  design <- data.frame("Samples" = seq(1:nrow(df)),
                       "Group" = seq(1:nrow(df)))
  design$Samples <- rownames(df)
  design$Group <- gsub("_\\d+", "", design$Samples)

  # Perform a PCA with pre-processed data
  pca <- pca(X = df,
             ncomp = nrow(df),
             center = TRUE,
             scale = TRUE)
  # Create a 2D Sample Plot
  p <- plotIndiv(object = pca,
            comp = c(1,2),
            ind.names = FALSE,
            group = design$Group,
            title = "Template data set",
            legend = TRUE,
            size.xlabel = rel(1.3),
            size.ylabel = rel(1.3),
            size.legend = rel(1.3),
            cex = 0.8,
            ellipse = TRUE)
  return(p$graph)
}

#### TAB 3 ####
function.heatmap <- function(matrix){
  x <- as.matrix(matrix)
  x.trunc <- as.vector(unique(x))
  x.trim <- x.trunc[x.trunc >= quantile(x.trunc, probs = 0.01, na.rm = T) &
                      x.trunc <= quantile(x.trunc, probs = 0.99, na.rm = T)]
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
  # create heatmap
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
  return(ht)
}
