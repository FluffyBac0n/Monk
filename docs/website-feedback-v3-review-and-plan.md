# Website feedback review and delivery plan

Reviewed 17 October 2026.

Historical review: the user subsequently authorized implementation on `codex/website-feedback-v3`, using the Text sheets and database statistics, with programme enquiries first. See [the implementation handoff](website-feedback-v3-implementation.md) for the delivered scope and validation.

Source: [feedback workbook](</Users/amich/Desktop/Website Design - v3 - Added Host Portal.xlsx>), all 12 worksheets and 44 distinct embedded images. Worksheet/cell references below refer to that workbook. Current implementation was assessed from the website and relevant shared data source files in this checkout. The deployed website, production account state and runtime behaviour were not re-tested for this review.

The workbook is stakeholder feedback to evaluate. This review authorizes no implementation, publication, payments, invitations or access changes. The workbook and application source remain unchanged by this review.

**Recommendation:** deliver an editorial and host-onboarding release first, followed by practical additions to Explore Trails. Treat the web itinerary planner and paid host/member programmes as separate product work. Preserve the existing host approval, listing review and trail-report infrastructure.

**1. What the feedback means for the existing site**

| Area | Workbook proposal | Current source | Recommended action |
| --- | --- | --- | --- |
| Homepage | Emotional introduction; hikers/hosts/sponsors; Cyprus focus; compact involvement links. `Hero Section v2 -Text`, A12:A49. | Existing hero, emotional copy, three audience cards, full hiker showcase, host process, involvement grid and FAQ. | Refine the hierarchy and copy. Add Get Inspired and Cyprus-focus links; move long explanations to their destination pages. Reuse the existing visual system. |
| Navigation | Explore Trails, Get Inspired, The Eurotrex Initiative and Community & Support appear in the visual annotations. | For Hikers, For Hosts, Explore Trails, Join Us, About Us; separate portal/report/notification actions. | Agree one sitemap, then update desktop, mobile and footer navigation together. Keep operational account links distinct from public content. |
| Explore Trails | Maps, elevation, facilities, accommodation, daily stages, planner and conditions. `Explore Trails - Text`, A12; `Explore Trails - Visual`, A5:H14. | Cyprus overview, route image, searchable 123-point directory, point-level services/elevation, schematic locators and snapshot accommodation entries. No web itinerary engine was identified. | Improve the existing guide incrementally; specify the planner separately. Reuse route-data loading and approved-issue infrastructure where appropriate. |
| Get Inspired | Motivation, quotes, stories, photographs and submissions. `Get Inspired - Text`, A5:A72. | No dedicated page or story publishing workflow identified. | Start with an editorial page and a small approved collection. Add moderated submissions after defining consent, review and publication responsibilities. |
| The Eurotrex Initiative | Origin, founders, Cyprus focus, expansion phases and funding. `The Eurotrex Initiative - Text`, A13:A18. | `/about` already contains founder biographies and the website/app/portal explanation; funding marks exist in the footer. | Expand `/about` into the Initiative page, retaining the team content and existing URL. Present future expansion as an intention. |
| Community & Support | Walks and pace, expedition schedule, opportunities, collaboration and support. `Community & Support - Text`, A12:A15. | `/get-involved` already has volunteer/collaboration/field-walk enquiries; `/partnerships` has sponsorship enquiries. | Expand these pages and reuse their forms. Show confirmed dates or a clear no-dates-yet state. Keep sponsorship enquiries working while commercial terms are decided. |
| Become a Host | Dedicated introduction, process, benefits, account entry, FAQ and verification badge. `Become a Host - Visual`, A4:A110 and R53. | Host process exists on the homepage; `/portal` already provides authentication, access review, saved drafts, listing submission and review status. | Add a public `/become-a-host` landing page that leads into the existing portal. The workbook does not specify a replacement authenticated dashboard. |
| Host registration | First name, surname, optional company, email, password and confirmation. `Become a Host - Visual`, M93. | Registration requires company name; `OwnerProfile`, registration writes and Firestore rules expect `businessName`. | Change the full account flow, data validation and admin display together. Support individuals and organisations while retaining existing company-only accounts. |
| Host programmes | Partner Host: at least 10% member discount; Premium Host: sponsored placement; Friends of the Path: donation-based hosting around EUR 20; paid Member users. `Become a Host - Text`, A12. | These commercial roles, member entitlements, payment flows and ranking rules are not defined in the inspected website models. | Hold these for a separately agreed product specification. They affect the mobile app and operations as well as the website. |

