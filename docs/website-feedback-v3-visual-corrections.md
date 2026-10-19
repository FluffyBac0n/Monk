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

Published successfully with owner-only access preserved on 17 October 2026. Website source: `2ba157e429166880bfd79536b643d748b08c0a45`; deployment: `appgdep_6ad38417d348819187b53efbb13c93c3`. The production build passed. Live inspection confirmed the shared hero photograph, transparent app strip and restored outline CTA.

## Explore Trails simplification — 18 October 2026

The user's next review removes Notify Me from desktop and mobile navigation, the trail intro/freshness/subnavigation block, the elevation caption, the five-points eyebrow and the planner caveat. ERA remains available as a plain text link. The extra planning/safety prose is removed so the page follows the supplied Explore Trails Text sheet without additional editorial filler.

The five content sections now share the landing page's uppercase section-title typography, yellow rule and spacing: Trail Overview Dashboard, Daily Stage Planner, Smart Multi-Day Itinerary, Live Trail Conditions Noticeboard and Accommodation Directory. The shared app download section follows them. The noticeboard is a separate section rather than being nested inside planner results. White bordered statistic/form cards use the existing rounded controls and brand colours. The towns display as Paphos – Larnaca; numerical statistics still come from the database.

The map uses the mobile app's white-ring green/red flag artwork and colours (#277653/#D14B45), replacing A/B pins. The static map and responsive flag overlays share an explicit Mercator camera, preserving endpoint alignment. Camera fitting follows the [Mapbox Static Images API](https://docs.mapbox.com/api/maps/static-images/). The recorded-route fallback also shows flags.

Accommodation results and counts are absent until a search is submitted or a direct search link is followed. Search pagination and itinerary View stays links preserve the search state. An explicit empty-filter search can show all results; a non-matching query shows the existing empty-result message.

The requested design/copy preference is recorded in the workspace AGENTS.md: new UI must reuse the existing look and feel and relevant Excel Text sheets, with no unnecessary explanatory text and no mock statistics.

Validation: TypeScript; map camera alignment, padding, coincident endpoint and URL-length checks; existing profile/itinerary/auth checks; the 12-route/form integration suite plus initial/search/empty accommodation cases; desktop and 390 px mobile browser review with no horizontal overflow. Live data and Firestore rules are unchanged. The application review branch remains unmerged.

Published privately on 18 October 2026 with owner-only access preserved. Website source: `631b9535bddb4f5b3e4bd8ae8538e8835a3ccb91`; deployment: `appgdep_6ad463e9e6cc81919bbb7bf9fe54055f`. Production build passed. Live inspection confirms the five matching section titles, no navigation notification button, zero accommodation cards before search and no horizontal overflow. The restyled planner returns one walking day, 25.9 km, for Pafos Airport–Tsada.

## Dropdowns, section separators and in-place searches — 18 October 2026

The planner and accommodation dropdowns now use 56 px controls with 16 px text; the planner form column is wider on desktop. Accommodation search has a matching Reset action that clears filters and results. Search, reset and pagination update only their own section through HTMX, preserving scroll position. Planner calculation/reset likewise update in place. Partial requests preserve the other section's submitted parameters from the current URL, preventing a stale form from discarding an existing itinerary or accommodation search.

The landing page and Explore Trails reuse the original trail-divider CSS: a dotted line with a yellow centre circle. Dividers separate the existing content sections; the hero and attached app strip remain one banner. Crete and Peloponnese retain their visible Coming soon labels as disabled, non-focusable text rather than links.

Validation includes TypeScript, runtime syntax, existing data/profile/itinerary/auth checks and local route/form smoke checks. Desktop browser checks confirm all three dropdowns are 56 px high with 16 px text, both future trails have no href, five Explore dividers are present, accommodation search stays at the same scroll position, and Reset clears filters/results in place.

Published privately on 18 October 2026, preserving owner-only access. Website source: `37a0d118d35ae9a20e08e551979456928b551533`; deployment: `appgdep_6ad4673614d88191b88dbbebb560d671`. Production build passed. Browser checks also confirmed six landing-page dividers, no horizontal overflow at 390 px, unchanged accommodation search scroll position, and preservation of both the 25.9 km Pafos Airport–Tsada itinerary and accommodation search across independent updates. Live inspection confirmed the enlarged dropdown, Reset, separators and non-clickable future trail labels.

## Restore the final visual-reference section — 18 October 2026

