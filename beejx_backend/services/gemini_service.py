import google.generativeai as genai
import os
from dotenv import load_dotenv

load_dotenv()

# Configure Gemini
# Ensure you have GOOGLE_API_KEY in your .env file
genai.configure(api_key=os.getenv("GOOGLE_API_KEY", "YOUR_GEMINI_KEY"))

# System Prompt for Deep-Shiva
SYSTEM_PROMPT = """
You are Deep-Shiva, an expert agricultural advisor for Indian farmers. 
Your goal is to provide accurate, timely, and practical advice on:
- Crop management (Rice, Wheat, Maize, etc.)
- Pest and disease control
- Weather-based farming decisions
- Government schemes (PM-KISAN, etc.)

Guidelines:
1. Answer in a simple, encouraging tone.
2. If the query is in Hindi/Regional language, reply in the same language (or English if requested).
3. Keep answers concise (under 100 words) unless detailed explanation is asked.
4. If you don't know the answer, suggest consulting a local expert (Krishi Vigyan Kendra).
"""

model = genai.GenerativeModel('gemini-pro')

def get_agri_advice(query: str, history: list = []) -> str:
    try:
        # Convert simple history list to Gemini format if needed
        # Expected format: [{'role': 'user', 'parts': ['...']}, {'role': 'model', 'parts': ['...']}]
        gemini_history = []
        for msg in history:
            role = 'user' if msg.get('role') == 'user' else 'model'
            gemini_history.append({'role': role, 'parts': [msg.get('message', '')]})

        # Create a chat session with history
        chat = model.start_chat(history=gemini_history)
        
        # We don't need to inject system prompt every time in history, 
        # but for the current turn we verify the context.
        response = chat.send_message(query)
        
        return response.text
    except Exception as e:
        print(f"Gemini Error: {e}")
        # Check for API Key issues
        if "API_KEY" in str(e) or "403" in str(e):
             return "Server Error: Invalid or Missing Google API Key. Please check backend .env file."
        return f"I am unable to connect to the Agri-Brain right now. Error: {str(e)}"
