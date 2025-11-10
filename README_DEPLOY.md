Deploying the Bookswap app to Firebase

This document explains how to deploy the repository to Firebase (hosting, Firestore rules/indexes, storage rules, and Cloud Functions). Some steps require you to run commands locally and authenticate with Firebase.

Prerequisites

- Install the Firebase CLI:

  ```bash
  npm install -g firebase-tools
  # or
  yarn global add firebase-tools
  ```

- If you plan to deploy from CI (GitHub Actions), generate a CI token or use a service account and store it as a GitHub secret (see the CI section below).
- Have Flutter installed and on your PATH for building web artifacts if you want to deploy web hosting.

Local deploy (interactive)

1. Log into Firebase from your machine:

```bash
firebase login
```

2. Select your project (interactive) or set the default project:

```bash
firebase use --add
# choose the "bookswap-879ad" project (or the project ID you want)
```

3. (Optional) If you haven't already, configure FlutterFire for all platforms you need (recommended):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=bookswap-879ad
```

This generates/updates `lib/firebase_options.dart` and (for Android/iOS) downloads native config files.

4. Build the web app (if deploying hosting):

```bash
npm run build:web
# or
flutter build web --release
```

Hosting is configured to serve `build/web` (see `firebase.json`).

5. Deploy everything (hosting, firestore, storage, functions):

```bash
npm run deploy:firebase
# or to build & deploy in one step:
npm run build-and-deploy
```

This will deploy:

- Hosting (contents of `build/web`)
- Firestore rules and indexes (from `firestore.rules` and `firestore.indexes.json`)
- Storage rules (`storage.rules`)
- Cloud Functions (the `functions/` directory)

Non-interactive CI deploy (GitHub Actions)

1. Create a CI token locally:

```bash
# Create a token that can be used by CI (expires when revoked)
firebase login:ci
```

Copy the generated token and add it to your GitHub repository secrets as `FIREBASE_TOKEN`.

2. Add the provided GitHub Actions workflow (`.github/workflows/firebase-deploy.yml`) to the repo and enable Actions. The workflow expects the `FIREBASE_TOKEN` secret.

Notes and troubleshooting

- If you see errors about `DefaultFirebaseOptions` or `google-services.json`/`GoogleService-Info.plist`, run `flutterfire configure` as described above, or add the native platform files manually.
- Cloud Functions require Node.js 18+ or the version specified in `functions/package.json` (this repo sets node 22). Ensure your local Node.js supports that when deploying functions.
- Large function deployments and first-time hosting deploys may take several minutes.

Security

- Never check service account keys or the output of `firebase login:ci` into source control. Use GitHub secrets or other secure secret stores.

If you want, I can also:

- Add a GitHub Actions workflow template to this repo (I can create it and you can enable it and add the `FIREBASE_TOKEN` secret),
- Or walk you through running `flutterfire configure` interactively and what to expect.
