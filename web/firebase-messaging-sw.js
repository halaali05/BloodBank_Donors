importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCkbQc1wHeY8i-TJ0pZlunDeTywB1OmySk",
  authDomain: "blood-bank-5264a.firebaseapp.com",
  projectId: "blood-bank-5264a",
  storageBucket: "blood-bank-5264a.firebasestorage.app",
  messagingSenderId: "466854985428",
  appId: "1:466854985428:web:e6c18a6a177c809466c541",
  measurementId: "G-YW3VKFD8K5",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const data = payload?.data || {};
  const title =
    data.title || payload?.notification?.title || "Blood Bank Notification";
  const body = data.body || payload?.notification?.body || "";

  self.registration.showNotification(title, {
    body,
    data,
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const data = event.notification?.data || {};
  const encoded = encodeURIComponent(JSON.stringify(data));
  const targetUrl = `${self.location.origin}/?notificationData=${encoded}`;

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ("focus" in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
      return null;
    }),
  );
});
