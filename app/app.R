#' Code to run the Shiny app
#'
#' shiny::runApp('R',port = 5678)

#### Front end ####
source("R/app_ui.R")

#### Back end ####
source("R/app_server.R")

#### Serve ####
enableBookmarking(store = "url")
shinyApp(app_ui, app_server)
