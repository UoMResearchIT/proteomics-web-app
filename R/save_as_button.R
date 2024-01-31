save_as_UI <- function(id) {
  tagList(
    #### Download Button ####
    actionButton(
      NS(id,"save_as_button"),
      label = HTML( '<i class="fa fa-images"></i> Save as...'),
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
      class = "row",
      id = NS(id,"save_as_options"),
      style = "
                                  background-color: #EFE;
                                  border: 1px solid #ddd;
                                  border-radius: 5px;
                                  padding: 10px;
                                  width: 650px;
                                  margin-left: 0px;
                                  margin-bottom: 20px;
                                  display: none;
                                ",
      column(3,
             style = "display: flex;
                                         align-items: center;
                                         justify-content: center;",
             downloadButton(
               NS(id,'download_button'),
               "Save image",
               class = "btn-info",
               style = "padding: 20px 10px;"
             )
      ),
      column(4,
             radioButtons(
               NS(id,"download_format"),
               label = "Format:",
               choices = list("png",
                              "pdf",
                              "svg"),
               selected = "png",
               inline = TRUE
             )
      ),
      column(2,
             numericInput(
               NS(id,"download_image_width"),
               label = "Width [px]",
               value = 600
             )
      ),
      column(2,
             numericInput(
               NS(id,"download_image_height"),
               label = "Height [px]",
               value = 450
             )
      ),
    ),
  )
}

save_as_Server <- function(id,dataset_name = NULL, plot = NULL, plot_tag = NULL) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$save_as_button, {
      # Toggle this "save_as_options"
      shinyjs::toggle("save_as_options")
      # Hide all other "save_as_options"
      sel <- paste("[id*=save_as_options]:not(#",id,"-save_as_options)",sep = "")
      shinyjs::hide(selector = sel)
      # Scroll to the bottom of the page
      shinyjs::runjs("window.scrollTo(0,document.body.scrollHeight);")
    })
    output$download_button <- downloadHandler(
      filename = function() {
        paste(dataset_name,"_",plot_tag,"_plot.",input$download_format,sep = "")
      },
      content = function(file) {
        w = input$download_image_width
        h = input$download_image_height
        format = input$download_format
        if (format == "png") {
          png(file, width = w, height = h, units = "px")
        } else if (format == "pdf") {
          pdf(file, width = w, height = h)
          #PLOT IS INCMPLETE!!!
        } else if (format == "svg") {
          svg(file, width = w, height = h)
          #PLOT IS INCMPLETE!!!
        }
        print(plot)
        dev.off()
      }
    )
  })
}
