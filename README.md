# Project Overview

This project consists of two main components: a web-based experiment for data collection and a data analysis pipeline for processing the collected mouse tracking data.

---

## 1. Experiment / Website

The experiment is a web application that captures user interactions (mouse movements, clicks, etc.) with a product interface.

### Files

| File | Description |
|---|---|
| `index.html` | Entry point of the experiment. Loads all other resources and defines the page structure. |
| `app.js` | Core application logic. Handles experiment flow, event listeners, and data collection. |
| `data.js` | Contains the product data used as input for the experiment. Imported by `app.js`. |
| `styles.css` | Stylesheet for the experiment interface. Referenced by `index.html`. |

### Dependencies

```
index.html
├── styles.css
├── data.js
└── app.js (requires data.js)
```

---

## 2. Data Analysis Pipeline

The analysis pipeline processes the raw mouse tracking data through a series of sequential steps. Each step builds on the output of the previous one.

### Step 1 — Normalization (`Normalization.ipynb`)

Normalizes the raw `mouse_events` data to account for differences in screen size and layout.

- **Input:** `mouse_events` (raw)
- **Output:** `mouse_events_norm`

### Step 2 — Mouse Metrics Calculation (`mouse_metrics.ipynb`)

Computes a set of mouse movement metrics from the normalized data. Produces three output files:

| Metric | Output File |
|---|---|
| Velocity + Distance | `velocity_metrics_norm.csv` |
| Submovement + Deviation | `submovement_metrics_norm.csv` |
| Hover Time | `hover_metrics.csv` |

- **Input:** `mouse_events_norm`

### Step 3 — Explorative Analysis (`Explorative Analysis.ipynb`)

Explores the data visually and extracts additional behavioural features.

1. **Mouse Trajectory Visualization** — Color-coded by velocity (no file output, visual only)
2. **Direction Changes** → `direction_changes.csv`
3. **Pause Analysis** → `pause_analysis.csv` + pause visualizations

- **Input:** Outputs from Steps 1 and 2

### Step 4 — Statistical Analysis (`Statistical Analysis.Rmd`)

Performs data cleaning, preparation, and statistical modelling in R.

- **Input:** CSV outputs from Steps 2 and 3
- **Output:** Statistical results and reports

### Pipeline Overview

```
mouse_events (raw)
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
  ▼
[Step 4] Statistical Analysis.Rmd
     → statistical results & reports
```
