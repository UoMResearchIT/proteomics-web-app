# proteomics-web-app
FBMH project

RSE : Emma Simpson

RSE Lead : Andrew Jerrison

Academics : Mychel Morais and Rachel Lennon

## To run shiny app
Open the Rproj in protometrics_app with RStudio

Open app.R and use the 'Run App' button in the RStudio toolbar to launch the app.

## Tour of the app
Title: 'Lennon Lab Proteomic data archive'

This is set in app.R line 16 titlePanel

Choose a dataset: - the items in this dropdown are from the contents of ./data (only .xlsx files are listed)

Gene: - the items in this dropdown are from the contents of the choosen dataset

Tabs - BoxPlot, PCA, HeatMap, Correlation

The code for these plots is in plot_functions.R

## Description of .R files

### app.R
Contains the ui and server logic and runs shinyApp(ui, server).

ui - determines the app layout

server - contains the reactive logic and functionality of the app

### plot_functions.R
Contains the business logic of the app, code for making the plots. 

### ./data
Place all datasets here. They should be .xlsx files and follow the same format as the cell_prot_final and prot_final demo files. The name to be displayed in the dropdown menu of 'Choose a dataset' should be the same as the name of the file. 


