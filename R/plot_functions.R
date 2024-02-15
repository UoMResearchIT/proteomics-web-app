#### Settings ####
font_family <- 'Arial'

##### Plotting scripts ####

#### TAB 1 ####
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

#### TAB 2 ####
generate_heatmap_colors <- function(matrix){
  x <- as.matrix(matrix)
  x.trunc <- as.vector(unique(x))
  x.trim <- x.trunc[x.trunc >= quantile(x.trunc, probs = 0.01, na.rm = T) &
                      x.trunc <= quantile(x.trunc, probs = 0.99, na.rm = T)]
  x.max <- which.max(x.trim)
  x.min <- which.min(x.trim)
  # Create a color function for the heatmap values
  col_fun <- circlize::colorRamp2(c(x.trim[x.min], 0, x.trim[x.max]),
                                  c("blue", "white", "red"),
                                  space = "sRGB")
  # Create color lists for samples and groups labels
  samples_names <- gsub("_", " ", colnames(x)) # for sample annotation
  samples_colors <- rainbow(length(samples_names))
  col_samples <- setNames(samples_colors, samples_names)
  group_names <- gsub("_\\d+", "", colnames(x)) |> as.factor() |> levels()
  group_colors <- hcl.colors(length(group_names))
  col_group <- setNames(group_colors, group_names)

  return(list(col_fun = col_fun, col_samples = col_samples, col_group = col_group))
}

top_annotation <- function(data, heatmap_colors){
  samples_lab <- gsub("_", " ", colnames(data))
  groups_lab <- gsub("_\\d+", "", colnames(data))
  top_annotation = HeatmapAnnotation(Samples = samples_lab,
                                     Groups = groups_lab,
                                     col = list(Samples = heatmap_colors$col_samples,
                                                Groups = heatmap_colors$col_group),
                                     show_annotation_name = T,
                                     annotation_name_side = "left",
                                     annotation_name_gp = gpar(fontsize = 9, fontface = "bold"))
  return(top_annotation)
}

make_heatmap <- function(data, heatmap_colors){
  data_m <- as.matrix(data)
  set.seed(3)
  ht <- ComplexHeatmap::Heatmap(data_m,
                                name = "P. Level",
                                cluster_rows = TRUE,
                                cluster_columns = FALSE,
                                col = heatmap_colors$col_fun,
                                show_row_names = F,
                                show_column_names = F,
                                row_title = "Proteins",
                                row_title_gp = gpar(fontsize = 10, fontface = "bold"),
                                column_title = "",
                                row_dend_width = unit(1.5, "cm"),
                                top_annotation = top_annotation(data_m, heatmap_colors))
  return(draw(ht,merge_legend = TRUE))
}

make_sub_heatmap <- function(data, heatmap_colors){
  data_m <- as.matrix(data)
  row_lab <- gsub(".*,\\s*", "", rownames(data_m))
  set.seed(3)
  ht <- ComplexHeatmap::Heatmap(data_m,
                                name = "P. Level",
                                cluster_rows = FALSE,
                                cluster_columns = FALSE,
                                col = heatmap_colors$col_fun,
                                show_row_names = T,
                                row_labels = row_lab,
                                row_names_gp = gpar(fontsize = 9),
                                show_column_names = T,
                                column_names_gp = gpar(fontsize = 10),
                                column_names_rot = 45,
                                row_title = "Proteins",
                                row_title_gp = grid::gpar(fontsize = 12, fontface = "bold"),
                                column_title = "",
                                top_annotation = top_annotation(data_m, heatmap_colors))
  return(draw(ht,merge_legend = TRUE))
}

#### TAB 3 ####
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
          axis.text.x = element_text(size = 10),
          axis.text.y = element_text(size = 10),
          legend.text = element_text(size = 10),
          legend.position = "none") +
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
          axis.text.x = element_text(size = 10),
          axis.text.y = element_text(size = 10),
          legend.text = element_text(size = 10),
          legend.position = "none")
  return(p)
}
