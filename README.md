# Slide Tutor

Turn a PDF of class slides into a friendly, complete lesson — clear explanations,
key terms, charts, diagrams, a quick quiz, a read-aloud lecture, and a chatbot
tutor you can ask questions. Works in **English and Arabic**.

![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=flat-square&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![Google Gemini](https://img.shields.io/badge/AI-Gemini-1C69FF?style=flat-square&logo=googlegemini&logoColor=white)
![Vercel](https://img.shields.io/badge/Deploy-Vercel-000000?style=flat-square&logo=vercel&logoColor=white)
![Cost](https://img.shields.io/badge/cost-%240%20%C2%B7%20no%20card-success?style=flat-square)

**Live demo:** _add your link here after deploying_ — e.g. `https://your-app.vercel.app`

---

## Contents

- [What it does](#what-it-does)
- [How it works](#how-it-works)
- [Tech stack](#tech-stack)
- [Run it on your computer](#run-it-on-your-computer)
- [Deploy it free on Vercel](#deploy-it-free-on-vercel)
- [Project structure](#project-structure)
- [Security: where the secret lives](#security-where-the-secret-lives)

## What it does

- **Lessons from slides** — upload a PDF and the AI splits it into 4–10 topics,
  teaching each one in simple, beginner-friendly words.
- **Visuals for every topic** — a bar / pie / line chart when a topic has real
  numbers, or a flow / cycle / hierarchy / comparison diagram for ideas.
- **Key terms & equations** — plain-language definitions and formula explanations.
- **Quick quiz** — one multiple-choice question per topic to check understanding.
- **Read-aloud lecture** — a spoken narration for each slide. Works for Arabic
  even on devices that have no Arabic voice installed.
- **Ask about a slide** — ask a question out loud about the slide you're on and
  get a short spoken answer.
- **Chatbot tutor** — chat with a patient tutor that answers from your lesson.
- **English & Arabic** — the whole interface, in both, with right-to-left layout
  for Arabic.
- **Save your lessons** — sign in to keep lessons in the cloud across devices, or
  use it as a guest (lessons are saved on your device).

## How it works

The app is a Flutter web app that runs entirely in the browser. The only secret —
your Google Gemini API key — is kept on a small backend so it never reaches the
browser:

- **On your computer (development):** a tiny Dart program,
  `server/dev_server.dart`, holds the key and talks to Gemini for the app.
- **Deployed (production):** the same job is done by serverless functions in the
  `api/` folder, running on the *same* website under `/api`. The key is a private
  environment variable on the host.

The app chooses the right backend automatically, so you never edit a URL.

## Tech stack

| Part | Technology |
| --- | --- |
| App (frontend) | Flutter (web) |
| AI | Google Gemini (free tier) |
| Sign-in & cloud save | Firebase Authentication + Cloud Firestore |
| Read-aloud voice | Google Translate TTS (no key needed) |
| Hosting | Vercel (static site + serverless functions) |
| Local dev backend | Dart |

Everything used here has a **free tier with no credit card required.**

## Run it on your computer

**You need:** the [Flutter SDK](https://docs.flutter.dev/get-started/install) and a
free Gemini API key from <https://aistudio.google.com/apikey> (no credit card).

1. **Add your key.** Copy the template and paste your key into the copy:

   ```bash
   cp server/.env.example server/.env
   ```

   Open `server/.env` and put your key after `GEMINI_API_KEY=`. This file is
   git-ignored, so the key never leaves your computer.

2. **Start the backend** (it keeps the key and talks to Gemini):

   ```bash
   dart run server/dev_server.dart
   ```

3. **Start the app** in another terminal:

   ```bash
   flutter run -d chrome
   ```

## Deploy it free on Vercel

The compiled app lives in `build/web` and is committed, so the host doesn't need
Flutter installed. Vercel serves `build/web` as the website and runs `api/` as
serverless functions on the same domain — the settings are already in
`vercel.json`.

1. Push this repository to GitHub.
2. On [vercel.com](https://vercel.com), choose **Add New… → Project** and import
   the repository. Keep the detected settings.
3. In **Settings → Environment Variables**, add `GEMINI_API_KEY` = your key, then
   redeploy so it takes effect.
4. In the **Firebase console → Authentication → Settings → Authorized domains**,
   add your `your-app.vercel.app` domain. Without this, sign-in won't work on the
   live site (guest mode still will).
5. Open `https://your-app.vercel.app/api/health` — it should show
   `{"keyLoaded":true}`.

**After you change the app:** `build/web` is a compiled copy, so rebuild it before
pushing or the live site will show the old version:

```bash
flutter build web --release
```

Then commit the updated `build/web` and push.

## Project structure

```
lib/             The Flutter app (UI, screens, services)
  config.dart      Picks the local vs deployed backend automatically
  services/        Talks to the backend (generate, chat, narrate, ask, speak)
api/             Serverless backend used when deployed (one file per endpoint)
_shared/         Shared backend logic for the api/ functions
server/          Local development backend (dev_server.dart) + your .env key
build/web/       The compiled web app that gets served (committed for Vercel)
```

## Security: where the secret lives

- The **Gemini API key** is the only real secret. It lives only in `server/.env`
  (local) or as a Vercel environment variable (deployed) — never in the browser
  and never in this repository.
- The **Firebase settings** in `lib/firebase_options.dart` are meant to be public
  and are safe to commit. Firebase is protected by its server-side security
  rules, not by hiding these values.
- The online version accepts PDFs up to about 3 MB (a hosting limit). For larger
  files, run the app on your computer, where there is no such limit.
