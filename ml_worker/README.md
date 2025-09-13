# CipherX Ai powered APK cyber-security

> Lightweight toolkit to extract static features from Android APKs, train a Random Forest malware classifier, run lightweight penetration-testing heuristics and anomaly detection, and interact with the Gemini API to generate vulnerability write-ups.

---

## Project overview

This project extracts static features from APK files, trains a Random Forest classifier to distinguish benign vs malicious samples, and provides:

* a Streamlit UI to upload and analyze APKs (with on-demand Gemini write-ups), and
* standalone scripts to train, extract features, and analyze APKs.

Key components:

* Feature extraction: `apk_feature_extractor.py`.&#x20;
* Core analysis (prediction + pentest heuristics + anomaly detection): `apk_analyzer.py`.&#x20;
* Streamlit UI: `app.py`.&#x20;
* Training pipeline to build the Random Forest and artifacts: `train_apk_classifier.py`.&#x20;

---

## Features

* Static feature extraction (permissions, activities, services, intent filters, string constants, API calls, native libs).&#x20;
* Random Forest classifier training with exportable artifacts.&#x20;
* Penetration-testing heuristics to flag risky patterns (dangerous permissions, exported components, WebView/dynamic loading usage, cleartext endpoints, native libs).&#x20;
* Heuristic anomaly detection combining model uncertainty, vote dispersion and feature novelty.&#x20;
* Streamlit UI with on-demand Gemini vulnerability write-up (optional; requires Google AI API key).&#x20;

---

## Repo layout

```
.
├─ apk_feature_extractor.py      # feature extraction logic (androguard)
├─ train_apk_classifier.py       # training script (Random Forest)
├─ apk_analyzer.py               # analyzer: loads artifacts, runs checks & gemini
├─ app.py                        # Streamlit UI
├─ dataset/
│   ├─ benign/                   # put benign .apk files here
│   └─ malicious/                # put malicious .apk files here
└─ (artifacts saved after training)
```

(See each script for implementation details.)&#x20;

---

## Prerequisites

* Python 3.8+ (3.9/3.10 recommended)
* Java is **not required** for this static extractor (it uses `androguard`), but `androguard` has native/packaging dependencies.
* Typical Python packages:

  * `androguard`
  * `scikit-learn`
  * `joblib`
  * `numpy`
  * `streamlit` (for the UI)
  * `tqdm` (optional; improves progress display)
  * `google-generativeai` (optional; for Gemini writeups)
* Unix-like OS recommended for large-scale processing (memory/worker tuning).


Install:

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## Installation

1. Clone or copy the repository to your machine.
2. Create and activate a virtual environment.
3. Install dependencies (see [Prerequisites](#prerequisites)).
4. Ensure `dataset/benign` and `dataset/malicious` exist and contain `.apk` files before training.&#x20;

---

## Quick start — run the Streamlit UI

The Streamlit UI is a convenient way to upload an APK and see the model prediction, pentest findings and anomaly score.

```bash
# activate your venv
streamlit run app.py
```

* The UI uses the model artifacts produced by `train_apk_classifier.py`. If artifacts are missing it will show an error message.&#x20;
* On the sidebar you can optionally provide your Google AI (Gemini) API key to generate on-demand vulnerability writeups for matched top features.&#x20;

---

## Train the classifier 
### NOTE: already done once. no need to do it again
The training script processes APKs from `dataset/benign` and `dataset/malicious`, extracts features (using the extractor), trains a Random Forest, evaluates and saves artifacts.

Usage:

```bash
python train_apk_classifier.py
```

Important notes:

* Place `.apk` files under `dataset/benign` and `dataset/malicious` before running.&#x20;
* The script will:

  * Extract features with `apk_feature_extractor.py`.&#x20;
  * Preprocess them into a `DictVectorizer` format.
  * Train `RandomForestClassifier`.
  * Save artifacts (see next section).&#x20;

---

## Analyze a single APK (CLI)

You can use the extractor directly to dump features:

```bash
python apk_feature_extractor.py path/to/sample.apk
# This writes <sample.apk>_features.json on success.
```

(See the extractor for usage & CLI output.)&#x20;

The `apk_analyzer.py` exposes a function `analyze_apk(...)` that:

* Loads artifacts (model + vectorizer + top features),
* Extracts features,
* Predicts (Malicious/Benign),
* Runs pentest heuristics,
* Runs anomaly detection,
* Optionally uses Gemini to generate human-readable explanations.&#x20;

If you want to run an analysis programmatically:

```python
from apk_analyzer import load_artifacts, analyze_apk

model, vectorizer, top_features = load_artifacts()
result = analyze_apk("samples/foo.apk", model, vectorizer, top_features)
print(result)
```

(See `apk_analyzer.py` for return format.)&#x20;

---

## Artifacts produced by training

When training completes, the following files are saved (names come from the training script):&#x20;

* `apk_random_forest_model.joblib` — trained Random Forest model.
* `apk_feature_vectorizer.joblib` — fitted `DictVectorizer`.
* `model_performance_metrics.json` — accuracy/precision/recall/F1 and confusion matrix.
* `top_malware_features.json` — top \~100 features with importances (used for explanation).

These are the files `app.py` and `apk_analyzer.py` attempt to load at runtime.&#x20;

---

## Environment variables & configuration

* `ANDROID_FE_WORKERS` — cap worker processes used by `apk_feature_extractor.py` (defaults to min(4, cpu\_count)). Use to control memory/parallelism.&#x20;
* Gemini / Google AI API key — if you want on-demand writeups via Gemini, provide the key in the Streamlit sidebar or pass it into the `get_vulnerability_explanation` function (the Gemini code path uses `google.generativeai`).&#x20;

---


## Troubleshooting & tips

* `No APKs found` when training: ensure `dataset/benign` and `dataset/malicious` contain `.apk` files.&#x20;
* `OutOfMemory` while extracting: reduce `ANDROID_FE_WORKERS` or run fewer parallel processes.&#x20;
* If Streamlit UI complains about missing artifacts: run the training script first to create `*.joblib` and `top_malware_features.json`.&#x20;
* If Gemini generation fails, check your Google AI API key and network connectivity. The Gemini call is optional and may change depending on the `google-generativeai` client.&#x20;

---

## Security & privacy notes

* Uploaded APKs may contain sensitive/private code. Only analyze files you are permitted to handle.
* The Gemini (Google AI) write-up uses an external API — do not send private data you cannot share.&#x20;
* Model predictions are heuristic and not definitive. Use as a triage aid, not a final verdict.

---

