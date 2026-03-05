# Progressive Web App (PWA) Implementation Guide

This document outlines the core aspects of implementing a Progressive Web App (PWA) based on the configuration and code found in the Chatty application. Use this guide to implement PWA features in other web projects.

## Core PWA Components

### 1. Web App Manifest

Create a `manifest.json` file in your `static/` directory:

```json
{
  "name": "Your App Name PWA",
  "short_name": "App Name",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#000000",
  "icons": [
    {
      "src": "/your-app/logo_192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any"
    },
    {
      "src": "/your-app/logo_512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any"
    }
  ]
}
```

**Key Properties Explained:**
- `name`: Full name displayed when installing the app
- `short_name`: Shorter name for home screen icon
- `start_url`: URL that loads when the app is launched
- `display`: "standalone" makes it look like a native app
- `background_color`: Background color during app launch
- `theme_color`: Browser theme color
- `icons`: Required icon sizes (192x192 and 512x512 minimum)

### 2. HTML Meta Tags

Add these essential meta tags to your main HTML file (`src/app.html` in SvelteKit):

```html
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    
    <!-- PWA Essential Meta Tags -->
    <meta name="theme-color" content="#000000" />
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-status-bar-style" content="black" />
    
    <!-- Manifest Link -->
    <link rel="manifest" href="/your-app/manifest.json" />
    
    <!-- Icon -->
    <link rel="icon" href="/your-app/logo_512x512.png" />
    
    <!-- Additional styles and scripts -->
    %sveltekit.head%
</head>
<body>
    <!-- Your app content -->
    %sveltekit.body%
</body>
</html>
```

### 3. Service Worker Implementation

For development environments, you may want a service worker that unregisters itself to prevent caching issues:

**`static/service-worker.js`:**
```javascript
// Development service worker that unregisters itself
self.addEventListener('install', event => {
  console.log('Service worker installed');
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  console.log('Service worker activated');
  
  // Unregister this service worker in development
  self.registration.unregister()
    .then(() => {
      console.log('Service worker unregistered successfully');
    })
    .catch(error => {
      console.error('Error unregistering service worker:', error);
    });
    
  // Clear any caches
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          return caches.delete(cacheName);
        })
      );
    })
  );
});

self.addEventListener('fetch', event => {
  // Let browser handle requests normally in development
});
```

**Service Worker Registration in HTML:**
```html
<script>
    // Unregister any existing service workers in development
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.getRegistrations().then(registrations => {
            for (let registration of registrations) {
                registration.unregister().then(success => {
                    if (success) {
                        console.log('Service worker unregistered successfully:', registration.scope);
                    }
                }).catch(error => {
                    console.error('Error unregistering service worker:', error);
                });
            }
        }).catch(error => {
            console.error('Error getting service worker registrations:', error);
        });
    }
</script>
```

### 4. Dynamic Manifest Loading (SvelteKit Pattern)

For multi-tenant applications or different variants, dynamically load the manifest:

**In layout component (`src/routes/+layout.svelte`):**
```svelte
<script lang="ts">
    import { variantStore } from "$lib/stores/variant";
    const variant = $derived($variantStore);
</script>

<svelte:head>
    <title>{variant.texts.title || 'Default App Title'}</title>
    <link rel="icon" href="/{variant.variantPrefix}/logo_512x512.png" />
    <link rel="manifest" href="/{variant.variantPrefix}/manifest.json" />
    <link rel="stylesheet" href="/{variant.variantPrefix}/style.css" />
</svelte:head>
```

### 5. Required PWA Assets

Create the following image assets in your `static/` directory:

```
static/
├── your-app/
│   ├── manifest.json
│   ├── logo_192x192.png    (192x192 pixels)
│   ├── logo_512x512.png    (512x512 pixels)
│   ├── favicon.ico         (optional)
│   └── style.css           (app-specific styles)
```

**Icon Requirements:**
- **192x192**: Minimum required size for home screen icon
- **512x512**: Minimum required size for splash screen
- **Purpose**: Use "any" for general icons, "maskable" for adaptive icons
- **Format**: PNG preferred, but JPEG, GIF, and WebP also supported

### 6. Mobile Optimization CSS

Add mobile-friendly CSS for better PWA experience:

