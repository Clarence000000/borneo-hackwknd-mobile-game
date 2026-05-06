import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import fetch from "node-fetch";

// Load local environment variables (safe fallback since firebase emulators inject differently)
require("dotenv").config({ path: "../.env.local" });

if (!getApps().length) initializeApp();
const db = getFirestore();

// OpenWeather API config
const OPENWEATHER_API_KEY = process.env.COOGLE_CLOUD_KEY || process.env.OPENWEATHER_API_KEY || "YOUR_API_KEY";
const OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/weather";

// Weather condition IDs that trigger disasters
// See: https://openweathermap.org/weather-conditions
const FLOOD_IDS = [502, 503, 504, 511, 521, 522, 531]; // Heavy rain / shower
const STORM_IDS = [200, 201, 202, 210, 211, 212, 221, 230, 231, 232]; // Thunderstorm
const DROUGHT_THRESHOLD_TEMP = 40; // °C — extreme heat

interface WeatherResponse {
    weather: Array<{ id: number; main: string; description: string }>;
    main: { temp: number; humidity: number };
    wind: { speed: number };
}

/**
 * Weather Check Cloud Function
 *
 * 1. Receives user's GPS coordinates
 * 2. Calls OpenWeather API
 * 3. Checks for severe weather alerts
 * 4. If severe → writes disaster event to Firestore
 * 5. Returns disaster status to client
 */
export const weatherCheck = onCall(
    async (request) => {
        const uid = request.auth?.uid;
        if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");

        const { lat, lng } = request.data;
        if (typeof lat !== "number" || typeof lng !== "number") {
            throw new HttpsError("invalid-argument", "lat and lng required");
        }

        try {
            // Fetch weather data
            const url = `${OPENWEATHER_URL}?lat=${lat}&lon=${lng}&appid=${OPENWEATHER_API_KEY}&units=metric`;
            const response = await fetch(url);
            const data = (await response.json()) as WeatherResponse;

            // Analyze weather conditions
            let disasterType: string | null = null;
            let severity = 0;

            if (data.weather && data.weather.length > 0) {
                const weatherId = data.weather[0].id;

                if (FLOOD_IDS.includes(weatherId)) {
                    disasterType = "flood";
                    severity = 0.7 + Math.random() * 0.3; // 0.7-1.0
                } else if (STORM_IDS.includes(weatherId)) {
                    disasterType = "storm";
                    severity = 0.5 + Math.random() * 0.5;
                }
            }

            // Check for extreme heat (drought)
            if (!disasterType && data.main && data.main.temp >= DROUGHT_THRESHOLD_TEMP) {
                disasterType = "drought";
                severity = (data.main.temp - DROUGHT_THRESHOLD_TEMP) / 10; // Scale
                severity = Math.min(severity, 1.0);
            }

            // If disaster detected, write event to Firestore
            if (disasterType) {
                const eventRef = db
                    .collection("users")
                    .doc(uid)
                    .collection("disasterEvents")
                    .doc();

                await eventRef.set({
                    type: disasterType,
                    severity,
                    cropsDestroyed: 0, // Client will update after processing
                    insurancePayout: 0, // Will be calculated by insurancePayout function
                    timestamp: FieldValue.serverTimestamp(),
                    weatherData: {
                        id: data.weather?.[0]?.id,
                        description: data.weather?.[0]?.description,
                        temp: data.main?.temp,
                    },
                });

                return {
                    hasDisaster: true,
                    disasterType,
                    severity,
                    eventId: eventRef.id,
                };
            }

            return { hasDisaster: false, disasterType: null, severity: 0 };
        } catch (error) {
            console.error("Weather check failed:", error);
            // Fail safe: no disaster if API is down
            return { hasDisaster: false, disasterType: null, severity: 0 };
        }
    }
);
