# Visual-guide corrections

17 October 2026 — `codex/website-feedback-v3`.

The user clarified that screenshots of the existing website in the workbook are implementation references to reuse. The initial implementation had treated them too loosely. This correction preserves the supplied Text-sheet copy and database statistics while restoring the shown compositions. The workbook itself is unchanged.

| Visual reference | Correction |
| --- | --- |
| Hero Section v2 - Visual: images 4–8, 10–12 | Keep the coastal hero, compact download strip, two-column emotional cue, large hiker card with two stacked host/sponsor cards, overlapping app phones, FAQ and compact footer. This supersedes the initial equal-width cards; the latest user instruction resolves the conflict with the Text sheet's parenthetical three-column suggestion. |
| Explore Trails - Visual: images 23–29 and A12/H12 | Restore the geographic map beside vertical database metrics, compact dark elevation profile, five-point waypoint strip, planner form on the left and day results/notices on the right, original app showcase and planning/safety panel. Accommodation directory remains available. |
| The Eurotrex Initiativ - Visual: images 31–36 | Centered landscape mission, image-left origin story, pale-blue project-phase band with three light cards, centered project focus and funding, original Join Us image-card composition. Existing team biographies remain. |
| Community & Support - Visual: images 37–38 | Restore the existing volunteer image and heading, Ways to Help list on the left and enquiry form on the right. Supplied walking philosophy, expeditions and programme information follow. |
| Become a Host - Visual: images 40–44 and M93/R53 | Restore the large host introduction, original three photo steps, three-column benefits band, green verified-stay explanation, inline sign-in/create-account form and FAQ. Registration retains the requested personal-name fields, optional company and password confirmation. Programme enquiries remain available. |
| Get Inspired - Visual | No existing-site screenshot layout is supplied for this page. Keep the supplied motivation, quotations, moderated stories, photographs and submission form. |

The map uses Mapbox's outdoors style, matching the geographic presentation in the reference, with the current Firestore route overlaid. It does not reuse mock distance/elevation figures or a stale route screenshot. The server samples the route only for image rendering, keeps endpoints, bounds the Mapbox request length and caches the image while the route is unchanged. The current database elevation profile and waypoint links remain available; a service failure falls back to the recorded route diagram. API details follow the [Mapbox Static Images documentation](https://docs.mapbox.com/api/maps/static-images/).

The embedded account form uses the existing Firebase registration/sign-in implementation. Navigation into and out of the host page loads the document so its React form handlers remain active. No new authentication method, role or rule change is required.

Validation: TypeScript, production build, itinerary/data/authentication checks (including standard encoded-path fixture and map request bounds), local enquiry/story integration smoke tests, deployment-recovery and local-preview checks. Browser checks cover desktop and 390 px mobile layouts, no horizontal overflow, account-mode switching, database map loading, programme enquiry selection and a 25.9 km Pafos Airport–Tsada itinerary in the restored planner columns. No production account or enquiry was created for these checks.

The corrected version is intended for the existing private review site with its current audience. The application review branch remains unmerged.

Published successfully to https://eurotrex.andreasmic332452.chatgpt.site on 17 October 2026. Website source commit: `b6c7247196c086cf23d8c63d293c7cb995f2679c`; deployment: `appgdep_6ad357e5d4d0819182ad9094551495b4`. The access policy immediately before this publication contained only the owner and no invited viewers; that existing owner-only access was preserved. No Firestore rules or application data were changed for this visual correction.

## Homepage follow-up

The user's subsequent review restores three equal Choose Your Path columns, replacing the large/stacked layout above. The cards stack on phones. Editorial CTAs use sand-filled buttons with dark text; arrow decorations were removed from CTA labels across the public pages. Navigation and route-direction information retain their separate purpose. Current Project Focus now uses the same uppercase section heading and yellow rule as Get Involved. The first app strip is joined directly to the hero in one continuous banner, with no intervening gap. Public account-action buttons also use the sand treatment.

Verified at desktop widths and 390 px mobile width: equal card sizes, mobile stacking, zero hero/strip gap, sand button fill, matching section-header class, CTA navigation, no CTA arrows and no horizontal overflow. The existing local 12-route/form integration smoke checks and TypeScript validation passed. This presentation change needs no database or Firestore-rule migration.

The follow-up was privately published successfully on 17 October 2026, with owner-only access preserved. Published website source: `5bcff8b28889179083dca001126fee37ee6eda40`; deployment: `appgdep_6ad37d69e19881918fef5a483d45ac2c`. The production build passed. Live browser inspection confirmed the equal columns, sand buttons, updated heading, joined hero strip and absence of CTA arrows.

## CTA restoration, coastal hero fade and mobile elevation

The next user review supersedes the sand CTA treatment above: sand remains the page canvas, while buttons use the established blue, white and white-outline variants and original animated fill hover. Newly converted editorial buttons share that animation; CTA arrow removal, the three equal path cards and matching section headings remain.

The coastal image now spans both the hero and its first mobile-app strip. A continuous sea-colour gradient fades into the strip, replacing the hard navy seam. Desktop and phone layouts keep the copy legible over the shared photograph.

Explore Trails now uses the mobile app's elevation presentation: a white rounded card, navy profile line, subtle grid and the same blue/green/gold/orange contour colours at 0/300/700/1200 metres. Recorded database geometry is smoothed with the app's seven-point average before display downsampling. Endpoints are retained and missing measurements break the profile. Desktop and phone SVG layouts keep labels readable; displayed statistics still use the recorded database values.

Validation: TypeScript; profile checks for smoothing, colour interpolation, tick spacing, gap handling and endpoint retention; the existing 12-route/form smoke checks; desktop (1280 px) and phone (390 px) browser inspection of the hero and elevation, with no horizontal overflow. No data, account access or Firestore-rule changes are required. The review branch remains unmerged.
