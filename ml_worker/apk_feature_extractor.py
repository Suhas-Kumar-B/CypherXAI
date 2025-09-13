# apk_feature_extractor.py
#
# Updated: parallel processing for API-call extraction and lower memory footprint.
# The public interface remains exactly:
#    extract_features(apk_path) -> dict | None
#
# Notes:
# - Cap workers with the ANDROID_FE_WORKERS env var or default to min(4, cpu_count).
# - This parallelism focuses on the string/tuple processing step; it avoids
#   attempting to send androguard objects between processes (not picklable).
#
import os
import sys
import gc
import multiprocessing
from androguard import session
from androguard.core.bytecodes.apk import APK

from concurrent.futures import ProcessPoolExecutor, as_completed

# Worker count cap - keeps memory usage reasonable on machines with many cores.
_DEFAULT_MAX_WORKERS = 4

def _format_api_call_tuple(t):
    """
    Worker function that receives a picklable tuple describing a method and
    returns the formatted API-call string or None if not external.
    t: (class_name, name, descriptor, is_external_flag)
    """
    try:
        class_name, name, descriptor, is_external_flag = t
        if is_external_flag:
            # return the same format you used previously
            return f"{class_name}->{name}{descriptor}"
    except Exception:
        return None
    return None

def extract_features(apk_path):
    """
    Extracts static features from an APK file.

    Args:
        apk_path (str): The path to the APK file.

    Returns:
        dict: A dictionary containing the extracted features.
              Returns None if the APK cannot be processed.

    The callable interface is unchanged from your original version.
    """
    try:
        # Determine number of workers to use for child processes
        try:
            env_workers = int(os.environ.get("ANDROID_FE_WORKERS", "0") or 0)
        except Exception:
            env_workers = 0
        cpu_count = multiprocessing.cpu_count() or 1
        max_workers = env_workers if env_workers > 0 else min(cpu_count, _DEFAULT_MAX_WORKERS)
        if max_workers < 1:
            max_workers = 1

        # Create a session and load APK bytes (keeps session local)
        sess = session.Session()
        with open(apk_path, "rb") as f:
            apk_bytes = f.read()
        sess.add(apk_path, apk_bytes)

        a, d_list, dx = sess.get_objects_apk(apk_path)
        if not a:
            print(f"Error: Could not load APK file: {apk_path}", file=sys.stderr)
            return None

        features = {
            'file_name': a.get_filename(),
            'package_name': a.get_package(),
            'version_code': a.get_androidversion_code(),
            'version_name': a.get_androidversion_name(),
            'min_sdk_version': a.get_min_sdk_version(),
          #  'target_sdk_version': a.get_target_sdk_version(),
            'permissions': [],
            'activities': [],
            'services': [],
            'receivers': [],
            'providers': [],
            'intent_filters': {'activity': [], 'service': [], 'receiver': []},
            'hardware_features': [],
            'api_calls': [],   # will set later
            'strings': [],     # will set later
            'native_libraries': []
        }

        # --- Manifest Features (lightweight) ---
        features['permissions'] = a.get_permissions()
        features['activities'] = a.get_activities()
        features['services'] = a.get_services()
        features['receivers'] = a.get_receivers()
        features['providers'] = a.get_providers()
        features['hardware_features'] = list(a.get_features())

        # Extract intent filters for components
        for activity in a.get_activities():
            filters = a.get_intent_filters('activity', activity)
            if filters:
                features['intent_filters']['activity'].append({activity: filters})

        for service in a.get_services():
            filters = a.get_intent_filters('service', service)
            if filters:
                features['intent_filters']['service'].append({service: filters})

        for receiver in a.get_receivers():
            filters = a.get_intent_filters('receiver', receiver)
            if filters:
                features['intent_filters']['receiver'].append({receiver: filters})

        # --- Code-level features ---
        # Strategy:
        # 1) Iterate dx.get_methods() once to build a small list of picklable tuples:
        #    (class_name, name, descriptor, is_external_flag)
        # 2) Use a ProcessPoolExecutor to format api_call strings in parallel from those tuples.
        # This avoids trying to send androguard objects to subprocesses while still using multiple CPUs.

        api_calls_set = set()
        strings_set = set()

        if d_list is not None and dx is not None:
            # Collect strings first (these are usually plain python strings)
            try:
                # dx.get_strings() might return a generator or iterable; convert to list
                # then we'll dedupe via set.
                for s in dx.get_strings():
                    # guard against non-string returns
                    if isinstance(s, str):
                        strings_set.add(s)
            except Exception:
                # fallback: iterate per-dex if dx.get_strings() fails
                try:
                    for d in d_list:
                        for s in getattr(d, "get_strings", lambda: [])():
                            if isinstance(s, str):
                                strings_set.add(s)
                except Exception:
                    # give up collecting strings but do not fail the whole extractor
                    pass

            # Build small picklable tuples from dx.get_methods()
            method_tuples = []
            try:
                for method in dx.get_methods():
                    try:
                        # The original code used: method.method.class_name, method.name, method.descriptor
                        # and method.is_external(). We'll try to read those attributes.
                        class_name = getattr(method, "method", None)
                        # handle if method.method is an object; try to get class_name attr
                        if class_name is not None:
                            class_name = getattr(method.method, "class_name", None) or getattr(method.method, "class_name", "")
                        else:
                            class_name = getattr(method, "class_name", "")
                        name = getattr(method, "name", "")
                        descriptor = getattr(method, "descriptor", "")
                        is_external_flag = False
                        try:
                            is_external_flag = method.is_external()
                        except Exception:
                            # fallback: treat as not external
                            is_external_flag = False

                        # Only include if we have at least a name or class_name
                        if name or class_name:
                            method_tuples.append((class_name, name, descriptor, bool(is_external_flag)))
                    except Exception:
                        # skip any problematic method object
                        continue
            except Exception:
                # If dx.get_methods() fails completely, leave method_tuples empty
                method_tuples = []

            # If we have method tuples, parallelize formatting into API-call strings
            if method_tuples:
                # cap workers to avoid OOM on machines with many cores
                workers = min(max_workers, max(1, len(method_tuples)))
                # chunk size heuristic: avoid too-small chunks
                chunk_size = max(1, len(method_tuples) // (workers * 4 + 1))

                # Use ProcessPoolExecutor to parallelize formatting (string operations are light,
                # but this avoids GIL-bound work on large datasets)
                with ProcessPoolExecutor(max_workers=workers) as exe:
                    futures = []
                    # submit in chunks to reduce task scheduling overhead
                    for i in range(0, len(method_tuples), chunk_size):
                        chunk = method_tuples[i:i + chunk_size]
                        # map each tuple in chunk via submit to allow as_completed aggregation
                        for t in chunk:
                            futures.append(exe.submit(_format_api_call_tuple, t))

                    for fut in as_completed(futures):
                        try:
                            res = fut.result()
                            if res:
                                api_calls_set.add(res)
                        except Exception:
                            continue

                # free method_tuples asap
                del method_tuples
                gc.collect()

        # Convert sets -> lists for JSON serialization
        features['api_calls'] = list(api_calls_set)
        features['strings'] = list(strings_set)

        # --- Native Libraries ---
        try:
            features['native_libraries'] = list(a.get_libraries())
        except Exception:
            features['native_libraries'] = []

        # Clean up large objects and force garbage collection to release memory
        try:
            # remove session objects references
            del sess
            del dx
            del d_list
            del a
        except Exception:
            pass
        gc.collect()

        return features

    except Exception as e:
        print(f"An error occurred while processing {apk_path}: {e}", file=sys.stderr)
        # On error, attempt to free memory
        try:
            gc.collect()
        except Exception:
            pass
        return None


if __name__ == '__main__':
    import json
    import os
    if len(sys.argv) > 1:
        apk_file_path = sys.argv[1]
    else:
        print("Usage: python apk_feature_extractor.py <path_to_apk>")
        sys.exit(1)

    if not os.path.exists(apk_file_path):
        print(f"Error: APK file not found at '{apk_file_path}'")
        sys.exit(1)

    print(f"Extracting features from: {apk_file_path}")
    extracted_features = extract_features(apk_file_path)

    if extracted_features:
        output_filename = f"{os.path.basename(apk_file_path)}_features.json"
        with open(output_filename, 'w') as f:
            json.dump(extracted_features, f, indent=4)
        print(f"Features successfully extracted and saved to {output_filename}")

        # summary
        print("\n--- Feature Summary ---")
        print(f"Package Name: {extracted_features.get('package_name')}")
        print(f"Permissions Count: {len(extracted_features.get('permissions', []))}")
        print(f"Activities Count: {len(extracted_features.get('activities', []))}")
        print(f"Services Count: {len(extracted_features.get('services', []))}")
        print(f"Receivers Count: {len(extracted_features.get('receivers', []))}")
        print(f"API Calls Count: {len(extracted_features.get('api_calls', []))}")
        print(f"Strings Found: {len(extracted_features.get('strings', []))}")
        print("-----------------------\n")
    else:
        print("Feature extraction failed.")