The current evidence is in [homepage source](</Users/amich/Documents/Monk 2/www/app/page.tsx>), [public navigation](</Users/amich/Documents/Monk 2/www/components/PublicHeader.tsx>), [host registration](</Users/amich/Documents/Monk 2/www/components/AuthPanel.tsx>), [owner workspace](</Users/amich/Documents/Monk 2/www/app/portal/page.tsx>), [profile model](</Users/amich/Documents/Monk 2/www/lib/models.ts>), [profile creation and approval](</Users/amich/Documents/Monk 2/www/lib/accommodations.ts>) and [Firestore rules](</Users/amich/Documents/Monk 2/www/firestore.rules>).

**2. Decisions to settle before implementation**

| Decision | Recommended starting position | Why it matters |
| --- | --- | --- |
| First release scope | Revised public pages, individual-host signup and practical trail information. | Gives the feedback a deliverable scope without making membership and planner development prerequisites. |
| Public information structure | Home; Explore Trails; Get Inspired; The Eurotrex Initiative; Community & Support; a dedicated Become a Host page; existing portal and reporting areas. | The workbook changes page purposes, not only labels. |
| Host badge meaning | Use one defined listing-verification standard, with a documented review process and removal/review criteria. | Existing review concerns authority, contact details and trail relevance. “Certified” suggests a programme that needs defining. Payment should not silently imply verification. |
| Commercial model | Keep the initial listing workflow; specify eligibility, benefits, pricing and placement separately before offering tiers. | The workbook does not explain member identification, discount redemption, renewal, cancellations or ranking order. |
| Planner scope | Keep trip planning in the app for the initial website release; scope a web planner next. | The requested engine is substantial functionality, with inputs that can conflict. |
| Stories | Begin with editor-selected material and a named reviewer. | A user-upload button introduces storage, permissions, review and removal work. |

These are proposed defaults for review, not approved business policies.

**3. Recommended delivery sequence**

Effort labels below are relative implementation scope, not calendar commitments.

**Phase 0 — Approve the content and scope brief. Small implementation effort; stakeholder input required.**

- Resolve the decisions above and assign one person to approve public copy and host criteria.
- Confirm the sitemap, programme terminology and the claims that can be supported now.
- Collect approved photographs, permissions/credit details, quote sources, funding wording and any confirmed expedition information.
- Record each workbook item as accepted, revised, deferred or needing clarification.

Completion: an agreed first-release backlog and copy outline, with unresolved commercial features clearly deferred.

**Phase 1 — Public pages and navigation. Medium.**

- Update the homepage to: hero → short emotional introduction with Get Inspired link → audience choices → Cyprus project focus → app availability → concise community links and FAQ.
- The text requests three side-by-side audience columns, while the screenshots show the current large-hiker/smaller-hosts-and-sponsors arrangement. Recommended default: three balanced desktop cards, stacked on mobile; confirm in a single layout review.
- Create `/get-inspired` with edited motivation copy and approved material. Avoid empty galleries or submission buttons without a working destination.
- Expand `/about` as The Eurotrex Initiative: origin, founders, current work, three expansion phases and confirmed funding acknowledgement.
- Expand `/get-involved` as Community & Support. Preserve existing enquiries and `/partnerships`. Use explicit no-openings/no-dates states when appropriate.
- Add `/become-a-host` with introduction, host eligibility, how it works, benefits, verification explanation, FAQ and account/sign-in links.
- Keep `/about`, `/get-involved`, the stage URLs and portal URLs working. If any address changes, add redirects and update metadata/sitemap links.
- Keep confirmed app-store links separate from notification/testing calls to action.

Completion: every public link has a useful destination; desktop and mobile navigation agree; pages do not promise unavailable programmes or app features.

**Phase 2 — Host signup and verification. Medium; schema and permissions work.**

- Add first name, surname and password confirmation; make company/organisation optional. Password confirmation is checked during signup and is not stored as profile data.
- Extend the private owner profile and update registration, allowed field lists, validation, admin review labels and backward compatibility together. A form-only change will be rejected by the current Firestore rules.
- Support existing company-only profiles without requiring fabricated personal names or overwriting historical records.
- Retain email verification, administrator activation and separate accommodation approval. A new registrant cannot grant themselves verification, a tier or publishing privileges.
- Keep private contact identity out of public lodging records. Publish only intended accommodation contact information.
- Align any badge on website and app listings with explicit reviewed status; imported or merely submitted entries must not automatically gain it.
- Confirm who operates the review queue before promising a turnaround time. Current UI copy says 1–3 days.

Completion: individual and organisation signup both work; old accounts remain usable; pending/rejected/disabled accounts remain restricted; approved listing updates still require review before changing the app-facing record.

**Phase 3 — Explore Trails improvements. Medium; some data/UI work.**

