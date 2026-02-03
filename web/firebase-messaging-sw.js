// Minimal SW placeholder for later (background notifications).
// Step 1 doesn't send pushes yet, but web FCM setup expects an SW file.

importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');

// Your firebase config is embedded by FlutterFire in main app runtime.
// For SW, we still need explicit config (web options).
firebase.initializeApp({
  apiKey: "AIzaSyACykl4m8C7NUTXfoyQ7PQve-3Zqjxqeoc",
  authDomain: "strefa-ciszy.firebaseapp.com",
  projectId: "strefa-ciszy",
  storageBucket: "strefa-ciszy.firebasestorage.app",
  messagingSenderId: "734098285346",
  appId: "1:734098285346:web:6c0d95b707cf6b408c7b7b",
  measurementId: "G-VM6X22GFD0",
});

const messaging = firebase.messaging();

// Background handler (we’ll use this in Step 2)
messaging.onBackgroundMessage((payload) => {
  // No-op for now; Step 2 will display notifications here.
  console.log('[firebase-messaging-sw] BG message', payload);
});
