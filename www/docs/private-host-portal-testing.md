# Private host portal testing

The OpenAI Site remains **owner-private** during this phase. Do not change its
audience or access mode while following this checklist. Firebase owner accounts
control the portal after the Site access gate; they do not make the Site public.

## Prepared production configuration

- Firebase project: `eurotrex`
- Firebase Web app: `1:893185124081:web:87409fbc7f8e15966a6b50`
- Email/password Authentication: enabled
- Authorized Site domain: `eurotrex.andreasmic332452.chatgpt.site`
- Firestore rules: public read-only trail content; authenticated owner writes;
  administrator review/publishing; default deny

## Test privately as an accommodation owner

1. Open `https://eurotrex.andreasmic332452.chatgpt.site/portal` while signed in
   to the Site owner account.
2. Choose **Create owner account** and use a test email you control.
3. Add an accommodation, choose a real trail stage, accept the policy, and
   submit it.
4. Confirm the dashboard shows **Under review**. Sign out and back in to verify
   the listing remains attached to the same owner.

## Bootstrap your administrator account

This is deliberately a trusted manual step; owners cannot promote themselves.

1. In Firebase Console, open **Authentication → Users** and copy the UID of the
   account that should review listings.
2. In **Firestore Database**, create the document `admins/{UID}`. A minimal
   document may contain `email`, `role: "administrator"`, and `createdAt`.
3. Sign out of the portal and sign back in so Firebase refreshes the account
   session.
4. Open `/admin`, approve the test submission, and confirm it appears in the
   published inventory and in the mobile app's accommodation data.
5. Test **Request changes**, owner resubmission, and **Remove from app** before
   inviting any real host.

## Automated production smoke test

Maintainers can run the isolated smoke test below while signed in with the
Firebase CLI. It creates two temporary Auth users and uniquely named Firestore
records, verifies the complete owner-to-approval flow, and cleans them up.

```sh
node scripts/portal-production-smoke.mjs
```

The script intentionally targets the real `eurotrex` project. It never changes
Site visibility and it does not use or print a real owner's password.

## Before making the Site public later

- Replace the placeholder partner terms/privacy content with approved copy.
- Decide who receives owner-support and review notifications.
- Create named administrator accounts and remove all test accounts/documents.
- Test registration, password reset, submission, approval, update, rejection,
  removal, and the mobile-app result on iOS and Android.
- Add the final App Store and Google Play URLs.
- Confirm analytics, consent, accessibility, SEO metadata, and support contact.
- Back up Firestore and document the incident/rollback procedure.
- Only then change the Site audience from owner-private to the intended public
  audience. That access change is not part of the current work.
