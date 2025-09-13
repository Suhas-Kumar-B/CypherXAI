# apk_analyzer.py
#
# Enhancements:
# - Adds penetration testing heuristics based on extracted static features
# - Adds anomaly detection using model uncertainty, vote dispersion and feature novelty vs vectorizer vocab
# - Fixes Gemini API key usage (uses the provided key, removes hardcoded key)
#
# Dependencies:
# - scikit-learn, joblib, androguard, google-generativeai, numpy

import os
import sys
import json
import re
import joblib
import numpy as np
import google.generativeai as genai
from ml_worker.apk_feature_extractor import extract_features
from ml_worker.train_apk_classifier import preprocess_features  # Re-using the same preprocessor

# --- Configuration ---
MODEL_PATH = 'apk_random_forest_model.joblib'
VECTORIZER_PATH = 'apk_feature_vectorizer.joblib'
TOP_FEATURES_PATH = 'top_malware_features.json'


def load_artifacts():
    """
    Loads the trained model, vectorizer, and top features list from disk.

    Returns:
        tuple: (model, vectorizer, top_features_dict) or (None, None, None)
    """
    try:
        model = joblib.load(MODEL_PATH)
        vectorizer = joblib.load(VECTORIZER_PATH)
        with open(TOP_FEATURES_PATH, 'r') as f:
            top_features = json.load(f)
        return model, vectorizer, top_features
    except FileNotFoundError as e:
        print(f"Error: Missing artifact - {e.filename}", file=sys.stderr)
        print("Please run 'train_apk_classifier.py' first.", file=sys.stderr)
        return None, None, None


# ----------------------------
# Penetration Testing Heuristics
# ----------------------------

def _has_regex(strings, pattern):
    try:
        rx = re.compile(pattern)
        return any(rx.search(s or "") for s in strings)
    except re.error:
        return False


def run_pentest_checks(raw_features):
    """
    Lightweight static checks to highlight risky configuration and code-use.
    Returns a list of findings: [{id, title, severity, evidence, recommendation}]
    """
    findings = []
    perms = set(raw_features.get('permissions', []) or [])
    acts = raw_features.get('activities', []) or []
    srvs = raw_features.get('services', []) or []
    rcvs = raw_features.get('receivers', []) or []
    intents = raw_features.get('intent_filters', {}) or {}
    strings = raw_features.get('strings', []) or []
    apis = raw_features.get('api_calls', []) or []
    libs = raw_features.get('native_libraries', []) or []

    # 1) Dangerous permissions
    dangerous_perms = {
        'android.permission.SEND_SMS',
        'android.permission.READ_SMS',
        'android.permission.RECEIVE_SMS',
        'android.permission.CALL_PHONE',
        'android.permission.READ_CALL_LOG',
        'android.permission.WRITE_CALL_LOG',
        'android.permission.READ_CONTACTS',
        'android.permission.WRITE_CONTACTS',
        'android.permission.RECORD_AUDIO',
        'android.permission.CAMERA',
        'android.permission.WRITE_SETTINGS',
        'android.permission.SYSTEM_ALERT_WINDOW',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.WRITE_EXTERNAL_STORAGE',
        'android.permission.REQUEST_INSTALL_PACKAGES',
    }
    present_dangerous = sorted(list(perms & dangerous_perms))
    if present_dangerous:
        findings.append({
            'id': 'P1',
            'title': 'Dangerous permissions requested',
            'severity': 'High',
            'evidence': present_dangerous,
            'recommendation': 'Request only permissions strictly needed; consider scoped storage and runtime permission prompts with justification.'
        })

    # 2) Exported components without permission protection (heuristic)
    # If an intent filter exists, components are often implicitly exported (older targets)
    exported_components = []
    for comp_type in ['activity', 'service', 'receiver']:
        for m in intents.get(comp_type, []):
            # each m is {component_name: filters}
            for comp, filters in m.items():
                actions = filters.get('action', []) if isinstance(filters, dict) else []
                if actions:
                    exported_components.append(comp)
    if exported_components:
        findings.append({
            'id': 'P2',
            'title': 'Exported components with intent-filters',
            'severity': 'Medium',
            'evidence': sorted(exported_components),
            'recommendation': 'Add android:exported="false" where appropriate or require permissions/signature-level checks; validate intents.'
        })

    # 3) WebView JS bridge / cleartext indicators
    risky_api_markers = [
        'Landroid/webkit/WebView;->addJavascriptInterface',
        'Ljava/net/HttpURLConnection;->',
        'Lokhttp3/OkHttpClient;->',
        'Ldalvik/system/DexClassLoader;->',  # dynamic code loading
    ]
    risky_api_hits = sorted([a for a in apis if any(m in a for m in risky_api_markers)])
    if risky_api_hits:
        findings.append({
            'id': 'P3',
            'title': 'Risky API usage (WebView/Network/Dynamic loading)',
            'severity': 'Medium',
            'evidence': risky_api_hits[:50],
            'recommendation': 'Avoid JS bridges or restrict to trusted contexts; enforce TLS; avoid dynamic code loading; enable network security config.'
        })

    # 4) Cleartext endpoints in strings
    if _has_regex(strings, r'http://[A-Za-z0-9\.-]+'):
        matches = [s for s in strings if 'http://' in (s or '')]
        findings.append({
            'id': 'P4',
            'title': 'Cleartext (HTTP) endpoints found in strings',
            'severity': 'Medium',
            'evidence': matches[:20],
            'recommendation': 'Migrate all endpoints to HTTPS; enforce cleartextTrafficPermitted=false in Network Security Config.'
        })

    # 5) Native libs present
    if libs:
        findings.append({
            'id': 'P5',
            'title': 'Native libraries detected',
            'severity': 'Info',
            'evidence': sorted(libs),
            'recommendation': 'Harden NDK code with stack canaries, RELRO/PIE, and avoid dynamic loading of untrusted code.'
        })

    return findings


