# Pure Truth Water Factory — Employee Loan Management System

A Salesforce Experience Cloud application that lets Pure Truth Water Factory employees apply for loans,
track approval status, and submit repayments online — with the full approval, notification, and
verification workflow automated declaratively (custom objects, validation rules, and Flows, no Apex).

This repository is the Salesforce DX (source-format) project for the org. It is the backend
implementation to the `Pure_Truth_Employee_Portal` Experience Cloud site.

## What this system does

- **Employees** log in to a self-service portal to apply for a loan, check its status, and upload
  repayment receipts against an approved loan.
- **Admins/Finance** onboard new employees, approve or reject applications, and verify submitted
  repayments — every decision automatically emails the employee and stamps who/when on the record.

## Data model

| Object | Purpose |
|---|---|
| **Salary Scale** (`Salary_Scale__c`) | Designation-based pay bands, referenced during onboarding. |
| **Account** | Repurposed as the Employee record. Extended with `Designation__c`, `Employment_Number__c`, `Employment_Date__c`, `Active__c`, `Personal_Email__c`, and `Portal_User__c` (lookup to the employee's Community login). |
| **Loan Application** (`Loan_Application__c`) | Master-detail to Account. Carries loan terms, `Status__c`, and approval/decision stamp fields. |
| **Loan Repayment Receipt** (`Loan_Repayment_Receipt__c`) | Master-detail to Loan Application. One record per repayment submission, with the uploaded bank receipt and its own verification stamp fields. |

**Validation rules:** `Affordability_Check`, `No_Active_Duplicate_Loan`, `Employee_Must_Be_Active` —
enforced at submission time on the Loan Application object.

## Automation (Flows)

| Flow | Type | Purpose |
|---|---|---|
| Employee Onboarding | Screen Flow (admin) | Creates the employee Account: personal details, designation, employment info, personal email, optional portal login link. |
| Complete My Profile | Screen Flow (portal) | Lets a logged-in employee confirm/update their own personal email. |
| Submit Loan Application | Screen Flow (portal) | Employee self-service loan application. |
| Submit Loan Repayment | Screen Flow (portal) | Employee selects an approved loan, enters repayment details, uploads a receipt. |
| Loan Application Submitted Notification | Record-Triggered (after save) | Notifies loan approvers of a new submission. |
| Loan Application Decision Notification | Record-Triggered (after save) | Emails the employee once Status changes to Approved/Rejected. |
| Loan Application Decision Email Stamp | Record-Triggered (before save) | Copies the employee's current email onto the record at decision time. |
| Loan Application Approval Stamp | Record-Triggered (before save) | Stamps `Approved_By__c` / `Approval_Date__c`. |
| Loan Application Auto-Close | Record-Triggered / scheduled | Closes a loan once fully repaid. |
| Enforce One Active Loan Per Employee | Record-Triggered (before save) | Blocks a new application while one is already active. |
| Loan Repayment Decision Notification / Email Stamp | Record-Triggered (before/after save) | Same notification pattern, applied to repayment decisions. |
| Loan Repayment Verification Stamp | Record-Triggered (before save) | Stamps `Verification_Date__c` / `Verified_By__c` on repayment verification. |

**Pattern used throughout:** a *before-save* flow stamps data quietly and can never roll back the
triggering save if it fails; a separate *after-save* flow then sends the notification email, so an
email failure never blocks the underlying record change.

## Portal (Experience Cloud)

The `Pure Truth Employee Portal` site (LWR) is not fully retrievable as source via the Metadata API
(a known CLI limitation for newer LWR-template sites), so its page layout lives in the org and is
maintained through Experience Builder directly. This repo carries everything else that governs
portal access and behavior:

- **Sharing Set** (`Portal_Employee_Access`) — maps the logged-in user to their own Account, and
  separately to their own Loan Application records (master-detail access is *not* automatically
  inherited under a Sharing Set — each object needs its own mapping).
- **Profile** (`Customer Community Login User`) — object/field-level security for the portal.
- **Custom Report Type** and standard Reports/Dashboard for loan reporting.

## Project structure

```
force-app/main/default/
  objects/          Custom objects and fields
  flows/             All Flow metadata described above
  validationRules/   (defined inline under objects/)
  profiles/          Customer Community Login User, Admin (FLS grants)
  sharingSets/       Portal_Employee_Access
  permissionsets/
  layouts/
  workflows/         Email Alerts (Loan Application decision emails)
  email/             Classic email templates
  reports/ reportTypes/ dashboards/
  applications/ tabs/ flexipages/
```

## Working with this project

```bash
# Authenticate the CLI against the org (once)
sf org login web --alias PureTruthDev

# Retrieve the current state of a component before editing it
sf project retrieve start --metadata "Flow:Submit_Loan_Application" --target-org PureTruthDev

# Deploy a change back
sf project deploy start --metadata "Flow:Submit_Loan_Application" --target-org PureTruthDev
```

Profile metadata deploys are additive — deploying one new `fieldPermissions` block does not remove
any existing grants, so partial profile deploys are safe.

**Known gotcha:** Experience Cloud page metadata (`ExperienceBundle`) cannot currently be retrieved
through this CLI for this org's site — page composition changes must be made and verified directly
in Experience Builder.

## Documentation

Full project documentation — data model design, user stories, UAT test script, a complete technical
change log of every fix made during development testing, and a condensed project summary — is
maintained alongside this repository.
