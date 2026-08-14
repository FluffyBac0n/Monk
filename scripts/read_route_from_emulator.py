from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote, unquote

from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore


PROJECT_ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class RoutePoint:
    lat: float
    lng: float
    altitude_m: float
    distance_km: float
    reverse_distance_km: float


@dataclass(frozen=True)
class RouteMarker:
    id: str
    lat: float
    lng: float
    stage_id: str | None
    stage_name: str
    point_index: int
    distance_km: float
    reverse_distance_km: float
    altitude_m: float


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Read routeMetadata and routeChunks from the local Firestore emulator."
    )
    parser.add_argument("--project-id", default="eurotrex-local")
    parser.add_argument("--trail-id", default="cyprus-e4")
    parser.add_argument("--emulator-host", default="127.0.0.1:8080")
    parser.add_argument("--sample-size", type=int, default=3)
    parser.add_argument(
        "--visualize",
        action="store_true",
        help="Write an HTML Leaflet polyline preview and serve it on localhost.",
    )
    parser.add_argument(
        "--map-output",
        type=Path,
        default=Path("outputs/route-map.html"),
        help="Path for the generated HTML map when --visualize is used.",
    )
    parser.add_argument(
        "--elevation-output",
        type=Path,
        default=Path("outputs/elevation-map.html"),
        help="Path for the generated HTML elevation chart when --visualize is used.",
    )
    parser.add_argument(
        "--no-serve",
        action="store_true",
        help="Only write the map HTML; do not start the localhost preview server.",
    )
    parser.add_argument(
        "--serve-host",
        default="127.0.0.1",
        help="Host for the preview server used with --visualize.",
    )
    parser.add_argument(
        "--serve-port",
        type=int,
        default=9090,
        help="Port for the preview server used with --visualize.",
    )
    args = parser.parse_args()
    args.map_output = resolve_output_path(args.map_output)
    args.elevation_output = resolve_output_path(args.elevation_output)

    os.environ["FIRESTORE_EMULATOR_HOST"] = args.emulator_host

    db = firestore.Client(
        project=args.project_id,
        credentials=AnonymousCredentials(),
    )

    metadata, points, markers = load_route(db, args.trail_id)

    print("Route metadata")
    print(f"  trailId: {args.trail_id}")
    print(f"  version: {metadata.get('version')}")
    print(f"  pointCount: {metadata.get('pointCount')}")
    print(f"  chunkCount: {metadata.get('chunkCount')}")
    print(f"  pointStride: {metadata.get('pointStride')}")
    print(f"  pointFormat: {metadata.get('pointFormat')}")
    print(f"  totalDistanceKm: {metadata.get('totalDistanceKm')}")
    print()
    print(f"Expanded {len(points)} points from routeChunks")
    print(f"Loaded {len(markers)} routeMarkers")

    if points:
        print()
        print("First points")
        for point in points[: args.sample_size]:
            print(f"  {point}")

        print()
        print("Last points")
        for point in points[-args.sample_size :]:
            print(f"  {point}")

    if args.visualize:
        write_route_map(args.map_output, points, markers, args.trail_id)
        write_elevation_map(args.elevation_output, points, markers, args.trail_id)
        print()
        print(f"Wrote route map: {args.map_output.resolve()}")
        print(f"Wrote elevation map: {args.elevation_output.resolve()}")
        if not args.no_serve:
            serve_route_map(args.map_output, args.serve_host, args.serve_port)


