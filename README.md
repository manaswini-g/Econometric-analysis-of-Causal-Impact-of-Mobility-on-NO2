# Econometric-analysis-of-Causal-Impact-of-Mobility-on-NO2
An econometric analysis in R using a 2SLS (Instrumental Variable) model to estimate the causal impact of reduced mobility on NO₂ pollution. Uses COVID-19 lockdown stringency as an instrument to address endogeneity.
# Causal Impact of COVID-19 Mobility on NO₂ Pollution

> An econometric analysis in R using a Two-Stage Least Squares (2SLS) Instrumental Variable model to measure the causal impact of COVID-19 mobility reductions on NO₂ pollution in the United States.

![R](https://img.shields.io/badge/R-276DC3?style=for-the-badge&logo=r&logoColor=white)

---

### Project Summary

This project investigates the causal relationship between human mobility and urban NO₂ pollution during the COVID-19 pandemic. While a simple correlation suggests that as mobility decreased, pollution also decreased, this relationship is plagued by **endogeneity**. For example:

* **Reverse Causality:** Do high-pollution days discourage people from going out?
* **Omitted Variable Bias:** Are other factors, like reduced industrial activity, causing *both* lower mobility and lower pollution?

To address this, this analysis employs a **Two-Stage Least Squares (2SLS) Instrumental Variable (IV)** model. We use the **Oxford COVID-19 Government Response Tracker (OxCGRT) Stringency Index** as an instrument for mobility.

### Methodology

The 2SLS approach isolates the *causal* effect by:

1.  **First Stage:** Proving that lockdown stringency (the instrument) has a strong, significant effect on mobility (the endogenous variable).
2.  **Second Stage:** Using *only* the portion of mobility that was "predicted" by lockdown stringency to estimate the effect on NO₂ pollution.

This strategy relies on the assumption that national lockdown policies affect pollution *only* through their effect on human mobility, which is supported by the data and model diagnostics.

### Key Findings

The model successfully identifies a causal link and demonstrates the importance of correcting for endogeneity.

* **Endogeneity Confirmed:** A **Hausman Test** strongly rejects the null hypothesis (p < 2.2e-16), confirming that mobility is an endogenous variable and a simple OLS model would produce biased and inconsistent results.
* **Strong Instrument:** The first-stage regression shows that the **Stringency Index** is a strong and highly significant predictor of mobility (F-statistic = 2,073.65), validating its use as an instrument.
* **Causal Effect:** The 2SLS model (Column 3) estimates a statistically significant causal coefficient of **0.092 (p < 0.01)**. This suggests that a 1-unit increase in the mobility index (i.e., people moving *more*) causally increases NO₂ concentration.

#### Regression Results
| | **(1) Naive OLS** | **(2) First Stage** | **(3) 2SLS** | **(4) 2SLS + Time FE** |
|:---|:---:|:---:|:---:|:---:|
| **Dependent Var:** | *NO₂* | *Mobility* | *NO₂* | *NO₂* |
| **Mobility** | 0.065***<br>(0.002) | | **0.092***<br>(0.004) | -1.681<br>(7.865) |
| **Stringency** | | -0.632***<br>(0.003) | | |
| **Observations** | 10,454 | 10,454 | 10,454 | 10,454 |
| **Hausman Test** | p < 2.2e-16 | | | |
| **First-Stage F-stat** | 2,073.65 | | | |

*Note: The 2SLS model with both state and week fixed effects (Column 4) becomes unstable and insignificant, likely due to high multicollinearity and reduced identifying variation, reinforcing the robustness of the primary 2SLS model (Column 3).*

### Key Visualizations

**National Trends**
This chart shows the aggregated weekly trends for NO₂ and mobility, highlighting their synchronized drop during the initial lockdowns.
![National Trends in NO2 and Mobility Over Time](visualizations/Trend%20of%20NO₂%20and%20Mobility%20Over%20Time%20(National%20Average).png)

**First Stage Relationship (Instrument Strength)**
This plot clearly shows the strong negative correlation between the Lockdown Stringency Index and actual workplace mobility.
![First Stage: Stringency vs. Mobility](visualizations/Stringency%20vs%20Mobility%20(First%20Stage%20Relationship).png)

### 📥 Data Setup

The datasets for this project are too large to be hosted on GitHub directly. Please download the three required files using the links below:

1.  **NO₂ Pollution Data:** [Download `D1_No2level.csv`](https://drive.google.com/file/d/1PgzY0a5RYPf8n5npYUy9YYfxU0LtlYqE/view?usp=sharing)
2.  **Mobility Data:** [Download `D2_US_Mobility.csv`](https://drive.google.com/file/d/1shBmS7VEd1IvKJCsdiOR_z02K7HL0KMf/view?usp=sharing)
3.  **Stringency Data:** [Download `D3_data.csv`](https://drive.google.com/file/d/12JqBbp6WeAy3B25aNHeCO6HDtZNvmJRh/view?usp=sharing)

**After downloading, please place all three `.csv` files inside the `/data` folder** (which is currently empty) in your local copy of this project. The R script is built to look for them there.

### How to Reproduce

1.  Clone this repository:
    ```bash
    git clone [https://github.com/your-username/Causal-Impact-of-Mobility-on-NO2.git](https://github.com/your-username/Causal-Impact-of-Mobility-on-NO2.git)
    ```
2.  Open the project in RStudio.
3.  Install the required libraries:
    ```R
    install.packages(c("tidyverse", "readr", "lubridate", "plm", "ivreg", "stargazer", "ggplot2", "patchwork", "ggcorrplot"))
    ```
4.  **Download the data** using the links in the "Data Setup" section and place the files in the `/data` folder.
5.  Run the main analysis script:
    ```R
    source("code/mobility_no2_analysis.R")
    ```
    The script will load the data from the `/data` folder, perform all cleaning and aggregation, run the models, and generate the visualizations.

### Technologies Used

* **R** for statistical analysis and modeling.
* **`tidyverse`** (`dplyr`, `readr`): Data manipulation and cleaning.
* **`plm`**: Panel data modeling.
* **`ivreg`**: Instrumental Variable regression.
* **`stargazer`**: Creating regression tables.
* **`ggplot2`**: Data visualization.
