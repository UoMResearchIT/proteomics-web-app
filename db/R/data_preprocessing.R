#### Load libraries ####
library(tidyr)
library(openxlsx)
library(SummarizedExperiment)
library(QFeatures)
library(dplyr)
library(MsCoreUtils)
library(preprocessCore)



#### Full pre-processing pipeline ####
preprocess_data <- function(raw_data_path = "", dataset_name = "", dataset_path = "") {
  # This function triggers the full data pre-processing pipeline.
  # To go from the raw tsv file with the data, provide the `raw_data_path`.
  # The `dataset_name` is optional, and it is used to name the output files.
  # To skip the data preparation, use `dataset_path` instead of `raw_data_path`.

  # Set paths
  data_path <- "../app/data/"
  if (dataset_name == "") {
    dataset_name <- gsub(".tsv", "", basename(raw_data_path))
  }
  if (dataset_path == "") {
    prepare_dataset <- TRUE
    dataset_path <- paste(data_path, "datasets/",
                          dataset_name, ".xlsx",
                          sep = "")
  } else {
    prepare_dataset <- FALSE
    dataset_name <- gsub(".xlsx", "", basename(dataset_path))
  }
  if (dirname(dataset_path) != paste(data_path, "datasets", sep = "")) {
    old_path <- dataset_path
    dataset_path <- paste(data_path, "datasets/",
                          dataset_name, ".xlsx",
                          sep = "")
    system(paste("cp", old_path, dataset_path))
  }
  pca_data_path <- paste(data_path, "pcaplots/",
                         dataset_name, "_pca.xlsx",
                         sep = "")
  heatmaps_path <- paste(data_path, "heatmaps/",
                         dataset_name, "_heatmap.xlsx",
                         sep = "")
  files <- c(dataset_path, pca_data_path, heatmaps_path)

  # Make sure directories exist
  for (file in files){
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  }

  # Prepare dataset
  if (prepare_dataset) {
    print("Preparing dataset...")
    prepare_dataset(raw_data_path, dataset_path)
  }

  # Load protein data
  print("Loading protein data...")
  protein_data <- tryCatch({
    read.xlsx(dataset_path)
  }, error = function(e) {
    message("Error reading the Excel file:", conditionMessage(e))
  })

  # Preprocess data for plots
  print("Preprocessing data for pca plots...")
  pca_data(protein_data, pca_data_path)
  print("Preprocessing data for heatmaps...")
  heatmap_data(protein_data, heatmaps_path)
  protein_data <- protein_data |>
    pivot_longer(cols = !(Identifiers:Gene),
                 names_to = "experiment",
                 values_to = "expression")

  return(files)
}


#### Generates dataset from protein .tsv ####
prepare_dataset <- function(raw_data_path, dataset_path) {
  # This function reads the protein data .tsv file.
  # The `raw_data_path` is the path to the .tsv file with the data.
  # The `dataset_path` is the path to save the prepared dataset.

  print("  DEBUG - Generating dataset from protein .tsv...")
  print("  DEBUG - Reading the .tsv file...")
  proteins <- read.delim(raw_data_path) |> dplyr::filter(Organism != "")
  # Identify columns with quantitative expression values
  print("  DEBUG - Identifying columns with quantitative expression values...")
  ecols <- grep("_\\d+\\.Intensity", names(proteins))
  # Identify pooled samples from the data if present and remove it
  print("  DEBUG - Identifying and removing pooled samples...")
  if (any(grepl("pool", names(proteins[ecols]), ignore.case = TRUE))) {
    ecols <- ecols[!grepl("pool", names(proteins[ecols]), ignore.case = TRUE)]
  }
  # Remove entries flagged as common contaminants
  print("  DEBUG - Removing entries flagged as common contaminants...")
  contaminant_rows <- grep("contam_sp", proteins$Protein)
  proteins <- proteins[-contaminant_rows, ]
  # Create an S4 object, QFeatures type
  print("  DEBUG - Creating QFeatures object...")
  s4 <- QFeatures::readQFeatures(
    table = proteins, # protein data
    ecol = ecols, # expression indexes
    fnames = 1, # feature names
    name = "raw", # raw assay name
    sep = "\t" # separator for tabular data
  )
  # Add column with number of non-zero values to assay array
  print("  DEBUG - Adding column with number of non-zero values...")
  rowData(s4[[1]])$nNonZero <- rowSums(assay(s4[[1]]) > 0)
  # Replace zeroes with NA in S4 object
  print("  DEBUG - Replacing zeroes with NA...")
  s4 <- QFeatures::zeroIsNA(object = s4, i = "raw")
  # Remove proteins present in < 2 replicates
  print("  DEBUG - Removing proteins present in < 2 replicates...")
  s4 <- QFeatures::filterFeatures(object = s4, filter = ~nNonZero > 1)
  # Log2-transform peptide data #### ****** modified here
  print("  DEBUG - Log2-transforming peptide data...")
  s4 <- QFeatures::logTransform(
    object = s4, # S4 peptide data
    i = "raw", # raw expression matrix
    name = "log", # log assay name
    base = 2
  )
  # Normalize by median centring
  print("  DEBUG - Normalizing by median centring...")
  s4 <- normalize(
    object = s4, # S4 peptide data
    i = "log", # log expression data
    name = "norm", # norm assay name
    method = "center.median" # normalization method
  )
  # Extract summarized protein data
  print("  DEBUG - Extracting summarized protein data...")
  protein_data <- dplyr::as_tibble(assay(s4[["norm"]]))
  protein_data$Protein <- rowData(s4[["norm"]])$Protein.ID
  protein_data$Gene <- rowData(s4[["norm"]])$Gene
  protein_data$Identifiers <- rowData(s4[["norm"]])$Entry.Name
  colnames(protein_data) <- sub(".Intensity", "", colnames(protein_data))
  protein_data <- protein_data |>
    dplyr::relocate(Identifiers, Protein, Gene) |>
    dplyr::arrange(Protein)
  # Save to file
  print("  DEBUG - Saving to file...")
  openxlsx::write.xlsx(
    x = protein_data,
    file = dataset_path
  )
}


