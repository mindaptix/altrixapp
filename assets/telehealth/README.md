Amazon Chime SDK JS 3.32.0 is bundled locally with tools/chime (pnpm install, pnpm build).
The Flutter waiting room uses an isolated WebView HTTPS context and real getUserMedia
preview; the theater consumes meeting/attendee credentials from the public join API.
No AWS credentials belong in the mobile app. SDK license: CHIME_LICENSE.

Device acceptance: On physical Android and iOS, grant camera/microphone permission;
open a telehealth_call push in foreground/background/terminated states, check in,
join a doctor meeting, verify bidirectional audio/video, mute, video off/on, camera
switch, reconnect, doctor camera off/on, end confirmation and rejoin. Confirm camera
and mic indicators turn off after leaving. Test permission denial and expired links.
WebView WebRTC compatibility, interruptions and Bluetooth audio require device QA;
this is a bundled JS SDK integration rather than native Chime platform SDK bindings.
Notification pushes open on tap; this does not implement CallKit/full-screen ringing.