- Add accurate route metrics, units and direction from the maintained trail dataset, plus the date and meaning of the data snapshot.
- Add the web elevation overview and clearer connections between map, named points, facilities and accommodation. Preserve the distinction between reference points and proposed walking days.
- Offer a useful directory/filter view over approved public lodging fields. Decide the refresh method so public web stays do not drift from app-published listings; the current page-level stays use a snapshot.
- Add a conditions noticeboard using approved `trailIssues` projections. Reuse the existing review pipeline; do not expose private reports, reporter identities, photos or internal notes through the public feed.
- Show dates, empty/error states and removal of resolved notices. An empty noticeboard should not imply that the trail is confirmed clear.
- Keep future routes clearly marked until usable route data is ready.

Completion: web/app records and route totals agree; public pages expose approved data; map/elevation/service views remain usable on mobile and slow connections.

**Release checkpoint — Review and validate Phases 1–3 before publication.**

Review responsive layouts, keyboard access, contrast, image sizes and loading; navigation/history across public and authenticated pages; metadata and retained URLs; forms and consent; and owner/admin permissions. Run relevant existing site and emulator tests, including host approval and listing update/removal. Do not treat an unexecuted historical test result as validation of new changes. Review the candidate on a private preview and confirm the actual current deployment/access state before any separately authorized publication.

**Phase 4 — Web itinerary planner. Large; separate specification and estimate.**

- Define start/end, direction, desired days, distance limits, elevation/effort and camping preferences. Decide which constraint wins when a requested day count and distance limit cannot both be met.
- Define how accommodation, gaps between services and unavailable/uncertain camping information affect an itinerary. Return a clear infeasible-plan result rather than silently breaking constraints.
- Agree whether the first version is a simple suggested day split or a full accommodation-aware planner; these have different scope.
- Use the mobile planner's documented behaviour as a reference and common fixtures to compare results. The existing planner is Dart code, so web reuse needs an intentional shared-service or porting decision.
- Provide reset, editable days, visible daily distances/elevation and a useful app handoff. Saving or syncing plans is an additional account/data decision.

Completion: agreed example journeys match between platforms; incompatible inputs, reverse direction, sparse accommodation and no-solution cases behave predictably.

**Phase 5 — Commercial programmes and community submissions. Large; separate product decisions.**

Specify Partner/Premium/Member benefits, member verification, discount redemption, expiry, sponsorship placement/disclosure and administrative controls. Define the Friends of the Path host-review and contact flow, capacity/availability and what the suggested contribution means before presenting it as an active offer. Separately specify payments, recurring membership, app entitlements and support ownership if these are approved.

For stories/photos, define contribution permission, file limits, storage/access, moderation, approval and removal. Begin with moderated submissions; do not auto-publish user material. These features need their own acceptance criteria and estimate after scope decisions.

**4. Content inconsistencies to resolve**

- The Explore Trails mockup contains placeholder-looking metrics: “TOTAL DISTANCE” shows 12,450 m, the elevation value is also 12,450 m, and an alternative distance is 539 km. The current source snapshot is about 558.1 km with 123 named points. Reconcile against the intended route/version; do not copy screenshot numbers into production.
- The workbook refers to daily 20–30 km blocks. The current 123 stage points are reference locations, not 123 daily walking stages. Any daily schedule must be separately curated or generated.
- “Official ERA-verified alignment” is proposed in `Explore Trails - Text`, A12. Obtain the supporting route/version and permission for any relationship claim before using that wording.
- Funding text is proposed in `The Eurotrex Initiative - Text`, A15:A17. Confirm the exact acknowledgement, programme link and artwork. The note in L17 about supervision is not evidence of endorsement or technical certification.
- The same quote is attributed to Jake Dartington in `Get Inspired - Text`, B11 and Alexios in `Get Inspired - Visual`, B12. Resolve this and verify the remaining attributions before publishing.
- A note in `The Eurotrex Initiative - Text`, L13 says photographs came from a free-use website. Obtain the source and actual usage/credit terms for each chosen asset. The workbook's mockups alone do not establish those details.
- “Certified,” “verified,” “partner” and “premium” need distinct definitions; do not let sponsorship and verification become interchangeable labels.
- Donation, jobs, expedition, story and membership buttons need real destinations and owners. Use accurate availability states where the programme is still a proposal.

**5. The next concrete action**

Agree the first-release brief with the feedback author, using the proposed sitemap and decision table above. Then prepare one responsive homepage/host-page layout review before implementation. Implement in the sequence public pages → signup/schema → trail additions → validation, with the planner and commercial programmes held in separate backlogs.
