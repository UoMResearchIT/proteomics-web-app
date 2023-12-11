# proteomics-web-app
FBMH project

RSE : Emma Simpson

RSE Lead : Andrew Jerrison

Academics : Mychel Morais and Rachel Lennon

## To run shiny app
Open the proteomics_app.Rproj file in Rstudio. Renv should bootstrap itself; you may need to run renv::restore() to install the required packages.

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

## How to deploy app on UoM Shiny Server

https://github.com/UoMResearchIT/r-shinysender/#usage

## Ideas to make web site have a login feature
- Add an authentication layer to your shiny apps https://paulc91.github.io/shinyauthr/

- Google authentication types for R https://code.markedmondson.me/googleAuthR/articles/google-authentication-types.html

- Only allow users with a University of Manchester account to access the server - not sure if this is possible. 

This all needs discussion with WADS team. And consideration needs to be given to the security risks of storing database of user details. 

## Idea to refactor code for more robust deployment
https://engineering-shiny.org/index.html




