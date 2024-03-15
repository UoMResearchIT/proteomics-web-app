#' MQTT client functions, triggered by minio mqtt messages.
#'
#' Files added to raw-data bucket trigger data pre-processing
#' Files deleted from raw-data bucket trigger deletion of pre-processed data.

# Libraries
library(jsonlite)

source("R/data_preprocessing.R")

data_path <- "../app/data/"

# Function to process messages
process_message <- function(message) {
  #### Parse JSON ####
  data <- tryCatch({
    fromJSON(message)
  }, error = function(e) {
    print("Received message:")
    print(message)
    print("ERROR: Cannot parse JSON:")
    print(e)
    return(NULL)
  })
  # If data is NULL, return
  if (is.null(data)) {
    return()
  }

  # Verify the keys date, time, topic and payload are present
  if (!all(c("date", "time", "topic", "payload") %in% names(data))) {
    print("Received message:")
    print(message)
    print("ERROR: Missing keys in message.")
    print("  Required keys: date, time, topic, payload.")
    return()
  }

  # Verify the keys EventName and Key are present in the payload
  if (!all(c("EventName", "Key") %in% names(data$payload))) {
    print("Received message:")
    print(message)
    print("ERROR: Missing keys in payload. Required keys: EventName, Key")
    return()
  }

  # If accessed, ignore message
  if (grepl("s3:ObjectAccessed", data$payload$EventName)) {
    return()
  }

  # Print recieved message
  print("Received message:")
  print(paste(
    data$date,
    data$time,
    data$topic,
    paste(
      "{event:",
      data$payload$EventName,
      " key:",
      data$payload$Key,
      "}",
      sep = ""
    ),
    sep = "  "
  ))

  #### Process message ####
  # Creation event for any bucket
  if (data$payload$EventName == "s3:ObjectCreated:Put") {
    on_creation(data$payload$Key)
  }
  # Deletion event for any bucket
  if (grepl("s3:ObjectRemoved:Delete", data$payload$EventName)) {
    on_deletion(data$payload$Key)
  }

  # Creation/Deletion events on raw-data dir
  if (data$topic == "minio/raw-data") {
    if (data$payload$EventName == "s3:ObjectCreated:Put") {
      on_raw_data_added(data$payload$Key)
    } else if (grepl("s3:ObjectRemoved:Delete", data$payload$EventName)) {
      on_raw_data_deleted(data$payload$Key)
    } else {
      print(paste("Nothing to do with detected event: ",
                  data$payload$EventName))
    }
  }
  # else {
  #   print(paste("Nothing to do with detected topic: ", data$topic))
  # }
}

on_creation <- function(file) {
  system(paste("mc cp ",
               "protein/", file, " ",
               data_path, file,
               sep = ""))
  print(paste("File: ", file, "added to shiny app data storage."))
}

on_deletion <- function(file) {
  system(paste("rm ",
               data_path, file,
               sep = ""))
  print(paste("File: ", file, "deleted from shiny app data storage."))
}

on_raw_data_added <- function(file) {
  file_name <- gsub("raw-data/", "", file)
  print(paste("Added raw data file: ", file_name))
  # Pre-process data
  print("Pre-processing data...")
  files <- preprocess_data(raw_data_path = paste(data_path, file, sep = ""))
  # Push each file to the minio bucket
  for (file in files) {
    print(paste("mc cp ",
                 file, " ",
                 "protein/", dirname(file),
                 sep = ""))
    system(paste("mc cp ",
                 file, " ",
                 "protein/", gsub("../app/data/", "", dirname(file)),
                 sep = ""))
  }
  print("Raw data pre-processed and pushed successfully.")
}
on_raw_data_deleted <- function(file) {
  file_name <- gsub("raw-data/", "", file)
  dataset_name <- gsub(".txt", "", file_name)
  print(paste("Deleted raw data file: ", file_name))
  # Delete related pre-processed data files
  print("Deleting related files...")
  related_files <- list(
    c("datasets", ".xlsx"),
    c("heatmaps", "_heatmap.xlsx"),
    c("pcaplots", "_pca.xlsx"),
    c("dataset-info", "_info.md")
  )
  for (rel in related_files){
    system(paste("mc rm protein/", rel[1], "/",
                 dataset_name, rel[2],
                 sep = ""))
  }
  print("Raw data and related files deleted.")
}
