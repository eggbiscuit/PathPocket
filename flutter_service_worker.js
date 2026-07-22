'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"index.html": "82bb8dfd5e6ca447f3e5134fdf2aef8d",
"/": "82bb8dfd5e6ca447f3e5134fdf2aef8d",
"version.json": "33db4bb6eea372dcc9f751608491b605",
"main.dart.js": "ea296e79a5779afc62fcb43ddb92604a",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"openseadragon/changelog.txt": "68f8b6d0afc41fb463a71eff191f6cdc",
"openseadragon/openseadragon.min.js.map": "4dfe29f1da0767d740fc8edbb8bf0ec2",
"openseadragon/openseadragon.js": "f9885a1baa07507a8b9f21e79023791c",
"openseadragon/images/fullpage_grouphover.png": "42e9c79dc79375d102153858e669bd30",
"openseadragon/images/home_rest.png": "8d9fa38f7e0cd6d66f7c6927095e67a4",
"openseadragon/images/home_grouphover.png": "d14125142ef3694d56fd8a29fa32e2c6",
"openseadragon/images/zoomin_pressed.png": "5b21ffaa3340353be073ecedad1d5d0a",
"openseadragon/images/fullpage_hover.png": "f3a4dc16ec7028978d3c334073a9c36c",
"openseadragon/images/next_hover.png": "1d86f5b8002be1d5542cdd5dfb00e0b3",
"openseadragon/images/zoomin_grouphover.png": "9939873c8af89939e7c5be4db4dab447",
"openseadragon/images/rotateleft_grouphover.png": "803fa7192e5aa0bdb9dea5f78db5705a",
"openseadragon/images/flip_rest.png": "7f9c40c57f9f4be36aa1d5d22497f71f",
"openseadragon/images/rotateright_rest.png": "6a4823da6ccb5a7d4d7a2dde4b19d5e6",
"openseadragon/images/zoomin_hover.png": "6c78c2bc7bea7254506283208b553bb8",
"openseadragon/images/rotateleft_rest.png": "65336ac83e6674247de68e1363a916a0",
"openseadragon/images/zoomout_pressed.png": "c6327813723b52b9eabc1952626c99df",
"openseadragon/images/button_grouphover.png": "71845fb2fc9a756e824778d101b06157",
"openseadragon/images/next_rest.png": "504f56a785ab7f6da4a0415f1c16f6b4",
"openseadragon/images/zoomout_rest.png": "1750b0b6fb8f23fb343a3bd595741cbd",
"openseadragon/images/rotateleft_pressed.png": "b08af14c739a8482ddc495184adb21c3",
"openseadragon/images/previous_grouphover.png": "830a1f39be3cadaabedda812424ec763",
"openseadragon/images/next_grouphover.png": "5f8e933291cf779d715ded0ab4759692",
"openseadragon/images/fullpage_rest.png": "52688ff690266b2055752e3aa91f9009",
"openseadragon/images/home_pressed.png": "34fcccb901abeecf9731594b4ca70887",
"openseadragon/images/home_hover.png": "af78a3af12bcf393b01f74f9b3e37a6a",
"openseadragon/images/rotateleft_hover.png": "f34fb64dfbb2bfdd2e0d54478ec8e7cc",
"openseadragon/images/zoomin_rest.png": "92c4eed280c1bed37c9fba0aae7cca88",
"openseadragon/images/button_hover.png": "219ca15281bf30ca42fc9b041baa0f81",
"openseadragon/images/previous_rest.png": "7b852cf8cc419742f33c0796a375c790",
"openseadragon/images/zoomout_grouphover.png": "19662f7ca1c1a896c95bd760c0f6a31e",
"openseadragon/images/button_rest.png": "6d65f1f8fcc0ef137c1a0b9226dc7147",
"openseadragon/images/previous_pressed.png": "0478bc0721361e245bc6ae7b80d07bb2",
"openseadragon/images/button_pressed.png": "520d9665fb306f55bbf589cd94a12dee",
"openseadragon/images/flip_hover.png": "1d151fdb16a178907d72b409c04603a6",
"openseadragon/images/rotateright_pressed.png": "d7168de399c639756fad56a7b877938a",
"openseadragon/images/previous_hover.png": "b2eb667c796530057e17ec05556c8a30",
"openseadragon/images/zoomout_hover.png": "016da063e45add4f7f353eb87f2de5d7",
"openseadragon/images/flip_pressed.png": "5023e50d2cfd174f86d600825823321c",
"openseadragon/images/rotateright_grouphover.png": "1ac9f6bd7fd35cfe81abe8ec516a7ad0",
"openseadragon/images/next_pressed.png": "028df665ba465133ea20a5f7d8f7a45b",
"openseadragon/images/fullpage_pressed.png": "4f2a6dd2d0d4ffdf350ef253d17e45b0",
"openseadragon/images/flip_grouphover.png": "07cf5529f84839834d6b56b239d4a9ba",
"openseadragon/images/rotateright_hover.png": "7a66a59675febabbe9b4d30f0b1a0aeb",
"openseadragon/openseadragon.js.map": "32dc10c0e1adfd647db55bbfc3473d20",
"openseadragon/LICENSE.txt": "21620cf2e69ec43fad5524e6dbf03ab4",
"openseadragon/openseadragon.min.js": "91f309636b3d7eff276797fcb4b34bf9",
"openseadragon/pathpocket_osd.js": "e4710a35e2717b9bb58b8ad5714b807d",
"drift_worker.js": "90a7155a51872e8f0afa47b707ac1d66",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/fonts/MaterialIcons-Regular.otf": "2ffb713351f12d84523dee085a690882",
"assets/AssetManifest.bin": "d6d96d41e2ab0f9307e332de567cd843",
"assets/AssetManifest.json": "a6c0a9caeac5c8fbdc9b96dcbd592efb",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/NOTICES": "6f8844b4a7c29b10921ca4e63daf05bf",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "f2d7e0e0a54786c73ccbe6ca8a2a2dac",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"manifest.json": "8a63de3b671264d0d32fda575f9b8c8d",
"flutter_bootstrap.js": "0b3d71b256a6e287cb5d2af855d038be",
"sqlite3.wasm": "d59c35358a880f4f7ceb1714f8f7f93f",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
