#### Load libraries ####
library(MSnbase)
library(msqrob2)
library(reshape2)
library(QFeatures)
library(tidyverse)
library(openxlsx)
library(readxl)
library(tidyr)

#### Full pre-processing pipeline ####
preprocess_data <- function(raw_data_path, dataset_name="") {
  # Set paths
  data_path <- "data/"
  if (dataset_name == "") {
    dataset_name <- gsub(".txt", "", basename(raw_data_path))
  }
  dataset_path <- paste(data_path, "datasets/", dataset_name, ".xlsx", sep="")
  pca_data_path <- paste(data_path, "pcaplots/", dataset_name, "_pca.xlsx", sep="")
  heatmaps_path <- paste(data_path, "heatmaps/", dataset_name, "_heatmap.xlsx", sep="")

  # Prepare dataset
  prepare_dataset(raw_data_path, dataset_path)

  # Load protein data
  protein_data <- tryCatch({
    read_excel(dataset_path) |>
      pivot_longer(cols = !(UniprotID:gene.names),
                   names_to = "experiment",
                   values_to = "expression")
  }, error = function(e) {
    message("Error reading the Excel file:", conditionMessage(e))
  })

  # Preprocess data for plots
  pca_data(protein_data, pca_data_path)
  heatmap_data(protein_data, heatmaps_path)
}

#### Generates dataset from raw txt ####
prepare_dataset <- function(raw_data_path, dataset_path) {
  peptides <- read.delim(raw_data_path)
  # Identify columns with quantitative expression values
  ecols <- grep("Intensity.", names(peptides))
  # Identify pooled samples from the data if present and remove it
  if (any(grepl("pool", names(peptides[ecols]), ignore.case = TRUE))) {
    ecols <- ecols[!grepl("pool", names(peptides[ecols]), ignore.case = TRUE)]
  }
  # Create an S4 object, QFeatures type
  s4 <- QFeatures::readQFeatures(
    table = raw_data_path, # peptide data
    ecol = ecols, # expression indexes
    fnames = 1, # feature names
    name = "raw", # raw assay name
    sep = "\t" # separator for tabular data
  )
  # Add column with number of non-zero values to assay array
  rowData(s4[[1]])$nNonZero <- rowSums(assay(s4[[1]]) > 0)
  # Replace zeroes with NA in S4 object
  s4 <- QFeatures::zeroIsNA(object = s4, i = "raw")
  # Log2-transform peptide data
  s4 <- QFeatures::logTransform(
    object = s4, # S4 peptide data
    i = "raw", # raw expression matrix
    name = "log", # log assay name
    base = 2
  )
  # Remove contaminant peptides
  s4 <- QFeatures::filterFeatures(
    object = s4,
    filter = ~Potential.contaminant != "+"
  )
  # Remove decoys
  s4 <- QFeatures::filterFeatures(object = s4, filter = ~Reverse != "+")
  # Remove proteins present in < 2 replicates
  s4 <- QFeatures::filterFeatures(object = s4, filter = ~nNonZero > 1)
  # Remove overlapping proteins
  filter <- rowData(s4[[1]])$Proteins %in%
    msqrob2::smallestUniqueGroups(rowData(s4[[1]])$Proteins)
  s4 <- s4[filter, , ]
  # Normalize by median centering
  s4 <- normalize(
    object = s4, # S4 peptide data
    i = "log", # log expression data
    name = "norm", # norm assay name
    method = "center.median" # normalization method
  )
  # Summarize peptide to protein
  s4 <- QFeatures::aggregateFeatures(
    object = s4, # S4 peptide data
    i = "norm", # normalized expression data
    name = "prot", # protein assay name
    fcol = "Proteins", # rowData variable for aggregation
    fun = MsCoreUtils::robustSummary, # quantitative aggregation function
  )
  # Extract summarized protein data
  protein_data <- dplyr::as_tibble(assay(s4[[4]]))
  protein_data$Protein <- rowData(s4[[4]])$Leading.razor.protein
  protein_data$Gene <- rowData(s4[[4]])$Gene.names
  protein_data$Identifiers <- rowData(s4[[4]])$Proteins
  colnames(protein_data) <- gsub("Intensity.", "", colnames(protein_data))
  protein_data <- protein_data |>
    dplyr::relocate(Identifiers, Protein, Gene) |>
    dplyr::arrange(Protein)
  # Save to file
  openxlsx::write.xlsx(
    x = protein_data,
    file = dataset_path
  )
}

#### PCA plot ####
pca_data <- function(protein_data, pca_data_path) {
  protein_pca <- protein_data |>
    dplyr::select_if(is.numeric)
  # Identify and remove rows with missing values
  protein_pca$nZero <- apply(protein_pca, 1, function(x) sum(is.na(x)))
  protein_pca <- protein_pca |>
    dplyr::filter(!nZero > 0)
  # Format data set as a transposed matrix
  protein_pca_matrix <- t(protein_pca[, 1:(ncol(protein_pca) - 1)])
  # Save to file
  protein_pca_df <- as.data.frame(protein_pca_matrix)
  openxlsx::write.xlsx(x = protein_pca_df,
                       file = pca_data_path,
                       rowNames = TRUE, overwrite = TRUE)
}

#### Heatmap plot ####
heatmap_data <- function(protein_data, heatmaps_path) {
  protein_heatmap <- protein_data
  # Handle missing values in the data set
  protein_heatmap$nZero <- rowSums(is.na(
    dplyr::select_if(protein_heatmap, is.numeric)
  ))
  # Exclude variables with only missing values
  total_nVar <- ncol(dplyr::select_if(protein_heatmap, is.numeric)) - 1
  if (any(protein_heatmap$nZero == total_nVar)) {
    protein_heatmap <- protein_heatmap[!protein_heatmap$nZero == total_nVar, ]
  }
  # Exclude variables with missing values > 25%
  if (any(protein_heatmap$nZero > (total_nVar * 0.25))) {
    protein_heatmap <-
      protein_heatmap[protein_heatmap$nZero < (total_nVar * 0.25), ]
  }
  # Handling multiple identifiers
  if (any(grepl(";", protein_heatmap$Gene) == TRUE)) {
    mult_ids <- grep(";", protein_heatmap$Gene)
    ids <- sub(";.*", "", protein_heatmap$Gene[mult_ids])
    protein_heatmap$Gene[mult_ids] <- ids
  }
  # Handling missing identifiers
  if (any(protein_heatmap$Gene == "") == TRUE) {
    miss_ids <- which(protein_heatmap$Gene == "")
    ids <- protein_heatmap$Protein[miss_ids]
    protein_heatmap$Gene[miss_ids] <- ids
  }
  protein_heatmap <- protein_heatmap |>
    dplyr::group_by(Protein) |>
    dplyr::arrange(Identifiers) |>
    dplyr::ungroup() |>
    dplyr::select(!nZero)
  # Save to file
  openxlsx::write.xlsx(x = protein_heatmap,
                       file = heatmaps_path,
                       overwrite = TRUE)
}
