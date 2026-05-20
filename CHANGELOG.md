# Changelog

## 0.1.0 — Initial scaffold (May 2026)

### Phase 0 · Bootstrap

- XcodeGen `project.yml` with main app + 4 extensions (Widgets, NSE, Intents,
  Tests) and shared App Group entitlement.
- Local Swift packages: `DesignSystem`, `Core`, `Reminders`, `AICompanion`,
  `Social`, `Wellness`, `Customization`.
- `.xcconfig` files for Debug/Release with secrets pulled from
  `Config/Secrets.xcconfig` (gitignored).
- SwiftLint + SwiftFormat configs, GitHub Actions CI (build, test, lint,
  Supabase migration check).
- Supabase initial migration (`supabase/migrations/0001_init.sql`) with RLS,
  pgvector for AI memory, PostGIS for geofencing, friendships, boards,
  activity feed, AI conversations, wellness, AI pet, device tokens, and
  feature flags. Edge Functions: `ai-chat`, `ai-suggest`, `transcribe`,
  `embed-memory`, `notify-fanout`.

### Phase 1 · Design system + shell + auth

- `Tokens`, `Theme` (Aurora/Dawn/Nebula bundled), `Aurora` animated
  background, `GlassCard`, `PrimaryButton`, `GlassFieldStyle`,
  `HapticEngine`, `FloatingTabBar`.
- `LumenApp`, `LumenAppDelegate`, `RootView` with floating tab bar and
  custom long-press companion sheet.
- `OnboardingFlow` (Apple Sign-In + email magic link) and
  `UsernameClaimView`.
- `AuthService` wraps Supabase Auth; profile auto-created via Postgres
  trigger.

### Phase 2 · Reminders

- `ReminderEntity` (SwiftData) with Codable mirror for Supabase round-trips.
- `NLParser` (NSDataDetector + heuristics), `RecurrenceEngine`,
  `PriorityEngine`, `Geofencing`.
- `RemindersService` (create / mark done / snooze / schedule local pushes).
- `RemindersHomeView` with bucketed timeline, `ReminderCard`,
  `QuickAddSheet`, swipe + context actions.
- `SyncEngine` performs initial pull, realtime subscription, push of
  pending mutations.

### Phase 3 · AI Companion

- `Persona` (Aria/Nova/Echo/Sage), `AIChatService` streams from `ai-chat`
  Edge Function over SSE and persists messages.
- `VoiceService` records audio, ships to Whisper proxy, returns transcript.
- `AICompanionHomeView` with persona switcher, streaming bubbles, voice +
  text composer.
- `BriefingService` for morning briefings cached in App Group defaults.

### Phase 4 · Lock Screen

- `NextReminderWidget` (Lock + Home + Inline + Circular + Rectangular)
  with interactive `MarkReminderDoneIntent` button.
- `CompanionWidget`, `StreakWidget`, `ActivityFeedWidget`.
- `ReminderActivityAttributes` (shared in Reminders package) and
  `ReminderLiveActivityWidget` with full Dynamic Island layouts.
- `LiveActivityController` for starting/updating/ending activities.

### Phase 5 · Social

- `SocialService` (search, friend requests, accept/block, share reminder,
  react, refresh feed, create boards).
- `SocialHomeView` (Feed / Friends / Boards), `SharedReminderSheet`.
- `MomentShareCard` for image-sharable celebrations.
- `AccountabilityService` for "nudge a friend if I miss this" flows.

### Phase 6 · Wellness

- `WellnessService` (mood log, habit toggle), `PomodoroController`,
  `WellnessHomeView` with mood/focus/habit cards.

### Phase 7 · Customization

- `ThemeEngine` JSON encode/decode + `lumen://theme/...` deep link.
- `LumenAvatarView` animated layered avatar with aura.
- `SoundPackStore`, custom font registration helpers.

### Phase 8 · Viral hooks

- `AIPetService` with XP/level logic and `AIPetStage` evolution stages.
- `MomentShareCard` (Phase 5 file) used for streak/board completion shares.
- Accountability buddy flow.

### Phase 9 · Polish

- Notification Service Extension that adds avatars and elevates priority.
- App Intents extension (`CreateReminderIntent`) + Siri shortcuts.
- `PrivacyService` (export, forget-me, delete-account) and `PrivacyView`.
- Accessibility helpers (Reduce Transparency / decorative / card a11y).
