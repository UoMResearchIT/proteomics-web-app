#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.

# Libraries
library(shiny)
library(shinyjs)
library(plotly)
library(markdown)

source("R/save_as_button.R")

# Custom bootstrap theme
custom_theme <- bslib::bs_theme(
  version = 5,
  bg = "#FFFFFF",
  fg = "#000000",
  primary = "#660099",
  secondary = "#999999",
  base_font = bslib::font_google("Open Sans")
)


app_ui <- function(request) {
  fluidPage(
    #### Headers ####
    useShinyjs(),
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),

    #### Content ####

    # Banner
    tag("header",
      list(
        id = "banner",
        class = "header",
        a(
          class = "header-item",
          href = "https://www.manchester.ac.uk/",
          img(
            src = "logo_col_white_background.png",
            alt = "University of Manchester logo",
            id = "uom-logo"
          )
        ),
        div(
          id = "header-title",
          class = "header-item",
          p(id = "department", "The Lennon Lab"),
          p(id = "header-appname", "proteinBASE")
        ),
        div(
          id = "github-logo-container",
          class = "header-item",
          a(
            href = "https://github.com/UoMResearchIT/proteomics-web-app",
            img(
              src = "github-mark.png",
              alt = "GitHub logo",
              id = "github-logo"
            )
          )
        )
      )
    ),

    bslib::page_navbar(
      id = "view",
      title = "proteinBASE",
      fluid = FALSE,
      collapsible = TRUE,
      lang = "en",
      theme = custom_theme,
      bg = "#660099",

      #### Landing page ####
      tabPanel("Home",
        value = "home",
        div(includeMarkdown("data/content/home.md"))
      ),
      #### Data Visualization Tool ####
      tabPanel("Data Visualization Tool",
        value = "data",
        #### Dataset and gene selection dropdown menus ####
        fluidRow(
          div(class = "container",
            div(
              selectInput(
                inputId = "dataset",
                label = "Choose a dataset:",
                choices = gsub(
                  pattern = "\\.xlsx$",
                  "",
                  list.files(
                    path = "data/datasets/",
                    pattern = "\\.xlsx$",
                    full.names = FALSE
                  ),
                )
              ),
            ),
            div(
              # Only show gene dropdown if selected tab is BoxPlot
              conditionalPanel(
                condition = "input.tab == 'BoxPlot'",
                selectizeInput("gene", "Gene:", choices = NULL)
              )
            )
          )
        ),
        #### Plot tabs ####
        fluidRow(
          tabsetPanel(
            id = "tab",
            #### PCA ####
            tabPanel("PCA",
              plotlyOutput("PCA_plot", width = 600, height = 500),
              save_as_UI("pca_save_as", 600, 500)
            ),
            #### HeatMap ####
            tabPanel("HeatMap",
              fluidRow(
                div(style = "margin: 10px 10px;",
                  selectizeInput(
                    inputId = "subh_gene",
                    label = NULL,
                    multiple = TRUE,
                    choices = NULL,
                    options = list(
                      create = TRUE,
                      placeholder = "Search for genes...",
                      onDropdownOpen = I("function($dropdown)
                        {if (!this.lastQuery.length) {
                          this.close(); this.settings.openOnFocus = false;}}"),
                      onType = I("function (str) {
                        if (str === \"\") {this.close();}}"),
                      onItemAdd = I("function() {this.close();}")
                    )
                  )
                ),
                div(class = "container", style = "column-gap: 10px;",
                  div(
                    plotOutput("heatmap",
                      width = 250,
                      height = 500,
                      brush = "heatmap_brush"
                    ),
                    save_as_UI("heatmap_save_as", 250, 500),
                  ),
                  div(
                    uiOutput("sub_heat"),
                    save_as_UI("subheat_save_as", 600, 500),
                  )
                )
              ),
            ),
            #### BoxPlot ####
            tabPanel("BoxPlot",
              fluidRow(
                div(class = "container",
                  div(
                    plotlyOutput("plot_bar", width = 500, height = 500),
                    save_as_UI("bar_save_as", 500, 500)
                  ),
                  div(
                    plotlyOutput("plot_box", width = 300, height = 500),
                    save_as_UI("box_save_as", 300, 500)
                  ),
                )
              ),
              tableOutput("near_rows_data")
            ),
            #### About the dataset ####
            tabPanel("About the dataset",
              uiOutput("dataset_info"),
            ),
          )
        ),
      ),
      #### Plot Description ####
      tabPanel("Plot Description",
        value = "plot_description",
        div(includeMarkdown("data/content/plot_description.md"))
      ),
      #### Useful Links ####
      tabPanel("Useful Links",
        value = "useful_links",
        div(includeMarkdown("data/content/useful_links.md"))
      ),
      #### Contact ####
      tabPanel("Contact",
        value = "contact",
        div(includeMarkdown("data/content/contact.md"))
      )
    )
  )
}
