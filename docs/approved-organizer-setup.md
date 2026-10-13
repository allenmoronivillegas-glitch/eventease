# EventEase approved-organizer setup

EventEase can provision organizer access automatically for emails approved by the project administrator. Do not loosen Firestore rules or let app users edit their own role.

## Approve an organizer email

1. Open Firebase Console for project `eventease-4ad4c`.
2. Open **Firestore Database → Data**.
3. Create a collection named `approved_organizers` if it does not exist.
4. Add a document whose document ID is the exact email shown in Firebase Authentication for the user (use the same lowercase email address), for example `janedoe@gmail.com`.
5. Add a Boolean field: `approved` = `true`.
6. Do not grant client apps read or write access to this collection. The repository rules explicitly deny client access; a trusted project administrator manages approvals in Firebase Console/Admin SDK.

The approved user must own and verify that email address. For email/password accounts, EventEase sends a verification email when the person finishes onboarding as an organizer. They must verify it and tap Finish again. Verified Google accounts can proceed directly.

## How role provisioning works

- New accounts choosing Organizer can create an organizer profile only when the verified email has an approval document.
- Existing completed attendee profiles are automatically promoted at sign-in only if the authenticated, verified email is approved.
- Existing organizer profiles continue to work without changing their current role.
- Unapproved users remain attendees and cannot approve themselves.
- To remove organizer access from an already-provisioned user, a project administrator must change that user's `users/{uid}.role` to `attendee` in Firebase Console as well as disabling/removing the approval entry. Removing an approval entry alone does not demote a profile that already has organizer role.

## Deploy and test

After reviewing the updated `firestore.rules`, deploy rules from the project root:

```powershell
firebase deploy --only firestore:rules --project eventease-4ad4c
```

Then rebuild/redeploy the clients so they include the latest onboarding and sign-in code:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build web
```

Deploy the web build separately with your configured Firebase Hosting target. Installing a new APK is required for the Android code changes; changes to the web code require a new web build and Hosting deployment.

## Important

This feature intentionally does not contain a public “make me organizer” button that grants privileges by itself. Approval documents must only be created by trusted project administrators. The email must be verified before the role can be granted.
