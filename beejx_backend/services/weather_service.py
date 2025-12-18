import requests
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("OPENWEATHER_API_KEY", "YOUR_OWM_KEY")
BASE_URL = "https://api.openweathermap.org/data/2.5/weather"

def fetch_weather(lat: float, lon: float):
    try:
        if API_KEY == "YOUR_OWM_KEY":
            # Return mock data if no key provided
            return {
                "temp": 28,
                "condition": "Sunny (Mock)",
                "humidity": 65,
                "wind": 12,
                "location": "Uttarakhand (Mock)"
            }

        params = {
            "lat": lat,
            "lon": lon,
            "appid": API_KEY,
            "units": "metric"
        }
        response = requests.get(BASE_URL, params=params)
        data = response.json()

        if response.status_code == 200:
            return {
                "temp": int(data["main"]["temp"]),
                "condition": data["weather"][0]["main"],
                "humidity": data["main"]["humidity"],
                "wind": data["wind"]["speed"],
                "location": data["name"]
            }
        else:
            return {"error": "Unable to fetch weather"}
            
    except Exception as e:
        print(f"Weather Error: {e}")
        return {"error": str(e)}
