# train_apk_classifier.py
#
# Description:
# This script trains a Random Forest classifier to distinguish between benign and
# malicious APK files based on static features. It uses the feature extractor
# from 'apk_feature_extractor.py' to process the APKs.
#
# This script saves the trained model, the feature vectorizer, performance metrics,
# and a list of the most important features for malware detection.
#
# Dependencies:
# - scikit-learn
# - joblib
# - androguard (required by apk_feature_extractor)
# - tqdm (optional, for a nice progress bar)
#
# To install dependencies:
# pip install scikit-learn joblib androguard tqdm
#
# Directory Structure:
# .
# |-- train_apk_classifier.py
# |-- apk_feature_extractor.py
# L-- dataset/
#     |-- benign/
#     |   ...
#     L-- malicious/
#         ...
#
# Usage:
# python train_apk_classifier.py

import os
import sys
import json
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction import DictVectorizer
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, confusion_matrix
import joblib
import numpy as np

# Optional dependency for a nice progress bar. If not installed, a simple counter will be used.
try:
    from tqdm import tqdm
    _HAS_TQDM = True
except ImportError:
    _HAS_TQDM = False

# Import the feature extractor from your other script
try:
    from ml_worker.apk_feature_extractor import extract_features
except ImportError:
    print("Error: 'apk_feature_extractor.py' not found.")
    print("Please ensure the feature extractor script is in the same directory.")
    sys.exit(1)

def collect_apk_tasks(*directories_with_labels):
    """
    Collects .apk files from given directories and pairs them with labels.

    Args:
        directories_with_labels: sequence of (directory_path, label)

    Returns:
        list of (apk_path, label)
    """
    tasks = []
    for directory_path, label in directories_with_labels:
        if not os.path.isdir(directory_path):
            print(f"Warning: Directory not found: {directory_path}", file=sys.stderr)
            continue
        for filename in os.listdir(directory_path):
            if filename.endswith('.apk'):
                apk_path = os.path.join(directory_path, filename)
                tasks.append((apk_path, label))
    return tasks

def preprocess_features(feature_list):
    """
    Flattens and prepares the raw feature dictionaries for vectorization.

    Args:
        feature_list (list): A list of feature dictionaries from the extractor.

    Returns:
        list: A list of flattened dictionaries suitable for DictVectorizer.
    """
    processed_features = []
    for features in feature_list:
        flat_features = {}
        
        # Add permissions as individual features
        for perm in features.get('permissions', []):
            flat_features[f"permission_{perm}"] = 1
            
        # Add API calls as individual features
        for api_call in features.get('api_calls', []):
            flat_features[f"api_{api_call}"] = 1
            
        # Add hardware features
        for hw_feature in features.get('hardware_features', []):
            flat_features[f"hardware_{hw_feature}"] = 1

        # Add intent filter actions
        for component_type in ['activity', 'service', 'receiver']:
            for intent_map in features.get('intent_filters', {}).get(component_type, []):
                for component, filters in intent_map.items():
                    if 'action' in filters:
                        for action in filters['action']:
                            flat_features[f"intent_action_{action}"] = 1
        
        # Add numerical features
        flat_features['min_sdk'] = int(features.get('min_sdk_version', 0))
        #flat_features['target_sdk'] = int(features.get('target_sdk_version', 0))
        
        processed_features.append(flat_features)
        
    return processed_features

