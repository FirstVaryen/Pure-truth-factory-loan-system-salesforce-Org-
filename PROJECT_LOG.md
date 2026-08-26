# Pure Truth Loan Management App — Project Log

Read this file first in any new session before touching the org. It records what's built, the *correct* way to build each piece (learned the hard way), and what's still broken. Point me at this folder and I'll pick up from here.

## How to resume

```bash
cd "C:\Users\hilla\OneDrive\Desktop\dev sprint\loan-management-sfdx"
sf org login web --alias PureTruthDev --set-default   # only if the session errors on auth
```

- Org alias: `PureTruthDev`
- Test portal user: `portal.tester@example.com` / `[removed]` (Stanley Howard, Factory Supervisor, Gross $1,800/mo)
- Site: `https://orgfarm-069ab8bab7-dev-ed.develop.my.site.com` (Network status still shows `UnderConstruction` — remember to click **Publish** in Builder after any page edit, separate from deploying metadata)
- On Windows, `sf` commands sometimes fail via the Bash tool with `'C:\Program' is not recognized` — use PowerShell instead when that happens.

## What's built

**Data model** — Salary Scale, Account (repurposed as Employee), Loan Application, Loan Repayment Receipt. All objects/fields came from a pre-installed package; only 4 fields were added (Approved_By__c, Approval_Date__c, Verified_By__c, Verification_Date__c) plus later Applicant_Email__c on both Loan objects.

**Validation rules** (3, on Loan Application): `Affordability_Check` (36% of gross salary), `No_Active_Duplicate_Loan`, `Employee_Must_Be_Active`.

**Flows** (13):
- `Employee_Onboardin` — Screen Flow, Finance Officer creates Account. **Known gap**: does not set `Portal_User__c` or `Personal_Email__c` — these must currently be set manually per new employee (see Known Issues).
- `Submit_Loan_Application`, `Submit_Loan_Repayment` — pre-existing employee self-service Screen Flows (found mid-session, not originally built by us — see "Lessons" below on why this matters).
- `Enforce_One_Active_Loan_Per_Employee` — record-triggered duplicate-loan gate.
- `Loan_Application_Submitted_Notification`, `Loan_Application_Approval_Stamp`, `Loan_Repayment_Verification_Stamp`, `Loan_Application_Auto_Close` — record-triggered automation.
- `Loan_Application_Decision_Email_Stamp` / `Loan_Application_Decision_Notification` and the matching Repayment pair — approve/reject email notifications to the employee.
- `Loan_Application_Screen_Flow` (my own early build) — marked **Obsolete**, superseded by the pre-existing `Submit_Loan_Application`. Don't resurrect it.

**Email**: 4 templates + 4 Email Alerts (`unfiled$public` folder / Loan_Application__c & Loan_Repayment_Receipt__c workflows), each keyed off a real **Email-type** field (`Applicant_Email__c`), populated by a before-save stamp flow at decision time.

**Portal (Experience Cloud)**: site "Pure Truth Employee Portal", `Customer Community Login User` profile carries all portal object/field permissions, custom Report Type `Loan_Applications__c`, Sharing Set `Portal_Employee_Access`. Home page has a styled hero (starry navy gradient), 3-step cards, embedded `Submit_Loan_Application`/`Submit_Loan_Repayment` Flow components, shared header/footer (Theme Layout "Scoped Header and Footer" — edits to it apply site-wide, can't differ per page), Login/Log Out buttons split via component Visibility rules (`User > isGuest` Equal `True`/`False`).

**Reporting**: 4 Reports + 1 Dashboard, built via the UI Report Builder (not metadata — see Lessons).

**Deliverables** (in `dev sprint/deliverables/`): Data Model doc, User Stories doc, Progress PPT, Flow schema diagrams.

## Lessons — the correct way to build each of these (to avoid repeating errors)

1. **Flow metadata element ordering is strict and alphabetical** at the top level (`apiVersion`, `assignments`, `decisions`, `formulas`, `interviewLabel`, `label`, `processType`, `recordCreates`, `recordLookups`, `screens`, `start`, `status`...). Same-type elements (e.g. all `<decisions>` blocks) must be grouped together, never interleaved with other types. Deploy errors like "Element X is duplicated at this location" mean ordering, not actual duplication.

2. **`$User` global variable only exposes a few fields** (Id, Username, Email...) — it does **not** expose `AccountId`. To get a portal user's Account, either query `User` by `$User.Id` first and use its `AccountId`, or (the pattern the pre-existing flows use, and the better one) query `Account` directly filtered on a custom lookup field like `Portal_User__c = $User.Id`.

3. **Formula fields can never be written to.** `Loan_Duration__c` is `(Loan_End_Data__c - Loan_Start_Date__c)/30` — trying to set it directly in a `recordCreates` fails with `INVALID_FIELD_FOR_INSERT_UPDATE` no matter what FLS says. Set the underlying date field instead and let the formula compute itself.

4. **Custom Report Types need a `__c` suffix when referenced from a Report**, even though the file/folder name doesn't show it (e.g. `reportType>Loan_Applications__c` even though the ReportType's own file is `Loan_Applications.reportType-meta.xml`). Report `<columns><field>` values also need exact mixed-case API names except the primary Name field, which is just `Name`.

