
# Lumen Lite

**Lumen Lite** is the public, fully offline edition of [Lumen](../ReminderApp). Same beautiful SwiftUI experience — reminders, habits, expenses, widgets, and lock-screen Live Activities — with **no account, no cloud sync, and no AI companion or friends features**.

Everything stays on your device forever.

## Demo

<p align="center">
  <img src="https://github.com/user-attachments/assets/095e2dbb-f1be-44b0-b077-da167c064fec" width="200" alt="Home" />
  <img src="https://github.com/user-attachments/assets/0d4e4cc6-cabc-45de-8954-919c1d8357c6" width="200" alt="Reminders" />
  <img src="https://github.com/user-attachments/assets/7b2ed0a7-ad48-4e38-934b-2e9e7802a86d" width="200" alt="Quick add" />
  <img src="https://github.com/user-attachments/assets/14939c39-ae3a-46f8-8d24-163d1d0d6949" width="200" alt="Habits" />
</p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/12da8d60-31eb-4131-abed-8b6139cc900a" width="200" alt="Money" />
  <img src="https://github.com/user-attachments/assets/511859b0-f732-4980-af8f-7b66b02ab741" width="200" alt="Expense tracker" />
  <img src="https://github.com/user-attachments/assets/810f4ef9-e0c2-4139-a838-0ac4e8a7ae22" width="200" alt="Profile" />
  <img src="https://github.com/user-attachments/assets/5e91abe3-b095-4229-8bad-5eae98fc66fb" width="200" alt="Themes" />
</p>

## What's included

| Feature | Lumen (private) | Lumen Lite (this repo) |
|---------|-----------------|------------------------|
| Reminders, notes, tasks | ✅ | ✅ |
| Habits & streaks | ✅ (cloud) | ✅ (local SwiftData) |
| Expense tracker | ✅ (optional cloud sync) | ✅ (local only) |
| Widgets & Live Activities | ✅ | ✅ |
| Daily motivation | ✅ | ✅ |
| Themes | ✅ | ✅ |
| AI Companion | ✅ | ❌ |
| Friends & sharing | ✅ | ❌ |
| Supabase / sign-in | ✅ | ❌ |

## Requirements

- macOS with Xcode 15.4+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- iOS 17+ device or simulator

## Setup

```bash
cd ReminderApp-Public
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# Edit Secrets.xcconfig — set APP_BUNDLE_PREFIX and APPLE_TEAM_ID
xcodegen generate
open LumenLite.xcodeproj
```

On first launch, Lumen Lite asks for your name (stored in UserDefaults) and generates a local UUID used as `ownerID` for all SwiftData records. No onboarding, no sign-in.

## Project structure

```
ReminderApp-Public/
├── App/                 # Entry point, RootView, theme
├── Packages/
│   ├── Core/            # SwiftData, LocalIdentityService, motivation
│   ├── DesignSystem/    # Aurora, FloatingTabBar, Lumi mascot
│   ├── Reminders/       # Home tab
│   ├── Wellness/        # Habits tab
│   ├── Finance/         # Money tab
│   └── Customization/   # Sound packs
├── Widgets/             # WidgetKit + ActivityKit extensions
└── Intents/             # Siri shortcuts
```

## Tabs

1. **Home** — reminders, notes, tasks, calendar import, lock-screen pin
2. **Habits** — daily check-ins and streaks
3. **Money** — offline expense tracker with savings accounts
4. **Profile** — name, themes, motivation notifications, erase everything

The **+** button appears on Home and Money only.

## Privacy

- No network calls to Supabase or any backend
- No analytics SDKs
- **Erase everything** in Profile wipes all local SwiftData and your display name

## Relationship to the main app

This folder is a sibling copy of `ReminderApp/`, maintained separately so you can open-source or App Store–ship the offline edition without exposing private backend keys or social/AI code paths.
