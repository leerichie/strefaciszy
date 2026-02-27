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

-push
firebase deploy --only firestore:indexes / rules


3. RUN
clean
doctor
pub get
run
run -d chome

4. IOS build
bumb Version
flutter build ios --release

5. Xcode
bump Version
product - archive
distribute app store