5. **Raw XML authoring for Reports is unreliable** — kept hitting inconsistent "Invalid field name" errors that didn't reproduce logically. If report/dashboard XML fights you, stop and build it in the UI Report Builder instead; it's genuinely faster.

6. **Two separate "sharing" layers for external/portal users**, both of which gate access independently of Profile object/field permissions:
   - **External Sharing Model** (`externalSharingModel` on the CustomObject, distinct from the internal `sharingModel`) — if Private, portal users get zero row access regardless of profile. Salary_Scale__c was stuck on Private and silently returned empty query results with no error.
   - **Sharing Set** — needed for a portal user to have sufficient access to a parent record when *creating* a master-detail child (`INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` on Account otherwise). Metadata type `SharingSet`, `accessMappings` with `accessLevel`/`object`/`objectField`/`userField` — only standard-ish objects seem to work directly as the `object` value; mapping the custom child object directly threw `bad value for restricted picklist field`, so we only mapped `Account` and let the master-detail relationship cascade sharing down to Loan Application automatically.
   - Session/permission changes don't apply to an already-logged-in portal user until they log out and back in (or at least a hard refresh) — always retest with a fresh session.

7. **Never assume `$Record` is excluded from its own after-save queries.** `Enforce_One_Active_Loan_Per_Employee` queried "other active loans for this applicant" without excluding `$Record.Id` — since it's an *after*-save trigger, the record already exists in the query results, so it matched itself and blocked every first-ever application. Any after-save flow that queries siblings of the same object must filter `Id != $Record.Id`.

8. **Picklist values with stray formatting (trailing commas etc.) will silently desync from anything that hardcodes the "clean" version.** Found `"Submitted,"`, `"Approved,"` etc. baked into the original picklists. Fixed the picklists, then had to hunt down and fix 8 separate hardcoded references across 6 flows that used the old comma values.

9. **Live/per-keystroke field validation formulas** (`<validationRule>` on a screen field) only re-evaluate when *that specific field* changes — not when a field it depends on changes. If the formula spans multiple fields (e.g. amount vs. duration), move the check to a Decision element evaluated once on Next instead, or users get stuck on stale error messages.

10. **Before building something from scratch, check what already exists.** Lost real time mid-session rebuilding `Submit_Loan_Application` from zero before discovering the org already had a more complete pre-existing version (dynamic Loan Reason picklist, cleaner Account lookup pattern, inline file upload for receipts). Always `sf org list metadata --metadata-type Flow` (and similarly for other types) before building something that sounds like it should already exist.

11. **`ExperienceBundle` (the LWR site's page/component content) is not reliably retrievable via this org's Metadata API** — returns "Nothing retrieved" even with a wildcard. Page/header/footer content has to be edited live in Experience Builder, not via metadata deploy. HTML Editor components (raw HTML+inline CSS, no `<style>` blocks) are the one place you *can* hand-author real design there.

## Known unresolved issues

- **Home page's "2. Get Approved" and "3. Repay" card links are broken** — clicking them (or typing the URL directly) redirects back to Home instead of showing the Loan Application / Loan Repayment Receipt list pages. Was mid-diagnosis: suspect a **Page Access** restriction on those specific pages in Experience Builder (Page Settings → Page Access — separate from object/field CRUD permissions, controls whether a page route is reachable at all). Not yet confirmed or fixed.
- **`LAN-00001` (Stanley's test loan) is still sitting at Status = Submitted** — the approval attempt was blocked by the email bug (since fixed) but wasn't redone. Needs: open the record as admin, set Status = Approved, confirm it saves and the approval email fires.
- **Repayment flow only tested up to its first screen** — blocked until a loan is actually Approved (repayment flow looks up an Approved loan to attach to).
- **Employee Onboarding Flow doesn't set `Portal_User__c` or `Personal_Email__c`** — currently a manual data-fix step per new employee (done via anonymous Apex for Stanley). Should be added as fields on the Onboarding screen, or as a follow-up manual-provisioning step, before this is used for real employees.
- **About Us / News content pages** — not built.
- **Employee Offboarding / Deactivation flow** — not built (was on the "more flows" list).
- **Implementation Document and UAT test script** — not started. The "Lessons" and "Known unresolved issues" sections above are exactly what should seed both.

## Suggested order for next session

1. Fix Page Access on the two broken list pages.
2. Approve LAN-00001, confirm email, test repayment (upload receipt, verify, confirm auto-close works when balance hits zero).
3. Fix the Onboarding Flow gap (Portal_User__c / Personal_Email__c).
4. Write Implementation Doc + UAT script from this log.
5. About Us/News + Offboarding flow, if still wanted.
