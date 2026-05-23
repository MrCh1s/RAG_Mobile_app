import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_cleanup():
    print("=== Testing /notes/cleanup ===")
    payload = {
        "content": "mua 2kg thit bo o sieu thi luc 5h chieu nay va mua them it rau thom nhe"
    }
    try:
        response = requests.post(f"{BASE_URL}/notes/cleanup", json=payload)
        if response.status_code == 200:
            print("Status: Success")
            print("Original Content:", payload["content"])
            print("Cleaned Content:")
            print(response.json().get("cleaned_content"))
        else:
            print(f"Status: Failed (HTTP {response.status_code})")
            print(response.text)
    except Exception as e:
        print(f"Error calling API: {e}")

def test_create_and_classify():
    print("\n=== Testing /notes/create (Auto-classification) ===")
    payload = {
        "content": "Hop giao ban du an RAG Mobile app voi sếp luc 9 gio sang mai tai phong hop lon de thong qua ke hoach moi",
        "clean_up": False
    }
    try:
        response = requests.post(f"{BASE_URL}/notes/create", json=payload)
        if response.status_code == 200:
            print("Status: Success")
            data = response.json()
            print("Created Note ID:", data.get("note_id"))
            print("Auto-classified Folder:", data.get("folder"))
            print("Auto-generated Tags:", data.get("tags"))
        else:
            print(f"Status: Failed (HTTP {response.status_code})")
            print(response.text)
    except Exception as e:
        print(f"Error calling API: {e}")

def test_list_notes():
    print("\n=== Testing /notes (Listing categorized notes) ===")
    try:
        response = requests.get(f"{BASE_URL}/notes")
        if response.status_code == 200:
            notes = response.json()
            print(f"Found {len(notes)} notes in database:")
            for note in notes:
                print(f"- [{note.get('folder_name')}] [Tags: {note.get('tags')}]: {note.get('content')[:60]}...")
        else:
            print(f"Status: Failed (HTTP {response.status_code})")
    except Exception as e:
        print(f"Error calling API: {e}")

if __name__ == "__main__":
    print("Checking if the server is running...")
    try:
        requests.get(BASE_URL)
        print("Server is active. Starting tests...")
        test_cleanup()
        test_create_and_classify()
        test_list_notes()
    except requests.exceptions.ConnectionError:
        print(f"Could not connect to server at {BASE_URL}. Make sure the FastAPI server is running.")
