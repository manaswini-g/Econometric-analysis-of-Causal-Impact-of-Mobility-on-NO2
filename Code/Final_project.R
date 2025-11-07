
library(tidyverse)    # Data manipulation
library(readr)        # Data import
library(lubridate)    # Date handling
library(plm)          # Panel data models
library(ivreg)        # IV regression
library(stargazer)    # Regression tables
library(ggplot2)      # Plots
library(patchwork)    
library(ggcorrplot)    

# =============================================
# Loading the datasets and Final dataset creation
# =============================================


# --- NO₂ Data (EPA) ---
no2_data <- read_csv("~/econometrics/Project/Datasets/D1_No2level.csv") %>%
  select(
    date = `Date Local`,
    state = `State Name`,
    county = `County Name`,
    no2 = `Arithmetic Mean`
  ) %>%
  mutate(
    # Explicitly parse dd-mm-yyyy format
    date = dmy(date),
    county = str_remove(county, " County"),
    state = str_to_upper(state)
  ) %>%
  drop_na() %>%
  group_by(state, county, date) %>%
  summarize(no2 = mean(no2, na.rm = TRUE), .groups = "drop")

# --- Mobility Data (Google) ---
mobility_data <- read_csv("~/econometrics/Project/Datasets/D2_US_Mobility.csv") %>%
  filter(country_region_code == "US", !is.na(sub_region_2)) %>%
  select(
    state = sub_region_1,
    county = sub_region_2,
    date,
    mobility = workplaces_percent_change_from_baseline
  ) %>%
  mutate(
    # Explicitly parse dd-mm-yyyy format
    date = dmy(date),
    county = str_remove(county, " County"),
    state = str_to_upper(state)
  ) %>%
  group_by(state, county, date) %>%
  summarize(mobility = mean(mobility, na.rm = TRUE), .groups = "drop")

# --- Lockdown Stringency (OxCGRT) ---
stringency_data <- read_csv("~/econometrics/Project/Datasets/D3 data.csv") %>%
  select(date = Date, stringency = StringencyIndex_Average) %>%
  mutate(
    # Parse yyyymmdd format (e.g., "20200315" = March 15, 2020)
    date = ymd(date)
  )

# Merging all datasets 
final_data <- no2_data %>%
  # Merge mobility data by state + county + date
  inner_join(mobility_data, by = c("state", "county", "date")) %>%
  # Merge stringency data by date (national-level)
  left_join(stringency_data, by = "date") %>%
  # Remove rows with missing values
  drop_na()

# Aggregating final dataset by week to reduce complexity
final_data_ag <- final_data %>%
  mutate(week = floor_date(date, unit = "week")) %>%
  group_by(state, county, week) %>%
  summarize(across(c(no2, mobility, stringency), mean, na.rm = TRUE), 
            .groups = "drop")
final_data_ag <- final_data_ag %>%
  mutate(week = as.factor(week)) 


# =============================================
# Descriptive statistics
# =============================================


# Summary statistics table  
desc_stats <- final_data %>%
  select(no2, mobility, stringency) %>%
  summarise(across(everything(), 
                   list(mean = ~mean(., na.rm = TRUE),
                        sd = ~sd(., na.rm = TRUE),
                        min = ~min(., na.rm = TRUE),
                        max = ~max(., na.rm = TRUE),
                        q25 = ~quantile(., 0.25, na.rm = TRUE),
                        q75 = ~quantile(., 0.75, na.rm = TRUE),
                        n = ~sum(!is.na(.))))) %>%
  pivot_longer(everything(), 
               names_to = c("Variable", ".value"), 
               names_sep = "_") %>%
  mutate(across(where(is.numeric), ~round(., 2)))

knitr::kable(desc_stats, 
             caption = "Descriptive Statistics of Key Variables")

