# Slide Tutor

A web app that turns a PDF of class slides into a friendly, complete lesson:
clear explanations, key terms, simple charts and diagrams, a quick quiz, a
read-aloud lecture, and a chatbot tutor you can ask questions. It works in
English and Arabic. Sign in to save your lessons to the cloud, or use it as a
guest (lessons are saved on your device).

The AI work is done by Google's free Gemini models. Your API key stays on the
server and is never sent to the browser or committed to this repository.

## How it is put together

- **`lib/`** – the Flutter web app (what runs in the browser).
- **`api/`** – the backend, as small serverless functions, used when the app is
  deployed. Each file is one endpoint: `generate`, `chat`, `narrate`, `ask`,
  `tts`, `health`. They read the Gemini key from an environment variable.
- **`server/dev_server.dart`** – the same backend, but for running on your own
  PC while developing. It reads the key from `server/.env`.
- **`_shared/gemini.js`** – the shared backend logic the `api/` functions use.

The app automatically calls the local helper (`:8787`) when opened from
`localhost` or a phone on your Wi-Fi, and the same-site `/api` backend when
deployed. You do not edit anything to switch between them.

## Run it on your computer

1. Get a free Gemini API key (no credit card) at
   https://aistudio.google.com/apikey
2. Copy `server/.env.example` to `server/.env` and paste your key after the
   `=`. This file is git-ignored, so the key never reaches GitHub.
3. In one terminal, start the backend helper:
   ```
   dart run server/dev_server.dart
   ```
4. In another terminal, start the web app:
   ```
   flutter run -d chrome
   ```

## Deploy it (free, on Vercel)

The compiled web app lives in `build/web` and is committed, so the host does not
need Flutter installed. Vercel serves `build/web` as the website and runs the
`api/` folder as serverless functions on the same domain.

1. Push this repository to GitHub.
2. On https://vercel.com, **Add New… → Project** and import the repository.
   Leave the build settings as detected (`vercel.json` already configures them).
3. In the project's **Settings → Environment Variables**, add:
   - Name: `GEMINI_API_KEY`
   - Value: your Gemini key
   Then redeploy so the new variable takes effect.
4. In the **Firebase console → Authentication → Settings → Authorized
   domains**, add your `your-app.vercel.app` domain. Without this, sign-in will
   not work on the live site (guest mode still works).
5. Open `https://your-app.vercel.app/api/health` – it should show
   `{"keyLoaded":true}` once the key is set.

### After you change the app

`build/web` is a compiled copy, so if you edit the Dart code you must rebuild it
before pushing, or the live site will show the old version:

```
flutter build web --release
```

Then commit the updated `build/web` and push.

## Notes

- The online version accepts PDFs up to about 3 MB (a host limit). For larger
  files, run the app on your computer, where there is no such limit.
- Sign-in and cloud save use Firebase. The Firebase web settings in
  `lib/firebase_options.dart` are public by design and safe to commit; the only
  real secret is the Gemini key.
