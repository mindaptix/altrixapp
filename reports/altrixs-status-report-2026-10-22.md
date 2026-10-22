# Altrixs App — Status and Regression Report

Report date: 22 October 2026  
Prepared for: Andy  
Overall status: Apple conversion awaiting confirmation; device regression verification pending.

## 1. Apple Developer account conversion

Scope: Convert the existing Individual membership to an Organization membership for Altrixs LLC. This is not a confirmed transfer of the app to another team.

| Item | Status | Evidence / next action |
|---|---|---|
| Conversion request submitted | Confirmed from screenshot | Apple submission confirmation shown on 15 October 2026. |
| Organization conversion approved | Not confirmed | No approval email or updated membership details provided. |
| Latest account status | Last reported: Individual | Account holder to verify current Membership details. |
| Conversion case number | Not available in this report | Find in Apple's confirmation email or ask support to locate request. |
| Team ID | Awaiting account holder | Copy from Apple Developer Account → Membership details. |
| Support follow-up | Pending confirmation | Email option was available; no evidence of follow-up submission provided. |
| App review | Rejected in supplied screenshot | Guideline 5.1.1(ix); full issue description still needed. |
| Update to Andy | Draft ready below | Report does not confirm any message was sent. |

Next action: Follow up with Apple Developer Support using the account holder's Team ID and existing conversion case number, if available. Ask whether documents or verification are missing. Check the account email and spam folder for replies.

## 2. Readiness checks after conversion

Validate the existing configuration before replacing certificates or profiles. Record the Team ID before and after conversion; investigate any change before rebuilding.

| Check | Status | Verification / completion evidence |
|---|---|---|
| Membership shows Organization and correct legal entity | Pending | Account holder checks Membership details and approval email. |
| Developer team access | Pending | Required team members can sign in and access the team. |
| App Store Connect roles | Pending | Confirm Andy and developers have the roles needed for their tasks. |
| Agreements | Pending | Account holder checks and accepts any required agreements. |
| Bundle ID | Pending | Compare Xcode configuration, registered identifier, and existing App Store Connect app. |
| Signing certificates | Pending | Check validity, team ownership, and private-key availability on build machine. |
| Provisioning profiles | Pending | Check expiry, certificate association, Bundle ID, and enabled capabilities. |
| Push entitlements and APNs | Pending | Check signed build's aps-environment entitlement and APNs/Firebase configuration. |
| Real-device push delivery | Not tested | Verify foreground, background, and notification tap routing on release-capable build. |
| Archive and upload | Not verified | Archive latest build and confirm successful App Store Connect processing. |
| Review resubmission | Pending | Confirm conversion and address the complete rejection message before resubmitting. |

## 3. Client-reported issues and regression testing

Client issue emails have not been supplied for this report. The rows below cover features discussed in this chat; they are not a complete list of client-reported defects.

Build/version: Not recorded  
Android device and OS: Not recorded  
iPhone/iPad device and OS: Not recorded  
Test environment and account: Not recorded

| ID | Feature / expected behavior | Android | iOS | Evidence / next action |
|---|---|---|---|---|
| R01 | Chatbot appears on Home, Schedule, Messages, and Me; hidden on other screens | Not tested | Not tested | Navigate through all four tabs and pushed screens. |
| R02 | Insurance, Documents, and Billing open only their selected content | Not tested | Not tested | Open each entry from Me and verify displayed section. |
| R03 | Cognitive Distortions cards, reframes, filters, and session draft work | Not tested | Not tested | Exercise interactions; navigate back and reopen within the session. |
| R04 | Home notification badge reflects unread items and updates after reading | Not tested | Not tested | Use known unread data; open items, mark read, and return to Home. |
| R05 | Medication floating Add button opens form and saved entries persist | Not tested | Not tested | Add an entry, restart app, and verify saved details. |
| R06 | Medication dose logs, active toggle, and removal work | Not tested | Not tested | Log a dose, toggle status, remove an entry, and verify results. |
| R07 | Medication screen shows skeleton placeholders while loading | Not tested | Not tested | Use a slow network; confirm skeleton transitions to data or error. |
| R08 | Messages screen has no floating Start Chat button | Not tested | Not tested | Open Messages and verify existing conversation navigation. |
| R09 | Login, logout, and account separation remain correct | Not tested | Not tested | Switch between test accounts and verify private data stays separate. |
| R10 | iOS and Android push notifications deliver and open the correct destination | Not tested | Not tested | Test foreground/background delivery and tap behavior on real devices. |

### Historical automated checks

Earlier implementation work in this chat reported four medication tests passing and targeted Flutter analysis passing after the medication skeleton change. Messages screen targeted analysis also passed after removing Start Chat. These checks have not been rerun for this report and do not establish that the current release build passes on Android or iOS.

### Issue evidence format

For every failed test, record:

- Issue ID and client email date/reference.
- Build number, platform, device, and OS version.
- Preconditions and numbered steps to reproduce.
- Expected result and actual result.
- Screenshot/video or relevant sanitized logs.
- Severity, owner, next action, and retest result.

## 4. Outstanding inputs and actions

1. Obtain client issue emails and the full Apple rejection message.
2. Obtain Team ID, conversion case number, and latest Apple response.
3. Confirm whether the support follow-up was submitted.
4. Record latest build numbers and test-device details.
5. Run the Android/iOS matrix above and replace Not tested with evidence-backed Pass or Fail.
6. Share verified results and outstanding blockers with Andy.

## 5. Client update draft

Hi Andy,

The Individual-to-Organization conversion request was submitted to Apple on October 15. Approval has not yet been confirmed, and the last reported membership type was Individual. The next step is to follow up with Apple Developer Support using the Team ID and conversion case reference, and confirm whether any documents or verification are outstanding.

The post-conversion checklist is prepared for team access, App Store Connect roles, Bundle ID, signing certificates, provisioning profiles, and push notifications. Android and iOS device regression results are still pending. We also need the previously reported issue emails to ensure the test list covers every client issue.

The app remains pending readiness verification and resolution of the App Review rejection before resubmission.