#### PCA plot ####
pca_data <- function(protein_data, pca_data_path) {
  # This function prepares the protein data for PCA plot.
  # The `protein_data` is the already loaded and prepared protein data.
  # The `pca_data_path` is the output file path.

  print("  DEBUG - Preparing data for PCA plot...")
  print("  DEBUG - Selecting numeric columns...")
  protein_pca <- protein_data |>
    dplyr::select_if(is.numeric)
  # Identify and remove rows with missing values
  print("  DEBUG - Identifying and removing rows with missing values...")
  protein_pca$nZero <- apply(protein_pca, 1, function(x) sum(is.na(x)))
  protein_pca <- protein_pca |>
    dplyr::filter(!nZero > 0)
  # Format data set as a transposed matrix
  print("  DEBUG - Formatting data set as a transposed matrix...")
  protein_pca_matrix <- t(protein_pca[, 1:(ncol(protein_pca) - 1)])
  # Save to file
  print("  DEBUG - Saving PCA data to file...")
  protein_pca_matrix <- as.data.frame(protein_pca_matrix)
  openxlsx::write.xlsx(x = protein_pca_matrix,
                       file = pca_data_path,
                       rowNames = TRUE, overwrite = TRUE)
}


#### Heatmap plot ####
heatmap_data <- function(protein_data, heatmaps_path) {
  # This function prepares the protein data for Heatmap plots.
  # The `protein_data` is the already loaded and prepared protein data.
  # The `heatmaps_path` is the output file path.

  print("  DEBUG - Preparing data for Heatmap plot...")
  print("  DEBUG - Selecting numeric columns...")
  protein_heatmap <- protein_data
  # Handle missing values in the data set
  print("  DEBUG - Handling missing values...")
  protein_heatmap$nZero <- rowSums(is.na(
    dplyr::select_if(protein_heatmap, is.numeric)
  ))
  # Exclude variables with only missing values
  print("  DEBUG - Excluding variables with only missing values...")
  total_n_var <- ncol(dplyr::select_if(protein_heatmap, is.numeric)) - 1
  if (any(protein_heatmap$nZero == total_n_var)) {
    protein_heatmap <- protein_heatmap[!protein_heatmap$nZero == total_n_var, ]
  }
  # Exclude variables with missing values > 25%
  print("  DEBUG - Excluding variables with missing values > 25%...")
  if (any(protein_heatmap$nZero > (total_n_var * 0.25))) {
    protein_heatmap <-
      protein_heatmap[protein_heatmap$nZero < (total_n_var * 0.25), ]
  }
  # Handling multiple identifiers
  print("  DEBUG - Handling multiple identifiers...")
  if (any(grepl(";", protein_heatmap$Gene) == TRUE)) {
    mult_ids <- grep(";", protein_heatmap$Gene)
    ids <- sub(";.*", "", protein_heatmap$Gene[mult_ids])
    protein_heatmap$Gene[mult_ids] <- ids
  }
  # Handling missing identifiers
  print("  DEBUG - Handling missing identifiers...")
  missing_ids <- which(is.na(protein_heatmap$Gene) | protein_heatmap$Gene == "")
  protein_heatmap$Gene[missing_ids] <- protein_heatmap$Protein[missing_ids]

  protein_heatmap <- protein_heatmap |>
    dplyr::group_by(Protein) |>
    dplyr::arrange(Identifiers) |>
    dplyr::ungroup() |>
    dplyr::select(!nZero)
  # Save to file
  print("  DEBUG - Saving Heatmap data to file...")
  openxlsx::write.xlsx(x = protein_heatmap,
                       file = heatmaps_path,
                       overwrite = TRUE)
}
