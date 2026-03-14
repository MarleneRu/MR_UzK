# Project Overview

This project consists of two main components: a web-based experiment for data collection and a data analysis pipeline for processing the collected mouse tracking data.

---

## 1. Experiment / Website

The experiment is a web-based e-commerce simulation in which participants complete a product selection task while their mouse movements are recorded. Additionally, questionnaire responses and demographic information are collected.

### Files

| File | Description |
|---|---|
| `index.html` | Entry point. Loads all resources and provides the `<main id="app">` mount point. |
| `app.js` | Core application logic. Runs the entire experiment as a single-page app. |
| `data.js` | Contains the product data used as input for the experiment. Imported by `app.js`. |
| `styles.css` | Stylesheet for the experiment interface. Referenced by `index.html`. |

### Dependencies

```
index.html
├── styles.css
├── supabase-js (loaded via CDN)
├── data.js
└── app.js
```

---

## 2. Data Storage (Supabase)

All experiment data is collected and stored in a Supabase database. The following raw data tables can be exported as CSV files:

| Table | Description |
|---|---|
| `participants.csv` | Participant metadata: Participant metadata: ID, assigned condition (load × interest), Task 1 category ratings, assigned category for Task 2, and selected product. |
| `demographics.csv` | Age, gender, education, and employment status per participant. |
| `questionnaires.csv` | Questionnaire responses: PAAS, NRQ, PIES, and ECM.  |
| `mouse_events.csv` | Raw mouse movement events (x-y coordinates, timestamps etc.) |
| `mouse_hovers.csv` | Raw mouse hover events over products (product ID, entry time, exit time, hover duration etc.) |

---

## 3. Data Analysis Pipeline

The analysis pipeline processes the raw data exported from Supabase through a series of sequential steps. Each step builds on the output of the previous one.

### Step 1 — Normalization (`Normalization.ipynb`)

Normalizes the raw `mouse_events` data to account for differences in screen resolutions.

- **Input:** `mouse_events.csv` (raw)
- **Output:** `mouse_events_norm.csv`

### Step 2 — Mouse Metrics Calculation (`Mouse_Metrics.ipynb`)

Computes the five mouse movement metrics from the normalized data. Produces three output files:

| Metric(s) | Output File |
|---|---|
| Velocity + Distance | `velocity_metrics_norm.csv` |
| Submovement + Deviation | `submovement_metrics_norm.csv` |
| Hover Time | `hover_metrics.csv` |

- **Inputs:** `mouse_events_norm.csv`, `mouse_hovers.csv`, `participants.csv`

### Step 3 — Explorative Analysis (`Supplementary_Analysis.ipynb`)

Explores the data visually and extracts additional behavioural features.

1. **Mouse Trajectory Visualization** — Color-coded by velocity (no file output, visual only)
2. **Direction Changes** → `direction_changes.csv`
3. **Pause Analysis** → `pause_analysis.csv` + pause visualizations
4. **Velocities by Phase** → `velocity_by_phase.csv`

- **Inputs:** `mouse_events_norm.csv`, `mouse_hovers.csv`, `participants.csv`, `submovement_metrics_norm.csv`

### Step 4 — Statistical Analysis (`Statistical_Analysis.Rmd`)

Performs data cleaning, preparation, and statistical modelling in R.

- **Input:** Raw Supabase exports (`participants.csv`, `demographics.csv`, `questionnaires.csv`) and CSV outputs from Steps 1 to 3
- **Output:** Statistical results and plots

### Pipeline Overview

```
Supabase
  │  → participants.csv
  │  → demographics.csv
  │  → questionnaires.csv
  │  → mouse_events.csv
  │  → mouse_hovers.csv
  │
  ▼
[Step 1] Normalization.ipynb
  │  → mouse_events_norm
  ▼
[Step 2] mouse_metrics.ipynb
  │  → velocity_metrics_norm.csv
  │  → submovement_metrics_norm.csv
  │  → hover_metrics.csv
  ▼
[Step 3] Explorative Analysis.ipynb
  │  → direction_changes.csv
  │  → pause_analysis.csv
  │  → trajectory & pause visualizations
  │  → velocity_by_phase.csv

  ▼
[Step 4] Statistical Analysis.Rmd
     → statistical results & plots
```
