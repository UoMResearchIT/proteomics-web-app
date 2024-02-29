#### Load libraries ####
library(ggplot2)
library(mixOmics)

#### Settings ####
font_family <- 'sans'
title_fontsize <- 13
label_fontsize <- 11
# Fonts in complex heatmaps are smaller, so added an extra pt.
title_font_gp <- function() {
  title_fonts <- gpar(fontsize = title_fontsize + 1,
                      fontface = "bold",
                      fontfamily = font_family)
  return(title_fonts)
}
label_font_gp <- function() {
  label_fonts <- gpar(fontsize = label_fontsize + 1,
                      fontfamily = font_family)
  return(label_fonts)
}

##### Plotting scripts ####

#### TAB 1 ####
pca_plot <- function(matrix){
  # Run PCA
  pca_protein <- mixOmics::pca(
    X = matrix,
    ncomp = nrow(matrix),
    center = TRUE
  )
  # Extract from 'pca_protein' coordinates for the PCA plot
  coord <- as.data.frame(round(pca_protein$variates$X, digits = 2))
  coord$group <- as.factor(gsub("_\\d+", "", rownames(coord)))
  coord$sampleName <- gsub("_", " ", rownames(coord))
  # Extract labels for x and y axes
  labels.pca <- as.vector(pca_protein$cum.var)
  xlabel <- paste0("PC1, ",
                   (round((labels.pca[1]*100),
                          digits = 2)),"%")
  ylabel <- paste0("PC2, ",
                   (round(((labels.pca[2]-labels.pca[1])*100),
                          digits = 2)),"%")

  # Generate 2D PCA plot
  pca_plot <-  ggplot(coord,
                      aes(x = PC1, y = PC2,
                          color = group,
                          text = paste("", sampleName))) +
    geom_point(size = 4) +
    labs(x = xlabel, y = ylabel, color = "") +
    xlim((min(coord$PC1)-10), max(coord$PC1)+10) +
    ylim((min(coord$PC2)-10), max(coord$PC2)+10) +
    theme_light() +
    theme(text = element_text(family = font_family, size = title_fontsize),
          axis.text.x = element_text(size = label_fontsize),
          axis.text.y = element_text(size = label_fontsize)) +
    guides(shape = "none")
  return(pca_plot)
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

top_annotation <- function(data, heatmap_colors, legend = TRUE) {
  samples_lab <- gsub("_", " ", colnames(data))
  groups_lab <- gsub("_\\d+", "", colnames(data))
  top_annotation = HeatmapAnnotation(Samples = samples_lab,
                                     Groups = groups_lab,
                                     col = list(Samples = heatmap_colors$col_samples,
                                                Groups = heatmap_colors$col_group),
                                     show_annotation_name = T,
                                     annotation_name_side = "left",
                                     annotation_name_gp = label_font_gp(),
                                     annotation_legend_param = list(
                                       title_gp = title_font_gp(),
                                       labels_gp = label_font_gp()
                                     ),
                                     show_legend = legend)
  return(top_annotation)
}

make_heatmap <- function(data, heatmap_colors){
  data_m <- as.matrix(data)
  set.seed(3)
  ht <- ComplexHeatmap::Heatmap(data_m,
                                name = "P. Level",
                                cluster_rows = TRUE,
                                cluster_columns = TRUE,
                                col = heatmap_colors$col_fun,
                                show_row_names = F,
                                show_column_names = F,
                                row_title = "Proteins",
                                row_title_gp = title_font_gp(),
                                column_title = "",
                                row_dend_width = unit(1.5, "cm"),
                                top_annotation = top_annotation(data_m, heatmap_colors),
                                heatmap_legend_param = list(
                                  title_gp = title_font_gp(),
                                  labels_gp = label_font_gp()
                                )
                              )
  dht = draw(ht,merge_legend = TRUE,newpage = FALSE)
  return(dht)
}

calculate_row_fontsize <- function(n_rows) {
  # Uses at most 12pt and at least 3pt font size for row names
  # Starting at 20 rows, the font size decreases by 1pt for every 10 rows
  return(max(12 - floor((n_rows - 20) / 10), 3))
}

make_sub_heatmap <- function(data, heatmap_colors){
  data_m <- as.matrix(data)
  row_lab <- gsub(".*,\\s*", "", rownames(data_m))
  row_font_size <- calculate_row_fontsize(length(row_lab))
  set.seed(3)
  ht <- ComplexHeatmap::Heatmap(data_m,
                                name = "P. Level",
                                cluster_rows = FALSE,
                                cluster_columns = FALSE,
                                col = heatmap_colors$col_fun,
                                show_row_names = T,
                                row_labels = row_lab,
                                row_names_gp = gpar(fontsize = row_font_size, fontfamily = font_family),
                                show_column_names = F,
                                row_title = "Proteins",
                                row_title_gp = title_font_gp(),
                                column_title = "",
                                top_annotation = top_annotation(data_m, heatmap_colors, legend = FALSE),
                                show_heatmap_legend = FALSE)
  return(draw(ht))
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
    theme_light() +
    theme(text = element_text(family = font_family, size = title_fontsize),
          axis.text.x = element_text(size = label_fontsize),
          axis.text.y = element_text(size = label_fontsize),
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
    theme(text = element_text(family = font_family, size = title_fontsize),
          axis.text.x = element_text(size = label_fontsize),
          axis.text.y = element_text(size = label_fontsize),
          legend.position = "none")
  return(p)
}
