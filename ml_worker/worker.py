import sys
import os
import json
import joblib
import numpy as np
from pathlib import Path

# This allows the backend to import the worker and its dependencies
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Now, we can import your provided scripts
try:
    from apk_feature_extractor import extract_features
    from apk_analyzer import run_static_analysis, get_vulnerability_explanation
except ImportError as e:
    print(f"Error importing ML scripts: {e}", file=sys.stderr)
    print("Please ensure apk_feature_extractor.py and apk_analyzer.py are in the ml_worker directory.", file=sys.stderr)
    sys.exit(1)


class MLWorker:
    """
    Encapsulates the ML model loading and the full, live analysis pipeline.
    """

    def __init__(self):
        worker_dir = Path(__file__).parent
        model_path = worker_dir / "apk_random_forest_model.joblib"
        vectorizer_path = worker_dir / "apk_feature_vectorizer.joblib"
        features_path = worker_dir / "top_malware_features.json"

        print("Initializing ML Worker: Loading models...", flush=True)
        try:
            self.model = joblib.load(model_path)
            self.vectorizer = joblib.load(vectorizer_path)
            with open(features_path, 'r') as f:
                self.top_features = json.load(f)
            print("ML models and features loaded successfully.", flush=True)
        except FileNotFoundError as e:
            print(f"FATAL ERROR: Could not find model files in /ml_worker/: {e}", file=sys.stderr)
            print("Please place your .joblib and .json files in the /ml_worker directory and restart.", file=sys.stderr)
            self.model = None
            self.vectorizer = None
            self.top_features = []

    def _calculate_anomaly_score(self, confidence, unseen_features_count, total_features, pentest_findings):
        """
        Calculates a dynamic, rule-based anomaly score based on live analysis results.
        """
        # 1. Model Uncertainty Component (0 to 0.5)
        # Score is higher when confidence is closer to 0.5 (most uncertain)
        uncertainty_component = (1 - abs(confidence - 0.5) * 2) * 0.5

        # 2. Feature Novelty Component (0 to 0.3)
        # Score increases with the ratio of unseen features
        novelty_ratio = min(unseen_features_count / total_features, 1.0) if total_features > 0 else 0
        novelty_component = novelty_ratio * 0.3

        # 3. Pentesting Severity Component (0 to 0.2)
        severity_score = 0
        if pentest_findings:
            # Simple weighted score: High=3, Medium=2, Low=1
            weights = {'High': 3, 'Medium': 2, 'Low': 1, 'Info': 0}
            max_score = len(pentest_findings) * 3
            total_score = sum(weights.get(finding.get('severity', 'Info'), 0) for finding in pentest_findings)
            severity_score = (total_score / max_score) if max_score > 0 else 0
        severity_component = severity_score * 0.2

        # Final score is the sum of components, capped at 1.0
        final_score = min(uncertainty_component + novelty_component + severity_component, 1.0)

        components = {
            "uncertainty": float(confidence),
            "vote_std": 0.0,  # Placeholder as RandomForest doesn't directly provide this
            "novelty": novelty_ratio,
            "unseen_feature_count": unseen_features_count,
            "total_feature_count": total_features
        }
        return final_score, components

    def analyze_apk(self, apk_path: Path, filename: str, job_id: str):
        if not self.model:
            raise RuntimeError("ML Worker is not initialized. Models could not be loaded.")

        print(f"[{job_id}] Starting analysis for: {filename}", flush=True)

        # 1. Extract features
        print(f"[{job_id}] Extracting features...", flush=True)
        raw_features_dict = extract_features(str(apk_path))

        # The vectorizer expects a mapping from feature name to value (1.0 for presence)
        feature_input = {feature: 1.0 for feature in raw_features_dict.get('all_features', [])}

        # 2. Vectorize features
        print(f"[{job_id}] Vectorizing features...", flush=True)
        feature_vector = self.vectorizer.transform([feature_input])

        # 3. Make prediction
        print(f"[{job_id}] Making prediction...", flush=True)
        prediction_int = self.model.predict(feature_vector)[0]
        prediction = "Malicious" if prediction_int == 1 else "Benign"
        confidence_scores = self.model.predict_proba(feature_vector)[0]
        confidence = float(np.max(confidence_scores))

        # 4. Run pentesting heuristics
        print(f"[{job_id}] Running pentesting heuristics...", flush=True)
        pentest_results = run_static_analysis(str(apk_path), raw_features_dict)

        # 5. Calculate Anomaly Score
        print(f"[{job_id}] Calculating anomaly score...", flush=True)
        vocab = self.vectorizer.get_feature_names_out()
        unseen_features = [f for f in feature_input if f not in vocab]
        anomaly_score, anomaly_components = self._calculate_anomaly_score(
            confidence, len(unseen_features), len(feature_input), pentest_results
        )

        print(f"[{job_id}] Analysis complete. Prediction: {prediction}", flush=True)

        # 6. Assemble and return final JSON-compatible dictionary
        return {
            "job_id": job_id,
            "filename": filename,
            "prediction": prediction,
            "confidence_score": confidence,
            "matched_top_features": raw_features_dict.get('matched_malware_features', []),
            "pentest_findings": pentest_results,
            "anomaly_detection": {
                "score": anomaly_score,
                "components": anomaly_components
            }
        }

    def generate_gemini_report(self, api_key: str, vulnerabilities: list):
        """Calls the Gemini API using the function from apk_analyzer."""
        print(f"Generating Gemini report for {len(vulnerabilities)} vulnerabilities...")
        return get_vulnerability_explanation(api_key, vulnerabilities)