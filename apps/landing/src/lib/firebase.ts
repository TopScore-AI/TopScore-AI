import { initializeApp, getApps, getApp } from "firebase/app";
import { getAnalytics, isSupported } from "firebase/analytics";
import { getFirestore } from "firebase/firestore";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyD6AjKgCnEdmHdnfdWFXFzowEbii68R-rQ",
  authDomain: "elimisha-90787.firebaseapp.com",
  databaseURL: "https://elimisha-90787-default-rtdb.firebaseio.com",
  projectId: "elimisha-90787",
  storageBucket: "elimisha-90787.firebasestorage.app",
  messagingSenderId: "974459699084",
  appId: "1:974459699084:web:b0bed1e08764558c68a0a9",
  measurementId: "G-5GRBHEJ2V3"
};

// Initialize Firebase
const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
const db = getFirestore(app);

// Analytics initialization (Client-side only)
let analytics: any = null;
if (typeof window !== "undefined") {
  isSupported().then((supported) => {
    if (supported) {
      analytics = getAnalytics(app);
    }
  });
}

export { app, db, analytics };