The user clarified that the last section in Explore Trails - Visual is required. Image29.png, anchored at row 51, shows the final two-column Shape your own walk / Before you walk section. The earlier copy simplification removed it too broadly. It is restored after the app showcase as the final content section, preceded by the existing dotted separator.

The restoration reuses the existing typography, planning rows, navy safety panel, four numbered items and emergency number from the screenshot. The Walk either way text also follows the reference. Desktop and 390 px phone inspection confirm two columns / stacked layout respectively, with no horizontal overflow. TypeScript passes. No search behaviour, data or access changes are required.

Published privately with owner-only access preserved on 18 October 2026. Website source: `033ae4ef6ade84ca0cf64cdae8f67ac9bf7d2b5a`; deployment: `appgdep_6ad468104a148191910dd90dae59cfc9`. Production build passed. Live browser inspection confirms the restored final section and its reference text. The application branch remains unmerged.

## Hero separator correction — 18 October 2026

Removed only the first landing-page dotted divider, which collided with the connected hero/app banner. The five later landing-page dividers remain. Published privately with owner-only access preserved: website source `5de7877023cc3b4ec4028c1306e49ad88f9dc8f3`, deployment `appgdep_6ad468c905948191a68afb9bb662eae9`. Production build passed; live DOM inspection confirms the manifesto follows the hero directly, with five later dividers. The review branch remains unmerged.

## Shape Your Own Walk section heading — 18 October 2026

Promoted Shape Your Own Walk to the shared uppercase section-title style with its yellow rule, spanning above the existing two-column content. The two content headings are now subordinate headings while retaining their previous sizes. TypeScript and the production build passed. The review branch remains unmerged.

Published privately, preserving owner-only access. Website source: `787d9279fe8524ac77bac05f259a4c110728b808`; deployment: `appgdep_6ad469664a848191a1279964b78b96b8`. Live inspection confirms the h2 section-title, yellow rule, and no horizontal overflow at desktop and 390 px phone widths.

## Landing-page action hierarchy — 19 October 2026

Notify Me now shares the hero Explore button's transparent outline, corner radius, size and fill animation throughout the shared app sections. Notification controls on light surfaces, including the notification form and future-trail previews, use the same outline treatment in navy for contrast. Loading text remains hidden until a submission is in progress.

Choose Your Path restores the original full-card links with animated yellow lines and end dots; keyboard focus also expands the line. Get Involved uses plain underlined links with comfortable touch targets. The first and last remaining landing-page dividers were removed, leaving three internal separators. No editorial wording, form-submission behaviour or audience changed.

Validation: TypeScript; existing local route/form integration checks; desktop and 390 px phone browser review; notification dialog opening/closing and idle submit label; three linked path cards; 28→46 px line animation on keyboard focus; three remaining dividers; Get Involved contains links rather than buttons; no horizontal overflow.

Published privately with owner-only access preserved on 19 October 2026. Website source: `ccf11c83f318b98005a9beacc518e3589e5f0592`; deployment: `appgdep_6ad6658f7f3481918d366ccf7187c217`. Production build passed. Live inspection confirms three remaining separators, three animated card links, four Get Involved text links and matching outline Notify Me controls. The application branch remains unmerged.

## Landing text size and app-section navigation — 19 October 2026

Desktop navigation and editorial card-action labels now use 12 px text. The landing manifesto's Get Inspired action is a plain underlined link. The entire For Hikers card targets the existing #hikers app showcase on the same page; HTMX boosting is disabled for this local anchor so it does not open Explore Trails.

TypeScript and desktop/390 px browser checks pass: 12 px navigation/card labels, no horizontal overflow, no desktop navigation overlap, Get Inspired link styling, and the Hikers card staying on the homepage with #hikers visible beneath the header.

Current Project Focus has not been redesigned in this correction. The suggested next direction is a split photo/copy feature with a panoramic Cyprus trail image, the supplied text, and a compact row of database trail statistics, preserving the established yellow heading and sand canvas.

Published privately with owner-only access preserved on 19 October 2026. Website source: `63d7caad6e5890824a80582ef36db3abe6ab1bb2`; deployment: `appgdep_6ad66826e9688191846fa0c79e3b2365`. Production build passed. Live checks confirm 12 px navigation/card actions, Get Inspired as a link, and the Hikers card navigating to /#hikers without leaving the homepage. The review branch remains unmerged.