```css
/* Ensure full viewport usage */
html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    overflow-x: hidden;
}

/* Prevent text size adjustment on mobile */
body {
    -webkit-text-size-adjust: 100%;
    -ms-text-size-adjust: 100%;
}

/* Touch-friendly button sizes */
button, .btn {
    min-height: 44px;
    min-width: 44px;
}

/* Safe area padding for notched devices */
.app-container {
    padding-top: env(safe-area-inset-top);
    padding-bottom: env(safe-area-inset-bottom);
    padding-left: env(safe-area-inset-left);
    padding-right: env(safe-area-inset-right);
}
```

### 7. Enhanced Social Sharing (Optional)

For better sharing experience, add Open Graph meta tags:

```html
<!-- Open Graph / Facebook -->
<meta property="og:type" content="website">
<meta property="og:url" content="https://yourapp.com/">
<meta property="og:title" content="Your App Name">
<meta property="og:description" content="Description of your app">
<meta property="og:image" content="https://yourapp.com/your-app/preview-image.png">

<!-- Twitter -->
<meta property="twitter:card" content="summary_large_image">
<meta property="twitter:url" content="https://yourapp.com/">
<meta property="twitter:title" content="Your App Name">
<meta property="twitter:description" content="Description of your app">
<meta property="twitter:image" content="https://yourapp.com/your-app/preview-image.png">
```

### 8. Production Service Worker (Optional)

For production, implement a proper caching service worker:

```javascript
const CACHE_NAME = 'your-app-v1';
const urlsToCache = [
  '/',
  '/static/css/styles.css',
  '/static/js/app.js',
  // Add other static assets
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        return cache.addAll(urlsToCache);
      })
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        // Return cached version or fetch from network
        return response || fetch(event.request);
      })
  );
});
```

### 9. Installation Prompt Handling

Add JavaScript to handle PWA installation:

```javascript
let deferredPrompt;

window.addEventListener('beforeinstallprompt', (e) => {
  // Prevent Chrome 67 and earlier from automatically showing the prompt
  e.preventDefault();
  // Stash the event so it can be triggered later
  deferredPrompt = e;
  
  // Show your custom install button
  showInstallButton();
});

function showInstallPrompt() {
  if (deferredPrompt) {
    deferredPrompt.prompt();
    deferredPrompt.userChoice.then((choiceResult) => {
      if (choiceResult.outcome === 'accepted') {
        console.log('User accepted the PWA install prompt');
      }
      deferredPrompt = null;
    });
  }
}
```

## SvelteKit Specific Configuration

### Adapter Configuration

Ensure your `svelte.config.js` is properly configured:

```javascript
import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({
      routes: {
        include: ['/*'],
        exclude: ['/static/*']
      }
    })
  }
};

export default config;
```

### Package.json Dependencies

Essential dependencies for PWA in SvelteKit:

```json
{
  "devDependencies": {
    "@sveltejs/adapter-cloudflare": "5.*",
    "@sveltejs/kit": "2.*",
    "@sveltejs/vite-plugin-svelte": "5.*"
  }
}
```

## Testing PWA Implementation

### Checklist:
1. ✅ Manifest file accessible at `/manifest.json`
2. ✅ Icons available in correct sizes (192x192, 512x512)
3. ✅ Meta tags present in HTML head
4. ✅ HTTPS enabled (required for PWA)
5. ✅ Service worker registered
6. ✅ App works offline (if service worker caches content)
7. ✅ Installation prompt appears on supported browsers
8. ✅ App launches in standalone mode when installed

### Tools:
- **Chrome DevTools**: Application tab > Manifest
- **Lighthouse**: PWA audit
- **Web App Manifest Validator**: Check manifest syntax

## Platform-Specific Considerations

### iOS Safari:
- Requires `apple-touch-icon` meta tags for optimal experience
- `mobile-web-app-capable` for fullscreen mode
- `mobile-web-app-status-bar-style` for status bar appearance

### Android Chrome:
- Automatic install prompt with proper manifest
- Theme color affects status bar
- Splash screen generated from manifest

## Common Issues & Solutions

1. **Icons not showing**: Ensure correct file paths and sizes
2. **Installation prompt not appearing**: Check HTTPS, manifest validity
3. **App not launching in standalone**: Verify `display: "standalone"` in manifest
4. **Service worker not updating**: Implement proper cache versioning
5. **Theme color not applying**: Check meta tag and manifest consistency

## Summary

The core PWA implementation requires:
1. **Web App Manifest** with proper icons and metadata
2. **HTML Meta Tags** for mobile optimization
3. **Service Worker** for offline capability (optional but recommended)
4. **HTTPS** for security requirements
5. **Responsive Design** for mobile experience

This setup will make your web application installable and provide a native app-like experience across devices. 