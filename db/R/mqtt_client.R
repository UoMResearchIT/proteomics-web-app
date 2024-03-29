#' MQTT client loop, listening to minio mqtt messages.
#'


# Load necessary libraries
library(jsonlite)
library(processx)
library(crayon)

source("R/on_message.R")

run_mqtt_client <- function() {
  passwd <- readLines("config/.secret_passwd")
  # Start MQTT client
  print("Starting MQTT client...")
  retry <- TRUE
  while (retry) {
    mqtt_client <- process$new(
      "mosquitto_sub",
      args = c(
        "-h", "rabbitmq",
        "-u", "proteinBASE",
        "-P", passwd,
        "-t", "#",
        "-F", '{"date":"@Y-@m-@d","time":"@H:@M:@S","topic":"%t","payload":%p}'
      ),
      stdout = "|"
    )
    Sys.sleep(1)
    if (mqtt_client$is_alive()) {
      print("MQTT client connected successfully, listening for messages...")
      retry <- FALSE
    } else {
      print("MQTT client failed to connect, retrying...")
    }
  }

  consecutive_not_alive <- 0
  # Listen for messages
  while (TRUE) {
    # if (!exists("i")) { i <- 0 }; i <- i + 1; print(paste(i, "Waiting for messages..."))
    tryCatch({
      if (!mqtt_client$is_alive()) {
        consecutive_not_alive <- consecutive_not_alive + 1
      } else {
        consecutive_not_alive <- 0
      }
      if (consecutive_not_alive >= 10) {
        print("Lost MQTT client connection, exiting...")
        break
      }
      # Read line from MQTT client
      lines <- mqtt_client$read_output_lines()

      # Process message if line is not NA or length 0
      if (length(lines) > 0) {
        for (line in lines) {
          process_message(line)
        }
      }
    }, error = function(e) {
      print(crayon::red("UNHANDLED ERROR:"))
      print(crayon::red(e))
    })
    # sleep for 1 second
    Sys.sleep(1)
  }
}
# # Example message for new file in datasets
# minio/datasets {
#   "EventName": "s3:ObjectCreated:Put",
#   "Key": "datasets/1.txt",
#   "Records": [{...}]
# }

# # Example message for deleted file file from datasets
# minio/datasets {
#   "EventName": "s3:ObjectRemoved:Delete",
#   "Key": "datasets/1.txt",
#   "Records": [{...}]
# }

# # This runs the MQTT client if the file is called with Rscript, but not when sourced
# if (!interactive()) {
#   run_mqtt_client()
# }
