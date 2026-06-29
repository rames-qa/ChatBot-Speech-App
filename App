import os
import time
import threading
from flask import Flask, render_template, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Global thread lock for automation workers (Milestone 5)
automation_lock = threading.Lock()

def mock_cognitive_llm_extractor(raw_text):
    """
    Milestone 3: Cognitive Intent Extraction Matrix
    Normalizes complex natural language into a predictable dictionary structure.
    """
    text = raw_text.lower()
    payload = {"platform": "google", "query": "", "action": "search"}
    
    # Platform mapping dictionary
    platforms = {
        "amazon": ["amazon", "shopping cart", "buy"],
        "myntra": ["myntra", "shoes on myntra", "clothes"],
        "flipkart": ["flipkart"],
        "google": ["google", "look up", "search for"]
    }
    
    # Identify platform matching
    for platform, triggers in platforms.items():
        if any(trigger in text for trigger in triggers):
            payload["platform"] = platform
            break
            
    # Intent/Action profiling
    if "open" in text and "search" not in text:
        payload["action"] = "open"
    else:
        payload["action"] = "search"
        
    # Extract structural query text
    omit_phrases = ["look up", "search for", "open up", "on amazon", "on myntra", "for me", "can you", "hey", "some"]
    clean_query = text
    for phrase in omit_phrases:
        clean_query = clean_query.replace(phrase, "")
        
    payload["query"] = clean_query.strip().strip("'\"")
    return payload


def run_selenium_worker(platform, query):
    """
    Milestone 5: Concurrent Worker Operations executed inside an independent thread loop.
    """
    print(f"[Selenium Worker] Lock acquired. Operating pipeline for {platform} -> {query}")
    time.sleep(5) # Simulate backend worker execution delay
    print("[Selenium Worker] Task complete. Releasing execution track.")


@app.route('/')
def index():
    # Renders the single unified interface file
    return render_template('index.html')


@app.route('/api/command', methods=['POST'])
def handle_command():
    """
    Milestones 2, 4 & 5: Combined API Coordinator Routing Entry Point
    """
    data = request.get_json() or {}
    raw_command = data.get('command', '').strip()
    
    if not raw_command:
        return jsonify({"status": "error", "message": "Null token string submitted."}), 400
        
    # Milestone 3: Run intent extraction normalization
    extracted_intent = mock_cognitive_llm_extractor(raw_command)
    platform = extracted_intent["platform"]
    query = extracted_intent["query"]
    
    # Check if platform demands active backend automation processing loop
    has_automation = True if platform == "amazon" else False
    
    if not has_automation:
        # Milestone 4: Tab Redirection generation dictionary
        urls = {
            "myntra": f"https://www.myntra.com/{query}" if query else "https://www.myntra.com",
            "google": f"https://www.google.com/search?q={query}" if query else "https://www.google.com"
        }
        target_url = urls.get(platform, f"https://www.google.com/search?q={query}")
        
        return jsonify({
            "status": "success",
            "has_automation": False,
            "url": target_url,
            "intent": extracted_intent,
            "message": "Automation not available for this platform. Redirecting client workspace."
        })
        
    else:
        # Milestone 5: Automation Target (Locked background worker thread execution check)
        acquired = automation_lock.acquire(blocking=False)
        if not acquired:
            return jsonify({
                "status": "busy",
                "message": "System is currently executing an automated pipeline loop"
            }), 423 # 423 Locked State response
            
        try:
            # Dispatch async background worker thread loop
            def worker_wrapper():
                try:
                    run_selenium_worker(platform, query)
                finally:
                    automation_lock.release()
                    
            worker_thread = threading.Thread(target=worker_wrapper)
            worker_thread.start()
            
            return jsonify({
                "status": "success",
                "has_automation": True,
                "intent": extracted_intent,
                "message": f"Background automation pipeline initiated for {platform}."
            })
        except Exception as e:
            if automation_lock.locked():
                automation_lock.release()
            return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
