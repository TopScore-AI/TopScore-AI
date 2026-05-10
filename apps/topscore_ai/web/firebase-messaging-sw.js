importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyDoG5zU8EzdPPFrXFstx0licFDklaxs83M",
    authDomain: "elimisha-90787.firebaseapp.com",
    databaseURL: "https://elimisha-90787-default-rtdb.firebaseio.com",
    projectId: "elimisha-90787",
    storageBucket: "elimisha-90787.firebasestorage.app",
    messagingSenderId: "974459699084",
    appId: "1:974459699084:web:8d47fa11d39ca31968a0a9",
    measurementId: "G-YBP1DZ3VC9"
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);

    // Defensive check: payloads can be notification-only, data-only, or both.
    // If payload.notification is missing, try to fall back to payload.data
    const notificationTitle = (payload.notification && payload.notification.title) || 
                              (payload.data && payload.data.title) || 
                              'TopScore AI Update';
                              
    const notificationOptions = {
        body: (payload.notification && payload.notification.body) || 
              (payload.data && payload.data.body) || 
              '',
        icon: '/icons/Icon-192.png',
        data: payload.data // Pass data for click handling
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click: focus or open the app
self.addEventListener('notificationclick', (event) => {
    event.notification.close();

    const urlToOpen = new URL('/', self.location.origin).href;

    const promiseChain = clients.matchAll({
        type: 'window',
        includeUncontrolled: true
    }).then((windowClients) => {
        for (let i = 0; i < windowClients.length; i++) {
            const client = windowClients[i];
            if (client.url === urlToOpen && 'focus' in client) {
                return client.focus();
            }
        }
        if (clients.openWindow) {
            return clients.openWindow(urlToOpen);
        }
    });

    event.waitUntil(promiseChain);
});
