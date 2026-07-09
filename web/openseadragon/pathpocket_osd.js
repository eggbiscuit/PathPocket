// Glue between Flutter (dart:js_interop) and OpenSeadragon.
//
// Fetches our DZI descriptor (authenticated), parses the image geometry, then
// builds a custom tileSource whose getTileUrl points at the clean backend tile
// route. Every tile + the .dzi are loaded via AJAX with the Bearer header, so
// the whole viewer stays authenticated.
(function () {
  function parseDzi(xmlText) {
    const doc = new DOMParser().parseFromString(xmlText, "application/xml");
    const image = doc.getElementsByTagName("Image")[0];
    const size = doc.getElementsByTagName("Size")[0];
    return {
      width: parseInt(size.getAttribute("Width"), 10),
      height: parseInt(size.getAttribute("Height"), 10),
      tileSize: parseInt(image.getAttribute("TileSize"), 10),
      overlap: parseInt(image.getAttribute("Overlap"), 10),
      format: image.getAttribute("Format") || "jpeg",
    };
  }

  // elementId: DOM id of the host div
  // dziUrl:    GET .../wsi/slides/{id}/dzi
  // tileBase:  .../wsi/slides/{id}  (tiles at {tileBase}/tiles/{level}/{col}_{row}.jpeg)
  // token:     JWT access token
  window.pathpocketInitOSD = function (elementId, dziUrl, tileBase, token) {
    const headers = {
      Authorization: "Bearer " + token,
      "ngrok-skip-browser-warning": "true",
    };
    fetch(dziUrl, { headers: headers })
      .then(function (r) {
        if (!r.ok) throw new Error("dzi " + r.status);
        return r.text();
      })
      .then(function (xml) {
        const d = parseDzi(xml);
        OpenSeadragon({
          element: document.getElementById(elementId),
          prefixUrl: "openseadragon/images/",
          showNavigator: true,
          loadTilesWithAjax: true,
          ajaxHeaders: headers,
          crossOriginPolicy: "Anonymous",
          tileSources: {
            width: d.width,
            height: d.height,
            tileSize: d.tileSize,
            tileOverlap: d.overlap,
            minLevel: 0,
            getTileUrl: function (level, x, y) {
              return tileBase + "/tiles/" + level + "/" + x + "_" + y + "." + d.format;
            },
          },
        });
      })
      .catch(function (e) {
        const el = document.getElementById(elementId);
        if (el) {
          el.innerHTML =
            '<div style="color:#fff;font-family:sans-serif;padding:24px;text-align:center">' +
            "切片加载失败：" + (e && e.message ? e.message : e) + "</div>";
        }
      });
  };
})();
