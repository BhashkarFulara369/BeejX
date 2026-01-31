<p align="center">
  <img src="assets/icon.png" width="150" alt="BeejX Icon" />
</p>

#  BeejX: The Offline AI Ecosystem for Indian Farmers

> **"Digital Agriculture shouldn't stop where the Internet stops."**

BeejX is an **Offline-First** Super App designed to empower the 400 million smallholder farmers in India who struggle with connectivity. It combines **Edge AI** (On-device LLMs), **IoT** (Soil Monitoring), and **Computer Vision** (Disease Detection) into a single, seamless Flutter application.

---

## 🚀 The Problem
While the world talks about "Cloud AI," a farmer in a remote hill village in Uttarakhand has **no signal**.
*   **Existing apps fail** without 4G.
*   **IoT Hardware** is too expensive ($500+).
*   **Disease Diagnosis** requires sending photos to a server (which fails due to latency).
* **Everything at ONE Place**

## 💡 The Solution: BeejX
We built an operating system for the farm that works **100% Offline** when needed, and syncs to the cloud when possible.

### Key Features
*   🧠 **Offline Brain (Samvaad)**: Runs Google's **Gemma-2 (270M)** LLM locally on the phone. Farmers can ask *"How to fix yellow leaves?"* in Hindi/English without internet.
*   👁️ **Vaidya (Crop Doctor)**: Uses a custom **MobileNetV2 (TFLite)** model to detect diseases like *Rice Blast* or *Wheat Rust* in < 200ms using the camera.
*   📡 **Bijuka (IoT Sentinel)**: A low-cost (< ₹2000) hardware kit (Arduino + ESP8266) that monitors Soil pH and Moisture live.
*   📒 **Lekha (Smart Ledger)**: Digitizes farm expenses by scanning bills using OCR.

---

##  Tech Stack (Google Ecosystem)
This project is built almost entirely on Google Technologies:
*   **Mobile**: Flutter (Dart) - Material 3 Design.
*   **Backend**: Firebase (Auth, Realtime Database for IoT).
*   **AI (Cloud)**: Gemini API  (for complex Query RAG).
*   **AI (Edge)**: TensorFlow Lite (Vision) + Gemma (Text via `llama.cpp`).
*   **Hardware**: ESP8266 NodeMCU + Arduino Mega.

---

##  The Journey: Challenges I Faced
Building BeejX wasn't just about writing UI code. It was a battle against hardware constraints. Here is the real story:

### 1. The "Offline Brain" Nightmare
Getting an LLM to run on an Android phone was the hardest part.
*   **The Challenge**: Integrating `llama.cpp` with Flutter using Dart FFI. I initially faced constant crashes because the Android NDK libraries weren't linking correctly.
*   **The Fix**: I had to manually configure `ndk.abiFilters 'armeabi-v7a', 'arm64-v8a'` in `build.gradle` and ensure the `.gguf` model was quantized to `q8_0` to balance speed and accuracy without blowing up the RAM.

### 2. Taming the IoT Latency
Connecting an Arduino to a beautiful Flutter UI sounds easy, but "Real-time" is hard.
*   **The Challenge**: The ESP8266 would sometimes disconnect in the field, causing the App to show stale data (e.g., showing "Pump ON" when it was actually OFF).
*   **The Fix**: I implemented a **Heartbeat Mechanism** in Firebase. The hardware updates a timestamp every 5 seconds. If the Flutter app sees the timestamp is > 10 seconds old, it instantly grays out the UI and shows a "Sensor Offline" warning.

### 3. Making it "Not Ugly"
Most Agri-apps look like boring government forms.
*   **The Goal**: I wanted BeejX to look like a premium SaaS product.
*   **The Solution**: I used **Glassmorphism** (frosted glass effects) and `fl_chart` for the Bijuka dashboard. Adapting these high-end visuals to perform smoothly on low-end devices required optimizing the render loop to avoid "Jank."

---


## 🔧 How to Run
1.  **Clone the Repo**:
    ```bash
    git clone https://github.com/BhashkarFulara369/BeejX.git
    ```
2.  **Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Model Setup**:
    *   Download `gemma-2-270m-it.gguf` (Quantized).
    *   Place it in the phone's storage or assets.
4.  **Run**:
    ```bash
    flutter run --release
    ```
    *(Note: Connect a physical Android device. Emulators are too slow for the Offline Brain.)*

---

##  Future Roadmap
*   **Voice-to-Voice** (Hinglish): Fully conversational mode using OpenAI Whisper (Offline). 
*   **LoRaWAN Support**: Replacing ESP8266 Wi-Fi with LoRa for 5km+ range.
*   **Drone Integration**: For aerial disease mapping.

---
**me it's me**