# ----------------------------
# Anomaly Detection (no retraining)
# ----------------------------

def _forest_vote_stats(model, X):
    try:
        votes = np.array([est.predict(X)[0] for est in getattr(model, 'estimators_', [])])
        if votes.size == 0:
            return 0.0, 0.0
        return float(votes.mean()), float(votes.std())
    except Exception:
        return 0.0, 0.0


def detect_anomalies(processed_features, vectorizer, model, feature_vector):
    """
    Heuristic anomaly scoring combining:
      - Model uncertainty (1 - max(class_proba))
      - Ensemble vote dispersion (std of tree votes)
      - Feature novelty: fraction of feature keys unseen by vectorizer vocab
    Returns: dict with score in [0,1], level, and components.
    """
    # Uncertainty
    try:
        proba = model.predict_proba(feature_vector)[0]
        confidence = float(max(proba))
        uncertainty = 1.0 - confidence  # 0 (certain) .. 1 (uncertain)
    except Exception:
        uncertainty = 0.5

    # Vote dispersion
    vote_mean, vote_std = _forest_vote_stats(model, feature_vector)

    # Feature novelty (keys not in vocabulary)
    vocab = set(getattr(vectorizer, 'feature_names_', None) or vectorizer.get_feature_names_out())
    keys = set(processed_features[0].keys())
    unseen = [k for k in keys if k not in vocab]
    novelty = len(unseen) / max(1, len(keys))

    # Combined score (weights can be tuned)
    score = 0.5 * uncertainty + 0.3 * min(1.0, vote_std) + 0.2 * novelty

    if score >= 0.7:
        level = 'High'
    elif score >= 0.4:
        level = 'Medium'
    else:
        level = 'Low'

    return {
        'score': round(float(score), 3),
        'level': level,
        'components': {
            'uncertainty': round(float(uncertainty), 3),
            'vote_std': round(float(vote_std), 3),
            'novelty': round(float(novelty), 3),
            'unseen_feature_count': len(unseen),
            'total_feature_count': len(keys),
        },
        'notes': 'Higher scores indicate the sample is atypical relative to the training distribution; investigate further.'
    }


# ----------------------------
# Core analysis
# ----------------------------

def analyze_apk(apk_path, model, vectorizer, top_malware_features, *, run_pentest=True, run_anomaly=True):
    """
    Performs a full analysis of a single APK file.

    Args:
        apk_path (str): Path to the APK file
        model: Trained classifier
        vectorizer: Fitted DictVectorizer
        top_malware_features (dict): Feature->importance map
        run_pentest (bool): Include penetration tests
        run_anomaly (bool): Include anomaly detection

    Returns: dict with prediction, scores, and optional sections
    """
    print(f"Analyzing {apk_path}...")

    # 1. Extract features
    raw_features = extract_features(apk_path)
    if not raw_features:
        return {"error": "Could not extract features from the APK."}

    # 2. Preprocess (same as training)
    processed_features = preprocess_features([raw_features])

    # 3. Vectorize
    feature_vector = vectorizer.transform(processed_features)

    # 4. Predict
    prediction = model.predict(feature_vector)[0]
    prediction_proba = model.predict_proba(feature_vector)[0]

    result = {
        'file_name': os.path.basename(apk_path),
        'prediction': 'Malicious' if prediction == 1 else 'Benign',
        'confidence_score': float(prediction_proba[1] if prediction == 1 else prediction_proba[0]),
        'vulnerabilities_found': [],
        'pentest_findings': [],
        'anomaly_detection': None
    }

    # 5. If malicious, identify which high-risk features are present
    if prediction == 1:
        present_features = set(processed_features[0].keys())
        top_features_set = set(top_malware_features.keys())
        found_vulnerabilities = present_features.intersection(top_features_set)
        result['vulnerabilities_found'] = sorted(list(found_vulnerabilities))

    # 6. Optional: penetration tests
    if run_pentest:
        result['pentest_findings'] = run_pentest_checks(raw_features)

        # 7. Optional: anomaly detection
    if run_anomaly:
        result['anomaly_detection'] = detect_anomalies(processed_features, vectorizer, model, feature_vector)

    return result


def get_vulnerability_explanation(api_key, vulnerabilities):
    """
    Uses the Gemini API to generate explanations and fixes for vulnerabilities.

    Args:
        api_key (str): Google AI API key
        vulnerabilities (list[str]): Feature names identified as vulnerabilities

    Returns: Markdown string
    """
    if not vulnerabilities:
        return "No specific high-risk features were detected to generate a report."

    try:
        if not api_key:
            raise ValueError("Missing Google AI API key.")
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-2.5-flash')

        prompt = f"""
        As a mobile security expert, analyze the following static features detected in an Android APK file. These features are associated with malicious applications.

        For each feature, explain the potential security risk and propose concrete mitigation steps.

        Respond in Markdown with a heading per feature.

        Vulnerabilities Detected:
        {', '.join(vulnerabilities)}
        """
        response = model.generate_content(prompt)
        # The google.generativeai client may return an object with a `.text` attribute,
        # or a string-like representation — handle both.
        return getattr(response, "text", str(response))
    except Exception as e:
        print(f"Error calling Gemini API: {e}", file=sys.stderr)
        return f"## Error\nCould not generate the report. Check your API key and network connection. Details: {e}"