def main():
    """
    Main function to load data, train the model, evaluate it, and save artifacts.
    """
    benign_dir = os.path.join('dataset', 'benign')
    malicious_dir = os.path.join('dataset', 'malicious')

    # --- 1. Collect APK tasks ---
    tasks = collect_apk_tasks((benign_dir, 0), (malicious_dir, 1))
    total_apks = len(tasks)

    if total_apks == 0:
        print("Error: No APK files found in dataset/benign or dataset/malicious.")
        sys.exit(1)

    print(f"Found {total_apks} APK(s) to process.\n")

    all_raw_features = []
    all_labels = []

    # --- 2. Process APKs with progress indicator ---
    print("--- Starting Feature Extraction ---")
    iterator = tqdm(tasks, desc="Processing APKs", unit="apk") if _HAS_TQDM else tasks
    
    for task in iterator:
        apk_path, label = task
        try:
            features = extract_features(apk_path)
            if features:
                all_raw_features.append(features)
                all_labels.append(label)
        except Exception as e:
            # don't crash on a single bad APK; print and continue
            print(f"\nError processing {apk_path}: {e}", file=sys.stderr)
            continue

    if not all_raw_features:
        print("Error: No APKs were successfully processed. Exiting.")
        sys.exit(1)

    benign_count = sum(1 for l in all_labels if l == 0)
    malicious_count = sum(1 for l in all_labels if l == 1)

    print(f"\n--- Feature Extraction Complete ---")
    print(f"Total samples processed successfully: {len(all_raw_features)}")
    print(f"Benign samples: {benign_count}")
    print(f"Malicious samples: {malicious_count}")

    # --- 3. Preprocess and Vectorize Features ---
    print("\n--- Preprocessing and Vectorizing Features ---")
    processed_features = preprocess_features(all_raw_features)
    
    vectorizer = DictVectorizer(sparse=True)
    X = vectorizer.fit_transform(processed_features)
    y = np.array(all_labels)
    
    print(f"Feature matrix shape: {X.shape}")

    # --- 4. Split Data and Train Model ---
    print("\n--- Splitting Data and Training Random Forest Model ---")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, random_state=42, stratify=y
    )
    
    model = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
    model.fit(X_train, y_train)
    print("Model training complete.")

    # --- 5. Evaluate the Model ---
    print("\n--- Evaluating Model Performance ---")
    y_pred = model.predict(X_test)
    
    metrics = {
        'accuracy': accuracy_score(y_test, y_pred),
        'precision': precision_score(y_test, y_pred),
        'recall': recall_score(y_test, y_pred),
        'f1_score': f1_score(y_test, y_pred),
        'confusion_matrix': confusion_matrix(y_test, y_pred).tolist()
    }
    
    print(f"Accuracy: {metrics['accuracy']:.4f}")
    print(f"Precision: {metrics['precision']:.4f}")
    print(f"Recall: {metrics['recall']:.4f}")
    print(f"F1-Score: {metrics['f1_score']:.4f}")
    print("\nConfusion Matrix:")
    print(np.array(metrics['confusion_matrix']))

    # --- 6. Extract and Save Feature Importances ---
    print("\n--- Extracting Feature Importances ---")
    importances = model.feature_importances_
    feature_names = vectorizer.get_feature_names_out()
    feature_importance_dict = dict(zip(feature_names, importances))
    
    sorted_features = sorted(feature_importance_dict.items(), key=lambda item: item[1], reverse=True)
    
    top_features = dict(sorted_features[:100])
    print(f"Top 10 most important features:")
    for feature, importance in list(top_features.items())[:10]:
        print(f"- {feature}: {importance:.4f}")

    # --- 7. Save Model and Supporting Artifacts ---
    print("\n--- Saving Model and Artifacts ---")
    artifacts = {
        'model': 'apk_random_forest_model.joblib',
        'vectorizer': 'apk_feature_vectorizer.joblib',
        'metrics': 'model_performance_metrics.json',
        'top_features': 'top_malware_features.json'
    }
    
    joblib.dump(model, artifacts['model'])
    joblib.dump(vectorizer, artifacts['vectorizer'])
    
    with open(artifacts['metrics'], 'w') as f:
        json.dump(metrics, f, indent=4)
        
    with open(artifacts['top_features'], 'w') as f:
        json.dump(top_features, f, indent=4)
    
    print(f"Model saved to: {artifacts['model']}")
    print(f"Vectorizer saved to: {artifacts['vectorizer']}")
    print(f"Performance metrics saved to: {artifacts['metrics']}")
    print(f"Top 100 important features saved to: {artifacts['top_features']}")
    print("\nTraining process finished successfully.")

if __name__ == '__main__':
    main()