# State-Level Summary Table
state_stats <- final_data %>%
  group_by(state) %>%
  summarize(
    `Mean NO₂` = mean(no2, na.rm = TRUE),
    `Mean Mobility` = mean(mobility, na.rm = TRUE),
    `Obs Count` = n()
  ) %>%
  arrange(desc(`Mean NO₂`)) %>%
  mutate(across(where(is.numeric), ~round(., 2)))

knitr::kable(state_stats, 
             caption = "State-Level Averages")

# Correlation matrix
final_data_ag %>% 
  select(no2, mobility, stringency) %>% 
  cor(use = "complete.obs")

# --------- Visulaizations ---------------

# A. Correlation plot
cor_plot <- final_data_ag %>%
  select(no2, mobility, stringency) %>%
  cor(use = "complete.obs") %>%
  ggcorrplot::ggcorrplot(method = "circle", 
                         title = "Correlation Matrix")
print(cor_plot)

# B. Trend of NO₂ and Mobility Over Time (National Average)
national_trends <- final_data_ag %>%
  group_by(week) %>%
  summarise(
    no2 = mean(no2, na.rm = TRUE),
    mobility = mean(mobility, na.rm = TRUE)
  )

# Plot both on dual axis
library(scales)
ggplot(national_trends, aes(x = as.Date(week))) +
  geom_line(aes(y = no2, color = "NO2"), size = 1.2) +
  geom_line(aes(y = mobility / 10, color = "Mobility (scaled)"), size = 1.2, linetype = "dashed") +
  scale_y_continuous(name = "NO₂ Levels", 
                     sec.axis = sec_axis(~.*10, name = "Mobility Change (%)")) +
  labs(title = "National Trends in NO2 and Mobility Over Time",
       x = "Week", color = "Legend") +
  theme_minimal()

# C. Scatterplot: Mobility vs NO₂ (with linear fit)

ggplot(final_data_ag, aes(x = mobility, y = no2)) +
  geom_point(alpha = 0.4, color = "steelblue") +
  geom_smooth(method = "lm", se = FALSE, color = "darkred") +
  labs(title = "NO2 vs Mobility (Aggregated by Week)",
       x = "Mobility Change (%)",
       y = "NO2 Concentration") +
  theme_minimal()

# D. Boxplot of NO₂ by State (Top 10 Polluted States Only)

top_states <- final_data_ag %>%
  group_by(state) %>%
  summarise(avg_no2 = mean(no2, na.rm = TRUE)) %>%
  arrange(desc(avg_no2)) %>%
  slice_head(n = 10) %>%
  pull(state)

