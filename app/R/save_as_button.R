library(shiny)
library(shinyjs)
library(ggplot2)

save_as_ui <- function(id,
                       default_width = 600,
                       default_height = 450,
                       default_dpi = 300) {
  tagList(
    tags$head(
      tags$style(HTML(
        "
        .save_as-container {
          display: flex;
          flex-direction: row;
          align-content: flex-start;
          flex-wrap: wrap;
          row-gap: 0px;
          column-gap: 20px;
          justify-content: center;
          background-color: #EFE;
          border: 1px solid #ddd;
          border-radius: 5px;
          padding: 10px;
          margin-left: 0px;
          margin-bottom: 20px;
          max-width: 300px;
        }
        "
      )),
    ),
    #### Download Button ####
    actionButton(
      NS(id, "save_as_button"),
      label = HTML('<i class="fa fa-images"></i> Save as...'),
      tooltip = "Save image as...",
      class = "save-as",
      style = "
                                  color: #2D2;
                                  background-color: #EFE;
                                  border-color: #ddd;
                                  padding: 5px 20px",
    ),
    #### Save As Options
    div(
      class = "save_as-container",
      id = NS(id, "save_as_options"),
      style = "display: none;",
      div(
        downloadButton(
          NS(id, "download_button"),
          "Save image",
          class = "btn-info",
          style = "padding: 20px 10px;"
        )
      ),
      div(
        style = "display: none;",
        radioButtons(
          NS(id, "download_format"),
          label = "Format:",
          choices = list("png",
                         "pdf",
                         "svg"),
          selected = "png",
          inline = TRUE
        )
      ),
      div(
        numericInput(
          NS(id, "download_image_resolution"),
          label = "Resolution [dpi]",
          value = default_dpi,
          width = "120px"
        )
      ),
      div(
        style = "display: none;",
        numericInput(
          NS(id, "download_image_width"),
          label = "Width [px]",
          value = default_width,
          width = "80px"
        )
      ),
      div(
        style = "display: none;",
        numericInput(
          NS(id, "download_image_height"),
          label = "Height [px]",
          value = default_height,
          width = "80px"
        )
      ),
    ),
  )
}

save_as_server <- function(id,
                           dataset_name = NULL,
                           plot = NULL,
                           plot_tag = NULL) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$save_as_button, {
      # Toggle this "save_as_options"
      shinyjs::toggle("save_as_options")
      # Hide all other "save_as_options"
      sel <- paste(
        "[id*=save_as_options]:not(#", id, "-save_as_options)",
        sep = ""
      )
      shinyjs::hide(selector = sel)
      # Scroll to the bottom of the page
      shinyjs::runjs("window.scrollTo(0,document.body.scrollHeight);")
    })
    output$download_button <- downloadHandler(
      filename = function() {
        paste(
          dataset_name,
          "_",
          plot_tag,
          "_plot.",
          input$download_format,
          sep = ""
        )
      },
      content = function(file) {
        screen_dpi <- 72
        dpi <- input$download_image_resolution
        w <- input$download_image_width
        h <- input$download_image_height
        w <- as.integer(dpi * w / screen_dpi)
        h <- as.integer(dpi * h / screen_dpi)
        format <- input$download_format
        if (format == "png") {
          png(file, width = w, height = h, units = "px", res = dpi)
        } else if (format == "pdf") {
          pdf(file, width = w, height = h)
        } else if (format == "svg") {
          svg(file, width = w, height = h)
        }
        if (class(plot)[1] %in% c("Heatmap", "HeatmapList", "ComplexHeatmap")) {
          print(plot)
          dev.off()
          return()
        }
        ggsave(
          filename = file,
          plot = plot,
          dpi = dpi,
          # units = "px",
          # width = w,
          # height = h,
          device = format
        )
        dev.off()
      }
    )
  })
}
