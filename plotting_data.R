library(tidyverse)
library(ggplot2)
library(readxl)

data <- read_excel('./data/prot_final.xlsx')

# remove the index column
data2 <- data[,-1]

data_longer <- data2 |>
  pivot_longer(
    cols = !(UniprotID:gene.names), 
    names_to = "experiment", 
    values_to = "expression"
  )

data_longer |>
  filter(gene.names == 'DCAF13') |>
  ggplot(aes(x = experiment, y = expression)) +
  geom_point()
