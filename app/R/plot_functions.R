#### Load libraries ####
library(ggplot2)
library(mixOmics)
library(ComplexHeatmap)
library(circlize)
library(stringr)
library(grid)
library(dplyr)

#### Settings ####
font_family_web <- "Open Sans Local, Open Sans, Arial, sans-serif"
font_family_grid <- "sans" # grid-based plots need to use fonts from the system
# Paul Tol colorblind-safe palette
cb_palette <- c(
  "#332288",
  "#117733",
  "#AA4499",
  "#DDCC77",
  "#88CCEE",
  "#882255",
  "#44AA99",
  "#CC6677",
  "#999933",
  "#DDDDDD"
)
cb_colors <- function(n) rep_len(cb_palette, n)
title_fontsize <- 14
label_fontsize <- 13
# Separate control for complex heatmaps fonts, as they use grid graphics
title_font_gp <- function() {
  title_fonts <- gpar(fontsize = title_fontsize - 1,
                      fontface = "bold",
                      fontfamily = font_family_grid)
  return(title_fonts)
}
label_font_gp <- function(legend_labels = NULL) {
  if (is.null(legend_labels)) {
    label_fonts <- gpar(fontsize = label_fontsize - 1,
                        fontfamily = font_family_grid)
    return(label_fonts)
  }
  # Characterize size of legend to adjust font size accordingly
  longest_legend <- if (length(legend_labels) == 0) { 0 } else {
    max(nchar(legend_labels), na.rm = TRUE) }
  n_items <- length(legend_labels)
  legend_size_factor <- max(longest_legend*2, n_items*2)
  # Calculate font size and return legend parameters
  legend_fontsize <- calculate_row_fontsize(legend_size_factor)
  legend_ncol <- if (legend_fontsize <= 3) 2 else 1
  legend_key_size <- max(legend_fontsize * 0.42, 1)
  return(list(
    ncol = legend_ncol,
    labels_gp = gpar(fontsize = legend_fontsize, fontfamily = font_family_grid),
    grid_width = unit(legend_key_size, "mm"),
    grid_height = unit(legend_key_size, "mm")
  ))
}

clean_sample_label_text <- function(x) {
  gsub("_", " ", x)
}

clean_group_label_text <- function(x) {
  clean_sample_label_text(sub("_\\d+$", "", x))
}


##### Plotting scripts ####

#### TAB 1 ####
pca_plot <- function(matrix) {
  max_ncomp <- min(nrow(matrix) - 1, ncol(matrix))
  if (is.na(max_ncomp) || max_ncomp < 2) {
    return(
      ggplot() +
        annotate("text", x = 0, y = 0,
                 label = "Not enough data to compute 2 principal components") +
        theme_void()
    )
  }

  # Run PCA
  pca_protein <- mixOmics::pca(
    X = matrix,
    ncomp = max_ncomp,
    center = TRUE
  )
  # Extract from 'pca_protein' coordinates for the PCA plot
  coord <- as.data.frame(round(pca_protein$variates$X, digits = 2))
  coord$group <- as.factor(clean_group_label_text(rownames(coord)))
  coord$sampleName <- clean_sample_label_text(rownames(coord))
  # Extract labels for x and y axes
  labels.pca <- as.vector(pca_protein$cum.var)
  xlabel <- paste0("PC1, ",
                   (round((labels.pca[1] * 100),
                          digits = 2)), "%")
  ylabel <- paste0("PC2, ",
                   (round(((labels.pca[2] - labels.pca[1]) * 100),
                          digits = 2)), "%")

  # Generate 2D PCA plot
  pca_plot <-  ggplot(coord,
                      aes(x = PC1, y = PC2,
                          color = group,
                          text = paste("", sampleName))) +
    geom_point(size = 4) +
    labs(x = xlabel, y = ylabel, color = "") +
    xlim((min(coord$PC1) - 10), max(coord$PC1) + 10) +
    ylim((min(coord$PC2) - 10), max(coord$PC2) + 10) +
    theme_light() +
        theme(text = element_text(family = font_family_web, size = title_fontsize),
          axis.text.x = element_text(size = label_fontsize),
          axis.text.y = element_text(size = label_fontsize)) +
    scale_color_manual(values = cb_colors(nlevels(coord$group))) +
    guides(shape = "none")
  return(pca_plot)
}

#### TAB 2 ####
generate_heatmap_colors <- function(data) {
  x <- as.matrix(select_if(data, is.numeric))
  x_trunc <- as.vector(unique(x))
  x_trim <- x_trunc[x_trunc >= quantile(x_trunc, probs = 0.01, na.rm = TRUE) &
                      x_trunc <= quantile(x_trunc, probs = 0.99, na.rm = TRUE)]
  x_max <- which.max(x_trim)
  x_min <- which.min(x_trim)
  # Create a color function for the heatmap values
  col_fun <- circlize::colorRamp2(breaks = c(x_trim[x_min], 0, x_trim[x_max]),
                                  colors = c("blue", "white", "red"),
                                  space = "sRGB")
  # Create color lists for samples and groups labels
  samples_names <- clean_sample_label_text(colnames(x))
  samples_colors <- rainbow(length(samples_names))
  col_samples <- setNames(samples_colors, samples_names)
  group_names <- clean_group_label_text(colnames(x)) |> as.factor() |> levels()
  group_colors <- hcl.colors(length(group_names))
  col_group <- setNames(group_colors, group_names)

  return(list(col_fun = col_fun,
              col_samples = col_samples,
              col_group = col_group))
}