def load_route(
    db: firestore.Client,
    trail_id: str,
) -> tuple[dict, list[RoutePoint], list[RouteMarker]]:
    trail_ref = db.collection("trails").document(trail_id)

    metadata_snapshot = trail_ref.collection("routeMetadata").document("main").get()
    if not metadata_snapshot.exists:
        raise RuntimeError(f"Missing routeMetadata/main for trail '{trail_id}'")

    metadata = metadata_snapshot.to_dict() or {}
    stride = int(metadata.get("pointStride", 5))
    if stride != 5:
        raise RuntimeError(f"This reader expects pointStride=5, got {stride}")

    chunks = trail_ref.collection("routeChunks").order_by("chunkIndex").stream()

    points: list[RoutePoint] = []
    for chunk_snapshot in chunks:
        chunk = chunk_snapshot.to_dict() or {}
        flat_points = chunk.get("points", [])
        start_point_index = int(chunk.get("startPointIndex", len(points)))

        if len(flat_points) % stride != 0:
            raise RuntimeError(
                f"Chunk {chunk_snapshot.id} points length {len(flat_points)} "
                f"is not divisible by stride {stride}"
            )

        for offset in range(0, len(flat_points), stride):
            points.append(
                RoutePoint(
                    lat=flat_points[offset],
                    lng=flat_points[offset + 1],
                    altitude_m=flat_points[offset + 2],
                    distance_km=flat_points[offset + 3],
                    reverse_distance_km=flat_points[offset + 4],
                )
            )

        expected_total = start_point_index + (len(flat_points) // stride)
        if len(points) != expected_total:
            raise RuntimeError(
                f"Chunk {chunk_snapshot.id} produced unexpected point count. "
                f"Expected {expected_total}, got {len(points)}"
            )

    expected_point_count = metadata.get("pointCount")
    if expected_point_count is not None and len(points) != int(expected_point_count):
        raise RuntimeError(
            f"Metadata pointCount={expected_point_count}, but expanded {len(points)} points"
        )

    markers = load_route_markers(trail_ref)

    return metadata, points, markers


def load_route_markers(trail_ref: firestore.DocumentReference) -> list[RouteMarker]:
    markers: list[RouteMarker] = []
    marker_snapshots = trail_ref.collection("routeMarkers").order_by("pointIndex").stream()

    for marker_snapshot in marker_snapshots:
        marker = marker_snapshot.to_dict() or {}
        location = marker.get("location") or {}
        lat = read_location_value(location, "latitude")
        lng = read_location_value(location, "longitude")
        if lat is None or lng is None:
            continue

        markers.append(
            RouteMarker(
                id=marker_snapshot.id,
                lat=lat,
                lng=lng,
                stage_id=marker.get("stageId"),
                stage_name=str(marker.get("stageName") or marker_snapshot.id),
                point_index=int(marker.get("pointIndex", 0)),
                distance_km=float(marker.get("distanceKm", 0)),
                reverse_distance_km=float(marker.get("reverseDistanceKm", 0)),
                altitude_m=float(marker.get("altitudeM", 0)),
            )
        )

    return markers


def read_location_value(location: object, key: str) -> float | None:
    if isinstance(location, dict):
        value = location.get(key)
    else:
        value = getattr(location, key, None)

    if value is None:
        return None
    return float(value)


def write_route_map(
    output_path: Path,
    points: list[RoutePoint],
    markers: list[RouteMarker],
    trail_id: str,
) -> None:
    if not points:
        raise RuntimeError("Cannot visualize an empty route")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    coordinates = [[point.lat, point.lng] for point in points]
    marker_coordinates = [
        {
            "id": marker.id,
            "lat": marker.lat,
            "lng": marker.lng,
            "stageId": marker.stage_id,
            "stageName": marker.stage_name,
            "pointIndex": marker.point_index,
            "distanceKm": marker.distance_km,
            "reverseDistanceKm": marker.reverse_distance_km,
            "altitudeM": marker.altitude_m,
        }
        for marker in markers
    ]
    start = coordinates[0]
    end = coordinates[-1]

    cyprus_bounds = [[34.45, 32.0], [35.85, 34.9]]

    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{trail_id} route map</title>
  <link
    rel="stylesheet"
    href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
    integrity="sha256-p4NxAoJBhIINfQb8UXGnkK9T8EMH+2n6UX8EIDIVnU8="
    crossorigin=""
  >
  <style>
    .leaflet-container {{
      overflow: hidden;
      touch-action: pan-x pan-y;
    }}
    .leaflet-pane,
    .leaflet-tile,
    .leaflet-marker-icon,
    .leaflet-marker-shadow,
    .leaflet-tile-container,
    .leaflet-pane > svg,
    .leaflet-pane > canvas,
    .leaflet-zoom-box,
    .leaflet-image-layer,
    .leaflet-layer {{
      position: absolute;
      left: 0;
      top: 0;
    }}
    .leaflet-tile {{
      user-select: none;
      -webkit-user-drag: none;
    }}
    .leaflet-tile-pane {{
      z-index: 200;
    }}
    .leaflet-overlay-pane {{
      z-index: 400;
    }}
    .leaflet-shadow-pane {{
      z-index: 500;
    }}
    .leaflet-marker-pane {{
      z-index: 600;
    }}
    .leaflet-tooltip-pane {{
      z-index: 650;
    }}
    .leaflet-popup-pane {{
      z-index: 700;
    }}
    .leaflet-control-container .leaflet-top,
    .leaflet-control-container .leaflet-bottom {{
      position: absolute;
      z-index: 1000;
      pointer-events: none;
    }}
    .leaflet-top {{
      top: 0;
    }}
    .leaflet-right {{
      right: 0;
    }}
    .leaflet-bottom {{
      bottom: 0;
    }}
    .leaflet-left {{
      left: 0;
    }}
    .leaflet-control {{
      position: relative;
      z-index: 800;
      pointer-events: auto;
      float: left;
      clear: both;
      margin: 10px;
    }}
    .leaflet-right .leaflet-control {{
      float: right;
    }}
    .leaflet-control-zoom a {{
      background: white;
      border-bottom: 1px solid #d1d5db;
      color: #111827;
      display: block;
      font: 700 18px/26px Arial, sans-serif;
      height: 26px;
      text-align: center;
      text-decoration: none;
      width: 26px;
    }}
    .leaflet-control-attribution {{
      background: rgba(255, 255, 255, 0.8);
      font: 11px/1.5 Arial, sans-serif;
      padding: 0 5px;
    }}
    html, body, #map {{
      height: 100%;
      margin: 0;
    }}
    body, #map {{
      background: #f8fafc;
    }}
    .info {{
      background: white;
      border-radius: 4px;
      box-shadow: 0 1px 6px rgba(0, 0, 0, 0.25);
      font: 13px/1.4 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      padding: 8px 10px;
    }}
    .route-marker-triangle {{
      width: 0;
      height: 0;
      border-left: 6px solid transparent;
      border-right: 6px solid transparent;
      border-bottom: 13px solid #f59e0b;
      filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.35));
    }}
    .route-marker-triangle.unlinked {{
      border-bottom-color: #64748b;
    }}
    .marker-popup {{
      font: 13px/1.45 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    .marker-popup strong {{
      display: block;
      margin-bottom: 4px;
    }}
  </style>
</head>
<body>
  <div id="map"></div>
  <script
    src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
    integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
    crossorigin=""
  ></script>
  <script>
    const route = {json.dumps(coordinates, separators=(",", ":"))};
    const routeMarkers = {json.dumps(marker_coordinates, separators=(",", ":"))};
    const cyprusBounds = L.latLngBounds({json.dumps(cyprus_bounds)});
    const map = L.map("map", {{
      preferCanvas: true,
      maxBounds: cyprusBounds,
      maxBoundsViscosity: 1.0,
      worldCopyJump: false
    }});

    L.tileLayer("https://{{s}}.basemaps.cartocdn.com/light_all/{{z}}/{{x}}/{{y}}{{r}}.png", {{
      maxZoom: 19,
      minZoom: 8,
      noWrap: true,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
    }}).addTo(map);

    const polyline = L.polyline(route, {{
      color: "#0f766e",
      weight: 4,
      opacity: 0.9,
      lineJoin: "round"
    }}).addTo(map);

    L.circleMarker({json.dumps(start)}, {{
      radius: 7,
      color: "#166534",
      fillColor: "#22c55e",
      fillOpacity: 1
    }}).addTo(map).bindPopup("Start");

    L.circleMarker({json.dumps(end)}, {{
      radius: 7,
      color: "#991b1b",
      fillColor: "#ef4444",
      fillOpacity: 1
    }}).addTo(map).bindPopup("End");

    const escapeHtml = (value) => String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const markerPopupHtml = (marker) => `
      <div class="marker-popup">
        <strong>${{escapeHtml(marker.stageName)}}</strong>
        ${{marker.stageId ? `Stage ID: ${{escapeHtml(marker.stageId)}}<br>` : ""}}
        Point: ${{marker.pointIndex.toLocaleString()}}<br>
        Distance: ${{marker.distanceKm.toFixed(2)}} km<br>
        Reverse: ${{marker.reverseDistanceKm.toFixed(2)}} km<br>
        Altitude: ${{marker.altitudeM.toFixed(1)}} m
      </div>
    `;

    routeMarkers.forEach((marker) => {{
      const triangleIcon = L.divIcon({{
        className: "",
        html: `<div class="route-marker-triangle${{marker.stageId ? "" : " unlinked"}}"></div>`,
        iconSize: [12, 13],
        iconAnchor: [6, 13],
        popupAnchor: [0, -13]
      }});
      L.marker([marker.lat, marker.lng], {{
        icon: triangleIcon,
        title: marker.stageName
      }}).addTo(map).bindPopup(markerPopupHtml(marker));
    }});

    map.fitBounds(polyline.getBounds(), {{ padding: [24, 24], maxZoom: 12 }});

    const info = L.control({{ position: "topright" }});
    info.onAdd = function () {{
      const div = L.DomUtil.create("div", "info");
      div.innerHTML = "<strong>{trail_id}</strong><br>"
        + route.length.toLocaleString() + " route points<br>"
        + routeMarkers.length.toLocaleString() + " route markers";
      return div;
    }};
    info.addTo(map);
  </script>
</body>
</html>
"""
    output_path.write_text(html, encoding="utf-8")


def write_elevation_map(
    output_path: Path,
    points: list[RoutePoint],
    markers: list[RouteMarker],
    trail_id: str,
) -> None:
    if not points:
        raise RuntimeError("Cannot visualize an empty elevation profile")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    profile_points = [
        {
            "distanceKm": point.distance_km,
            "altitudeM": point.altitude_m,
            "lat": point.lat,
            "lng": point.lng,
        }
        for point in points
    ]
    marker_points = [
        {
            "stageName": marker.stage_name,
            "stageId": marker.stage_id,
            "distanceKm": marker.distance_km,
            "altitudeM": marker.altitude_m,
            "pointIndex": marker.point_index,
        }
        for marker in markers
    ]

    altitudes = [point.altitude_m for point in points]
    total_distance_km = points[-1].distance_km
    min_altitude_m = min(altitudes)
    max_altitude_m = max(altitudes)
    ascent_m = 0.0
    descent_m = 0.0
    for previous, current in zip(points, points[1:]):
        delta = current.altitude_m - previous.altitude_m
        if delta > 0:
            ascent_m += delta
        else:
            descent_m += abs(delta)

    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{trail_id} elevation profile</title>
  <style>
    * {{
      box-sizing: border-box;
    }}
    html, body {{
      height: 100%;
      margin: 0;
    }}
    body {{
      background: #f8fafc;
      color: #172033;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    main {{
      display: grid;
      grid-template-rows: auto auto;
      min-height: 100vh;
      padding: 16px;
      gap: 12px;
    }}
    header {{
      align-items: center;
      display: flex;
      gap: 16px;
      justify-content: space-between;
    }}
    h1 {{
      font-size: 18px;
      line-height: 1.2;
      margin: 0;
    }}
    .stats {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      justify-content: flex-end;
    }}
    .stat {{
      background: white;
      border: 1px solid #d8e0ea;
      border-radius: 6px;
      min-width: 108px;
      padding: 8px 10px;
    }}
    .stat span {{
      color: #64748b;
      display: block;
      font-size: 11px;
      text-transform: uppercase;
    }}
    .stat strong {{
      display: block;
      font-size: 15px;
      margin-top: 2px;
    }}
    .chart-shell {{
      background: white;
      border: 1px solid #d8e0ea;
      border-radius: 6px;
      height: 620px;
      min-height: 0;
      overflow: hidden;
      position: relative;
    }}
    canvas {{
      display: block;
      height: 100%;
      inset: 0;
      position: absolute;
      width: 100%;
    }}
    .tooltip {{
      background: rgba(15, 23, 42, 0.92);
      border-radius: 6px;
      color: white;
      display: none;
      font-size: 12px;
      left: 0;
      line-height: 1.45;
      max-width: 220px;
      padding: 8px 10px;
      pointer-events: none;
      position: absolute;
      top: 0;
      transform: translate(12px, -50%);
      white-space: nowrap;
      z-index: 10;
    }}
    @media (max-width: 720px) {{
      main {{
        padding: 10px;
      }}
      header {{
        align-items: stretch;
        flex-direction: column;
      }}
      .stats {{
        justify-content: stretch;
      }}
      .stat {{
        flex: 1 1 130px;
      }}
      .chart-shell {{
        height: 520px;
        min-height: 0;
      }}
    }}
  </style>
</head>
<body>
  <main>
    <header>
      <h1>{trail_id} elevation profile</h1>
      <section class="stats" aria-label="Elevation statistics">
        <div class="stat"><span>Distance</span><strong>{total_distance_km:.1f} km</strong></div>
        <div class="stat"><span>Altitude</span><strong>{min_altitude_m:.0f}-{max_altitude_m:.0f} m</strong></div>
        <div class="stat"><span>Ascent</span><strong>{ascent_m:.0f} m</strong></div>
        <div class="stat"><span>Descent</span><strong>{descent_m:.0f} m</strong></div>
        <div class="stat"><span>Points</span><strong>{len(points):,}</strong></div>
        <div class="stat"><span>Markers</span><strong>{len(markers):,}</strong></div>
      </section>
    </header>
    <section class="chart-shell">
      <canvas id="profile"></canvas>
      <div id="tooltip" class="tooltip"></div>
    </section>
  </main>
  <script>
    const profile = {json.dumps(profile_points, separators=(",", ":"))};
    const routeMarkers = {json.dumps(marker_points, separators=(",", ":"))};
    const canvas = document.getElementById("profile");
    const shell = canvas.parentElement;
    const tooltip = document.getElementById("tooltip");
    const totalDistanceKm = {total_distance_km:.12f};
    const minAltitudeM = {min_altitude_m:.12f};
    const maxAltitudeM = {max_altitude_m:.12f};
    let layout = null;
    let hoverIndex = null;
    let staticCanvas = null;
    let currentDpr = 1;

    const altitudePadding = Math.max(20, (maxAltitudeM - minAltitudeM) * 0.08);
    const chartMinAltitude = Math.floor((minAltitudeM - altitudePadding) / 10) * 10;
    const chartMaxAltitude = Math.ceil((maxAltitudeM + altitudePadding) / 10) * 10;

    function xForDistance(distanceKm) {{
      return layout.left + (distanceKm / totalDistanceKm) * layout.plotWidth;
    }}

    function yForAltitude(altitudeM) {{
      const ratio = (altitudeM - chartMinAltitude) / (chartMaxAltitude - chartMinAltitude);
      return layout.top + (1 - ratio) * layout.plotHeight;
    }}

    function resizeCanvas() {{
      const rect = {{
        width: shell.clientWidth,
        height: shell.clientHeight
      }};
      currentDpr = window.devicePixelRatio || 1;
      const nextWidth = Math.max(1, Math.floor(rect.width * currentDpr));
      const nextHeight = Math.max(1, Math.floor(rect.height * currentDpr));
      if (canvas.width !== nextWidth) {{
        canvas.width = nextWidth;
      }}
      if (canvas.height !== nextHeight) {{
        canvas.height = nextHeight;
      }}

      layout = {{
        width: rect.width,
        height: rect.height,
        left: 58,
        right: 22,
        top: 28,
        bottom: 44,
      }};
      layout.plotWidth = layout.width - layout.left - layout.right;
      layout.plotHeight = layout.height - layout.top - layout.bottom;
    }}

    function renderStaticChart() {{
      resizeCanvas();

      staticCanvas = document.createElement("canvas");
      staticCanvas.width = canvas.width;
      staticCanvas.height = canvas.height;

      const ctx = staticCanvas.getContext("2d");
      ctx.setTransform(currentDpr, 0, 0, currentDpr, 0, 0);
      ctx.clearRect(0, 0, layout.width, layout.height);

      drawGrid(ctx);
      drawProfile(ctx);
      drawMarkers(ctx);
    }}

    function draw() {{
      if (!staticCanvas) {{
        renderStaticChart();
      }}

      const ctx = canvas.getContext("2d");
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(staticCanvas, 0, 0);

      if (hoverIndex !== null) {{
        ctx.setTransform(currentDpr, 0, 0, currentDpr, 0, 0);
        drawHover(ctx, profile[hoverIndex]);
      }}
    }}

    function drawGrid(ctx) {{
      ctx.save();
      ctx.strokeStyle = "#e2e8f0";
      ctx.fillStyle = "#64748b";
      ctx.lineWidth = 1;
      ctx.font = "12px system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";

      const altitudeSteps = 5;
      for (let i = 0; i <= altitudeSteps; i += 1) {{
        const altitude = chartMinAltitude + ((chartMaxAltitude - chartMinAltitude) / altitudeSteps) * i;
        const y = yForAltitude(altitude);
        ctx.beginPath();
        ctx.moveTo(layout.left, y);
        ctx.lineTo(layout.width - layout.right, y);
        ctx.stroke();
        ctx.textAlign = "right";
        ctx.textBaseline = "middle";
        ctx.fillText(Math.round(altitude).toLocaleString() + " m", layout.left - 10, y);
      }}

      const distanceSteps = 8;
      for (let i = 0; i <= distanceSteps; i += 1) {{
        const distance = (totalDistanceKm / distanceSteps) * i;
        const x = xForDistance(distance);
        ctx.beginPath();
        ctx.moveTo(x, layout.top);
        ctx.lineTo(x, layout.height - layout.bottom);
        ctx.stroke();
        ctx.textAlign = "center";
        ctx.textBaseline = "top";
        ctx.fillText(Math.round(distance).toLocaleString() + " km", x, layout.height - layout.bottom + 12);
      }}

      ctx.strokeStyle = "#94a3b8";
      ctx.beginPath();
      ctx.rect(layout.left, layout.top, layout.plotWidth, layout.plotHeight);
      ctx.stroke();
      ctx.restore();
    }}

    function drawProfile(ctx) {{
      ctx.save();
      const areaGradient = ctx.createLinearGradient(0, layout.top, 0, layout.height - layout.bottom);
      areaGradient.addColorStop(0, "rgba(20, 184, 166, 0.36)");
      areaGradient.addColorStop(1, "rgba(20, 184, 166, 0.06)");

      ctx.beginPath();
      profile.forEach((point, index) => {{
        const x = xForDistance(point.distanceKm);
        const y = yForAltitude(point.altitudeM);
        if (index === 0) {{
          ctx.moveTo(x, y);
        }} else {{
          ctx.lineTo(x, y);
        }}
      }});
      ctx.lineTo(xForDistance(totalDistanceKm), layout.height - layout.bottom);
      ctx.lineTo(xForDistance(0), layout.height - layout.bottom);
      ctx.closePath();
      ctx.fillStyle = areaGradient;
      ctx.fill();

      ctx.beginPath();
      profile.forEach((point, index) => {{
        const x = xForDistance(point.distanceKm);
        const y = yForAltitude(point.altitudeM);
        if (index === 0) {{
          ctx.moveTo(x, y);
        }} else {{
          ctx.lineTo(x, y);
        }}
      }});
      ctx.strokeStyle = "#0f766e";
      ctx.lineWidth = 2;
      ctx.lineJoin = "round";
      ctx.stroke();
      ctx.restore();
    }}

    function drawMarkers(ctx) {{
      ctx.save();
      routeMarkers.forEach((marker) => {{
        const x = xForDistance(marker.distanceKm);
        const y = yForAltitude(marker.altitudeM);
        ctx.beginPath();
        ctx.moveTo(x, y - 7);
        ctx.lineTo(x - 5, y + 5);
        ctx.lineTo(x + 5, y + 5);
        ctx.closePath();
        ctx.fillStyle = marker.stageId ? "#f59e0b" : "#64748b";
        ctx.strokeStyle = "rgba(15, 23, 42, 0.5)";
        ctx.lineWidth = 1;
        ctx.fill();
        ctx.stroke();
      }});
      ctx.restore();
    }}

    function drawHover(ctx, point) {{
      const x = xForDistance(point.distanceKm);
      const y = yForAltitude(point.altitudeM);
      ctx.save();
      ctx.strokeStyle = "rgba(15, 23, 42, 0.35)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, layout.top);
      ctx.lineTo(x, layout.height - layout.bottom);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = "#ef4444";
      ctx.strokeStyle = "white";
      ctx.lineWidth = 2;
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    }}

    function nearestPointIndex(distanceKm) {{
      let low = 0;
      let high = profile.length - 1;
      while (low < high) {{
        const middle = Math.floor((low + high) / 2);
        if (profile[middle].distanceKm < distanceKm) {{
          low = middle + 1;
        }} else {{
          high = middle;
        }}
      }}
      if (low === 0) {{
        return 0;
      }}
      const previous = profile[low - 1];
      const current = profile[low];
      return Math.abs(previous.distanceKm - distanceKm) < Math.abs(current.distanceKm - distanceKm)
        ? low - 1
        : low;
    }}

    function updateHover(event) {{
      if (!layout) {{
        return;
      }}
      const rect = canvas.getBoundingClientRect();
      const x = Math.max(layout.left, Math.min(event.clientX - rect.left, layout.width - layout.right));
      const distanceKm = ((x - layout.left) / layout.plotWidth) * totalDistanceKm;
      hoverIndex = nearestPointIndex(distanceKm);
      const point = profile[hoverIndex];

      tooltip.style.display = "block";
      tooltip.style.left = x + "px";
      tooltip.style.top = yForAltitude(point.altitudeM) + "px";
      tooltip.innerHTML =
        "<strong>" + point.distanceKm.toFixed(2) + " km</strong><br>" +
        point.altitudeM.toFixed(1) + " m<br>" +
        point.lat.toFixed(6) + ", " + point.lng.toFixed(6);
      draw();
    }}

    function clearHover() {{
      hoverIndex = null;
      tooltip.style.display = "none";
      draw();
    }}

    canvas.addEventListener("mousemove", updateHover);
    canvas.addEventListener("mouseleave", clearHover);
    window.addEventListener("resize", () => {{
      staticCanvas = null;
      renderStaticChart();
      draw();
    }});
    renderStaticChart();
    draw();
  </script>
</body>
</html>
"""
    output_path.write_text(html, encoding="utf-8")


def resolve_output_path(output_path: Path) -> Path:
    if output_path.is_absolute():
        return output_path
    return PROJECT_ROOT / output_path


def serve_route_map(output_path: Path, host: str, port: int) -> None:
    output_path = output_path.resolve()
    project_root = PROJECT_ROOT.resolve()

    try:
        url_path = output_path.relative_to(project_root).as_posix()
        serve_directory = project_root
    except ValueError:
        url_path = output_path.name
        serve_directory = output_path.parent

    handler = partial(
        RouteMapRequestHandler,
        map_output=output_path,
        url_path=url_path,
        directory=str(serve_directory),
    )

    server = create_preview_server(host, port, handler)
    with server:
        actual_host, actual_port = server.server_address
        url = f"http://{actual_host}:{actual_port}/{quote(url_path)}"
        print()
        print(f"Serving map from: {serve_directory}")
        if actual_port != port:
            print(f"Port {port} was busy; using {actual_port} instead.")
        print(f"Open: {url}")
        print("Press Ctrl+C to stop the preview server.")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print()
            print("Stopped preview server.")


def create_preview_server(
    host: str,
    preferred_port: int,
    handler: type[SimpleHTTPRequestHandler],
) -> ThreadingHTTPServer:
    if preferred_port == 0:
        return ThreadingHTTPServer((host, 0), handler)

    last_error: OSError | None = None
    for port in range(preferred_port, preferred_port + 20):
        try:
            return ThreadingHTTPServer((host, port), handler)
        except OSError as error:
            if error.errno not in {48, 98}:
                raise
            last_error = error

    raise RuntimeError(
        f"No available preview port from {preferred_port} to {preferred_port + 19}"
    ) from last_error


class RouteMapRequestHandler(SimpleHTTPRequestHandler):
    def __init__(
        self,
        *args: object,
        map_output: Path,
        url_path: str,
        **kwargs: object,
    ) -> None:
        self.map_output = map_output
        self.map_paths = {
            "",
            "route-map.html",
            url_path.strip("/"),
        }
        super().__init__(*args, **kwargs)

    def translate_path(self, path: str) -> str:
        requested_path = unquote(path.split("?", 1)[0].split("#", 1)[0]).strip("/")
        if requested_path in self.map_paths:
            return str(self.map_output)
        return super().translate_path(path)


if __name__ == "__main__":
    main()
