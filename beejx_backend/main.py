from fastapi import FastAPI, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import redis
import json
import os
from services.gemini_service import get_agri_advice

app = FastAPI()

# Redis Configuration
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
try:
    redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)
    # Ping to check connection
    redis_client.ping()
    print(f"Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
except Exception as e:
    print(f"Warning: Redis connection failed: {e}. Caching will be disabled.")
    redis_client = None

# Allow from Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    query: str
    history: list = [] # Optional history

@app.post("/chat")
def chat(request: ChatRequest):
    try:
        query = request.query
        history = request.history
        
        # Redis Key includes ONLY query to cache common answers, 
        # BUT this ignores context. For a "Real Chatbot", enabling history usually disables simple caching 
        # or requires complex keys. For now, we cache only if history is empty (simple queries).
        
        cache_key = f"chat:{query.lower().strip()}"
        use_cache = len(history) == 0

        # 1. Check Cache (Only for fresh queries)
        if use_cache and redis_client:
            try:
                cached_response = redis_client.get(cache_key)
                if cached_response:
                    print(f"Cache Hit for: {query}")
                    return {"reply": cached_response}
            except Exception as e:
                print(f"Redis Read Error: {e}")

        # 2. Call Gemini
        response = get_agri_advice(query, history)

        # 3. Save to Cache
        if use_cache and redis_client and response:
            try:
                redis_client.setex(cache_key, 3600, response)
            except Exception as e:
                print(f"Redis Write Error: {e}")

        return {"reply": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

from services.weather_service import fetch_weather

@app.get("/weather")
def get_weather(lat: float, lon: float):
    return fetch_weather(lat, lon)

@app.get("/market_prices")
def get_market_prices():
    # Mock Market Data
    return [
        {"crop": "Wheat", "price": 2125, "change": 2.5, "isUp": True},
        {"crop": "Rice", "price": 3450, "change": 1.2, "isUp": False},
        {"crop": "Maize", "price": 1890, "change": 0.8, "isUp": True},
        {"crop": "Potato", "price": 1200, "change": 5.0, "isUp": True},
    ]