final_data_ag %>%
  filter(state %in% top_states) %>%
  ggplot(aes(x = reorder(state, no2, FUN = median), y = no2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "NO2 Distribution in Top 10 States",
       x = "State",
       y = "NO2 Concentration") +
  theme_minimal()

#Stringency vs Mobility (First Stage Relationship)

ggplot(final_data_ag, aes(x = stringency, y = mobility)) +
  geom_point(alpha = 0.4, color = "steelblue") +
  geom_smooth(method = "lm", se = FALSE, color = "darkred") +
  labs(
    title = "First Stage: Stringency vs. Mobility",
    x = "Lockdown Stringency Index",
    y = "Mobility Change (%)"
  ) +
  theme_minimal()


# Residual Plot from First Stage Regression
first_stage_lm <- lm(mobility ~ stringency + factor(state) + factor(week), 
                     data = final_data_ag)
residuals_df <- data.frame(
  fitted = fitted(first_stage_lm),
  residuals = resid(first_stage_lm)
)

ggplot(residuals_df, aes(x = fitted, y = residuals)) +
  geom_point(alpha = 0.5, color = "purple") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(
    title = "Residual Plot: First Stage Regression",
    x = "Fitted Mobility",
    y = "Residuals"
  ) +
  theme_minimal()


# =============================================
#  MODEL ESTIMATION
# =============================================

# Convert to panel data format
final_pdata_ag <- pdata.frame(final_data_ag, index = c("county", "week"))  

# ---- Naive Approach (likely biased)----

naive_model <- plm(no2 ~ mobility + factor(state),
                   data = final_pdata_ag,
                   model = "within")

# ---- First Stage Regression ----
first_stage <- plm(mobility ~ stringency + factor(state),
                   data = final_pdata_ag,
                   model = "within")

# Check instrument strength (F-stat > 10)
summary(first_stage)  # Look at F-statistic

# ---- 2SLS IV Regression ----
iv_model <- ivreg(no2 ~ mobility + factor(state) | 
                    stringency + factor(state),
                  data = final_data_ag)

# With time fixed effects
iv_timefe <- ivreg(no2 ~ mobility + factor(state) + factor(week) | 
                     stringency + factor(state) + factor(week),
                   data = final_data_ag)


# =============================================
# DIAGNOSTIC TESTS
# =============================================

# Hausman test for endogeneity
library(lmtest)
hausman_test <- phtest(no2 ~ mobility + factor(state), 
                       data = final_pdata_ag)
print(hausman_test)  # p < 0.05 suggests endogeneity



# =============================================
# RESULTS
# =============================================

# Regression tables
library(stargazer)
stargazer(naive_model, first_stage, iv_model, iv_timefe,
          type = "text",
          title = "Regression Results",
          column.labels = c("Naive OLS", "First Stage", "2SLS", "2SLS+TimeFE"),
          dep.var.labels = c("NO₂", "Mobility", "NO₂", "NO₂"),
          covariate.labels = c("Mobility", "Stringency"),
          notes = c("Standard errors in parentheses",
                    paste("Hausman test p-value:", round(hausman_test$p.value, 3))))


# Marginal effects plot
library(margins)
marginal_effects <- margins(iv_model, variables = "mobility")
plot(marginal_effects, main = "Marginal Effect of Mobility on NO₂")

# First stage visualization
ggplot(final_data_ag, aes(x = stringency, y = mobility)) +
  geom_point(alpha = 0.3) +
  geom_smooth(method = "lm", color = "darkgreen") +
  labs(title = "First Stage: Stringency → Mobility",
       x = "Lockdown Stringency Index",
       y = "Mobility Change (%)") +
  theme_minimal()

# =============================================
# SENSITIVITY ANALYSIS for IV estimates
# =============================================

# A. Sensitivity for Fixed Effects

# Model with only state FE
iv_state <- ivreg(no2 ~ mobility + factor(state) | stringency + factor(state),
                  data = final_data_ag)

# Model with state and week FE (your main model)
iv_state_week <- ivreg(no2 ~ mobility + factor(state) + factor(week) | 
                         stringency + factor(state) + factor(week),
                       data = final_data_ag)

# Model without any fixed effects
iv_nofe <- ivreg(no2 ~ mobility | stringency,
                 data = final_data_ag)

# Compare
stargazer(iv_nofe, iv_state, iv_state_week,
          type = "text",
          column.labels = c("No FE", "State FE", "State + Week FE"),
          title = "Sensitivity to Fixed Effects")

# B. Subsample Analysis : e.g., high vs. low pollution states.
# Create a binary flag: high NO2 states
state_mean_no2 <- final_data_ag %>%
  group_by(state) %>%
  summarize(mean_no2 = mean(no2)) %>%
  mutate(high_pollution = mean_no2 > median(mean_no2))

# Merge back
final_data_ag <- final_data_ag %>%
  left_join(state_mean_no2 %>% select(state, high_pollution), by = "state")

# Run separate models
iv_high <- ivreg(no2 ~ mobility + factor(state) + factor(week) | 
                   stringency + factor(state) + factor(week),
                 data = filter(final_data_ag, high_pollution == TRUE))

iv_low <- ivreg(no2 ~ mobility + factor(state) + factor(week) | 
                  stringency + factor(state) + factor(week),
                data = filter(final_data_ag, high_pollution == FALSE))

stargazer(iv_high, iv_low,
          type = "text",
          column.labels = c("High Pollution States", "Low Pollution States"),
          title = "Subsample Sensitivity by Pollution Level")
