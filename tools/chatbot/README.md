# Chatbot development proxy

The Flutter chat is scoped to Home, Schedule, Messages, and Me. Screens pushed
above the main shell cover it. The conversation stays in memory until logout
or the main shell is removed.

This local proxy uses Groq's OpenAI-compatible API. Its provider key is in the
ignored `tools/chatbot/.env` file, never in Flutter source or build flags.

Start the proxy with Node 20 or newer:

```sh
node tools/chatbot/server.mjs
```

For an iOS simulator or a desktop build:

```sh
flutter run --dart-define=CHATBOT_BASE_URL=http://127.0.0.1:8787
```

For Android, forward the device port first (emulator or USB device):

```sh
adb reverse tcp:8787 tcp:8787
flutter run --dart-define=CHATBOT_BASE_URL=http://127.0.0.1:8787
```

Without `CHATBOT_BASE_URL`, the app calls its existing authenticated backend at
`/api/patient/chatbot`. For production, implement that route on the patient
backend with session authorization, rate limits and the Groq key held on the
server. This loopback-only development proxy is not a production deployment.
The local proxy does not implement browser CORS; use a native Flutter target.

Change `GROQ_MODEL` in the proxy environment if needed. The default is
`openai/gpt-oss-20b`.
