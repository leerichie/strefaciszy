# strefa_ciszy

1. RESET APPLE SIM..
   xcrun simctl shutdown booted
   xcrun simctl erase booted
   open -a Simulator

2. DEPLOY
   firebase deploy
   .... --only hosting (web)

-- fetch indexes / rules
firebase firestore:indexes > firestore.indexes.json
firebase firestore:rules > firestore.rules

firebase firestore:indexes > firestore.indexes.live.json

-push
firebase deploy --only firestore:indexes / rules

index.js changes:
firebase deploy --only functions

GMAIL
(see password manager — credentials removed from repo 2026-09-03, rotate before reuse)

3. RUN
   clean
   doctor
   pub get
   run
   run -d chome

4. IOS build
   bump Version
   flutter build ios --release

5. Xcode
   bump Version
   product - archive
   distribute app store
