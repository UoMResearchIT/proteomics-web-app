#' MQTT client loop, listening to minio mqtt messages.
#'


# Load necessary libraries
library(jsonlite)
library(processx)

source("R/on_message.R")

run_mqtt_client <- function() {
  passwd <- readLines("config/.secret_passwd")
  # Start MQTT client
  mqtt_client <- process$new(
    "mosquitto_sub",
    args = c(
      "-u", "proteinBASE",
      "-P", passwd,
      "-t", "#",
      "-F", '{"date":"@Y-@m-@d","time":"@H:@M:@S","topic":"%t","payload":%p}'
    ),
    stdout = "|"
  )

  # Listen for messages
  while (TRUE) {

    # print("Waiting for messages...")
    tryCatch({
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