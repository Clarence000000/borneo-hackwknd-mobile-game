"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.weatherCheck = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const node_fetch_1 = __importDefault(require("node-fetch"));
// Load local environment variables (safe fallback since firebase emulators inject differently)
require("dotenv").config({ path: "../.env.local" });
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
// OpenWeather API config
const OPENWEATHER_API_KEY = process.env.COOGLE_CLOUD_KEY || process.env.OPENWEATHER_API_KEY || "YOUR_API_KEY";
const OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/weather";
// Weather condition IDs that trigger disasters
// See: https://openweathermap.org/weather-conditions
const FLOOD_IDS = [502, 503, 504, 511, 521, 522, 531]; // Heavy rain / shower
const STORM_IDS = [200, 201, 202, 210, 211, 212, 221, 230, 231, 232]; // Thunderstorm
const DROUGHT_THRESHOLD_TEMP = 40; // °C — extreme heat
/**
 * Weather Check Cloud Function
 *
 * 1. Receives user's GPS coordinates
 * 2. Calls OpenWeather API
 * 3. Checks for severe weather alerts
 * 4. If severe → writes disaster event to Firestore
 * 5. Returns disaster status to client
 */
exports.weatherCheck = functions.https.onCall(async (request) => {
    var _a, _b, _c, _d, _e, _f;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    const { lat, lng } = request.data;
    if (typeof lat !== "number" || typeof lng !== "number") {
        throw new functions.https.HttpsError("invalid-argument", "lat and lng required");
    }
    try {
        // Fetch weather data
        const url = `${OPENWEATHER_URL}?lat=${lat}&lon=${lng}&appid=${OPENWEATHER_API_KEY}&units=metric`;
        const response = await (0, node_fetch_1.default)(url);
        const data = (await response.json());
        // Analyze weather conditions
        let disasterType = null;
        let severity = 0;
        if (data.weather && data.weather.length > 0) {
            const weatherId = data.weather[0].id;
            if (FLOOD_IDS.includes(weatherId)) {
                disasterType = "flood";
                severity = 0.7 + Math.random() * 0.3; // 0.7-1.0
            }
            else if (STORM_IDS.includes(weatherId)) {
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
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                weatherData: {
                    id: (_c = (_b = data.weather) === null || _b === void 0 ? void 0 : _b[0]) === null || _c === void 0 ? void 0 : _c.id,
                    description: (_e = (_d = data.weather) === null || _d === void 0 ? void 0 : _d[0]) === null || _e === void 0 ? void 0 : _e.description,
                    temp: (_f = data.main) === null || _f === void 0 ? void 0 : _f.temp,
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
    }
    catch (error) {
        console.error("Weather check failed:", error);
        // Fail safe: no disaster if API is down
        return { hasDisaster: false, disasterType: null, severity: 0 };
    }
});
//# sourceMappingURL=weatherCheck.js.map