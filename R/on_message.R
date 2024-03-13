#' MQTT client functions, triggered by minio mqtt messages.
#'
#' Files added to raw-data bucket trigger data pre-processing
#' Files deleted from raw-data bucket trigger deletion of pre-processed data.

# Libraries
library(jsonlite)

source(data_preprocessing)

# Function to process messages
process_message <- function(message) {
  print("Received message:")
  #### Parse JSON ####
  data <- tryCatch({
    fromJSON(message)
  }, error = function(e) {
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
    print(message)
    print("ERROR: Missing keys in message.")
    print("  Required keys: date, time, topic, payload.")
    return()
  }

  # Verify the keys EventName and Key are present in the payload
  if (!all(c("EventName", "Key") %in% names(data$payload))) {
    print(message)
    print("ERROR: Missing keys in payload. Required keys: EventName, Key")
    return()
  }

  # Print recieved message
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
  # Creation/Deletion events on raw-data dir
  if (data$topic == "raw-data") {
    if (data$payload$EventName == "s3:ObjectCreated:Put") {
      on_creation(data$payload$Key)
    } else if (grepl("s3:ObjectRemoved:Delete", data$payload$EventName)) {
      on_deletion(data$payload$Key)
    } else {
      print(paste("Nothing to do with detected event: ",
                  data$payload$EventName))
    }
  } else {
    print(paste("Nothing to do with detected topic: ", data$topic))
  }
}

on_creation <- function(file) {
  file_name <- gsub("raw-data/", "", file)
  print(paste("Added raw data file: ", file_name))
  # Pre-process data
  print("Pre-processing data...")
  files <- preprocess_data(raw_data_path = file)
  # Push each file to the minio bucket
  for (file in files) {
    system(paste("mc cp ",
                 "/tmp/", file,
                 " protein/", dirname(file),
                 sep = ""))
  }
  print("Raw data pre-processed and pushed successfully.")
}

on_deletion <- function(file) {
  file_name <- gsub("raw-data/", "", file)
  print(paste("Deleted raw data file: ", file_name))
  # Delete related pre-processed data files
  print("Deleting related files...")
  for (dir in c("datasets", "heatmaps", "pcaplots", "dataset-info")){
    system(paste("mc rm protein/", dir, "/",
                 file_name, "_*",
                 sep = ""))
  }
  print("Raw data and related files deleted.")
}