top_annotation <- function(data, heatmap_colors, legend = TRUE) {
  samples_lab <- clean_sample_label_text(colnames(data))
  groups_lab <- clean_group_label_text(colnames(data))
  top_annotation <- HeatmapAnnotation(
    Samples = samples_lab,
    Groups = groups_lab,
    col = list(Samples = heatmap_colors$col_samples,
               Groups = heatmap_colors$col_group),
    show_annotation_name = TRUE,
    annotation_name_side = "left",
    annotation_name_gp = label_font_gp(),
    annotation_legend_param = c(
      list(title_gp = title_font_gp()),
      label_font_gp(unique(c(samples_lab, groups_lab)))
    ),
    show_legend = legend
  )
  return(top_annotation)
}

make_heatmap <- function(data, heatmap_colors) {
  data_m <- as.matrix(select_if(data, is.numeric))
  set.seed(3)
  ht <- ComplexHeatmap::Heatmap(
    data_m,
    name = "Intensity",
    cluster_rows = TRUE,
    cluster_columns = TRUE,
    col = heatmap_colors$col_fun,
    show_row_names = FALSE,
    show_column_names = FALSE,
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
  dht <- draw(
    ht,
    merge_legend = TRUE,
    newpage = FALSE,
    padding = unit(c(2, 2, 2, 6), "mm")
  )
  return(dht)
}

calculate_row_fontsize <- function(n_rows) {
  # Uses at most 12pt and at least 3pt font size for row names
  # Starting at 20 rows, the font size decreases by 1pt for every 10 rows
  return(max(12 - floor((n_rows - 20) / 10), 3))
}

make_sub_heatmap <- function(data, heatmap_colors) {
  data_m <- as.matrix(select_if(data, is.numeric))
  row_lab <- rownames(data_m)
  row_font_size <- calculate_row_fontsize(length(row_lab))
  set.seed(3)
  ht <- ComplexHeatmap::Heatmap(
    data_m,
    name = "Intensity",
    cluster_rows = FALSE,
    cluster_columns = FALSE,
    col = heatmap_colors$col_fun,
    show_row_names = TRUE,
    row_labels = row_lab,
    row_names_gp = gpar(fontsize = row_font_size, fontfamily = font_family_grid),
    show_column_names = FALSE,
    row_title = "Proteins",
    row_title_gp = title_font_gp(),
    column_title = "",
    top_annotation = top_annotation(data_m, heatmap_colors, legend = FALSE),
    show_heatmap_legend = FALSE
  )
  return(draw(ht))
}

#### TAB 3 ####
prepare_gene_plot_data <- function(gene_dropdown, df) {
  df |>
    filter(Gene == gene_dropdown) |>
    mutate(
      experiment_label = clean_sample_label_text(experiment),
      experiment_type = clean_group_label_text(experiment)
    ) |>
    filter(!is.na(expression))
}
bar_plot <- function(gene_dropdown, df) {
  ## TODO: Sort out Warning: Removed x rows containing missing values
  if (!(gene_dropdown %in% df$Gene)) {
    return()
  }
  df_plot <- prepare_gene_plot_data(gene_dropdown, df)
  p <- ggplot(data = df_plot, aes(x = experiment_label, y = expression))
  p <- p +
    geom_bar(mapping = aes(x = experiment_label,
                           y = expression,
                           fill = experiment_type),
             stat = "identity",
             col = "black") +
    xlab("") +
    scale_y_continuous(name = "Normalized Log2-protein intensity") +
    theme_light() +
    theme(text = element_text(family = font_family_web, size = title_fontsize),
          axis.text.x = element_text(size = label_fontsize, angle = 45),
          axis.text.y = element_text(size = label_fontsize),
          legend.position = "none") +
    scale_fill_manual(values = cb_colors(length(unique(df_plot$experiment_type)))) +
    labs(NULL)
  return(p)
}
box_plot <- function(gene_dropdown, df) {
  if (!(gene_dropdown %in% df$Gene)) {
    return()
  }
  df_plot <- prepare_gene_plot_data(gene_dropdown, df)
  p <- ggplot(data = df_plot, aes(x = experiment_type, y = expression))
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
    theme(text = element_text(family = font_family_web, size = title_fontsize),
          axis.text.x = element_text(size = label_fontsize),
          axis.text.y = element_text(size = label_fontsize),
          legend.position = "none") +
    scale_fill_manual(values = cb_colors(length(unique(df_plot$experiment_type))))
  return(p)
}
