# Silver Sidewalk â Mirrosa AI Storefront Kiosk (POC)

Phase 6 proof-of-concept. A storefront-facing kiosk that captures a guest's photo via webcam, sends it to the existing Mirrosa Phase 1 API for AI skin analysis, and displays personalized facial recommendations on a large TV display. A QR code hands off to the full web app on the guest's phone.

## Hardware (POC Setup)

- **MacBook Pro 16" (2024)** â runs Chrome in fullscreen (kiosk mode)
- **Logitech Brio 4K** â USB webcam pointed at pedestrians through the window
- **Samsung TV** â connected to MacBook via HDMI (MacBook mirrors/extends display)
- **Later:** Two-way mirror acrylic from TwoWayMirrors.com (1/4" sheet, custom-cut to TV dimensions)

## Quick Start (Local)

```bash
npx serve public -l 3001 --cors
```

Then open Chrome and go to: `http://localhost:3001`

For fullscreen kiosk mode on the TV:
1. Open Chrome on the TV display
2. Navigate to `http://localhost:3001`
3. Press F11 for fullscreen
4. Press C to open the config panel (hidden by default)

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **C** | Toggle config panel (API URL, mock/live mode, timeout) |
| **Space** | Advance to next state (for testing without FaceDetector API) |
| **Escape** | Reset to attract screen |

## State Machine

```
ATTRACT â ENGAGE â COUNTDOWN â ANALYZE â RESULTS â (idle timeout) â ATTRACT
                                    â
                                  ERROR â (15s) â ATTRACT
```

1. **ATTRACT** â Eye-catching "Discover Your Perfect Facial" screen. Face detection polls the webcam every 300ms. When a face is detected for 4+ consecutive checks, transitions to ENGAGE.

2. **ENGAGE** â Shows the camera feed with a face guide oval. Requires a stable face for ~2.4 seconds before proceeding. If the person walks away, returns to ATTRACT.

3. **COUNTDOWN** â 3-2-1 countdown with the camera visible in the corner. Captures the photo at zero.

4. **ANALYZE** â Sends the photo to the Mirrosa API. Shows step-by-step progress. In mock mode, simulates a 3.5 second analysis with realistic results.

5. **RESULTS** â Displays recommended facial, add-ons, products, and a QR code. A progress bar at the bottom counts down to the idle timeout (default 60 seconds), then returns to ATTRACT.

6. **ERROR** â Displays error message with a "Try Again" button. Auto-returns to ATTRACT after 15 seconds.

## Mock Mode vs Live Mode

**Mock mode (default):** No API calls. Returns realistic sample data. Use this for testing the UI, camera, face detection, and the full flow without needing the API running.

**Live mode:** Calls the actual Mirrosa Phase 1 API at `mirrosa-webapp.vercel.app`. Sends the front-facing photo for all three required angles (front, left, right). Submits a survey with safe defaults (not pregnant, no concerns pre-selected, Fitzpatrick left blank for AI determination with IV+ safety fallback).

**CORS Note:** The live API may not accept cross-origin requests from the kiosk domain. For local development, this is usually not an issue. For production, either add CORS headers to the mirrosa-webapp API endpoints, or proxy API calls through this project's Vercel deployment.

## API Flow (Live Mode)

```
1. POST /api/analysis-jobs          â Upload photo (frontÃ3) â get jobId
2. POST /api/analysis-jobs/{id}/survey  â Submit safe defaults
3. POST /api/analysis-jobs/{id}/run-analysis â Run GPT-4 Vision analysis â get results
4. Display results + generate QR code pointing to web app with ?mirrosa_source=kiosk
```

## QR Code Handoff

The QR code on the results screen links to:
```
https://mirrosaai.silvermirror.com?mirrosa_source=kiosk
```

When the guest scans this on their phone, they land on the full Phase 1 web app where they can:
- See their detailed results
- Enter their email/phone for lead capture
- Book a facial

The `mirrosa_source=kiosk` parameter lets us track that this lead originated from the storefront kiosk.

## Face Detection

Uses the Chrome [FaceDetector API](https://developer.chrome.com/docs/capabilities/shape-detection#facedetector) when available. This is a native browser API (no external ML models to load) and works well with the Brio's high-quality video feed.

If FaceDetector is not available (non-Chrome browsers, or Chrome without the flag), use the **Space** key to manually advance through states for testing.

To enable FaceDetector in Chrome (if not already enabled):
1. Navigate to `chrome://flags`
2. Search for "Experimental Web Platform features"
3. Enable it
4. Restart Chrome

## Deployment to Vercel

```bash
# Install Vercel CLI if needed
npm i -g vercel

# Deploy
vercel --prod
```

The project deploys as a static site. No build step needed.

## Project Structure

```
mirrosa-kiosk/
  public/
    index.html     â The entire kiosk app (self-contained)
  package.json
  vercel.json      â Vercel deployment config
  README.md
```

## What This Does NOT Do (Yet)

- No left/right profile photos (front only for POC â AI still works but with less accuracy)
- No lead capture on the kiosk itself (happens via QR code handoff to phone)
- No two-way mirror integration (just a TV for now)
- No Raspberry Pi build (MacBook as compute for POC)
- No questionnaire (uses safe defaults)
- No Boulevard booking integration (QR links to general booking page)
