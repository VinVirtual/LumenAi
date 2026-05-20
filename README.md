# Lumen Lite

**Lumen Lite** is the public, fully offline edition of [Lumen](../ReminderApp). Same beautiful SwiftUI experience — reminders, habits, expenses, widgets, and lock-screen Live Activities — with **no account, no cloud sync, and no AI companion or friends features**.

Everything stays on your device forever.

## Demo

<p align="center">
  <img src="https://github.com/user-attachments/assets/909a7b7b-13fb-4572-b059-6b56f48423fd" width="200" alt="Home" />
  <img src="https://github.com/user-attachments/assets/44be73e0-ad47-4343-a614-325da556fd79" width="200" alt="Reminders" />
  <img src="https://github.com/user-attachments/assets/efb207ff-aaa8-4282-baf2-e4ce9782be44" width="200" alt="Quick add" />
  <img src="https://github.com/user-attachments/assets/fa022e9f-947a-4048-8da4-f42435ca3c80" width="200" alt="Habits" />
</p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/4a466ef2-b863-426a-adbf-d569bc8209b7" width="200" alt="Money" />
  <img src="https://github.com/user-attachments/assets/93ecbdc9-2bc2-4227-beba-a0d7e471a86c" width="200" alt="Expense tracker" />
  <img src="https://github.com/user-attachments/assets/c2d02396-7e55-4645-a06b-8d3953619532" width="200" alt="Profile" />
  <img src="https://github.com/user-attachments/assets/b5ae3c2e-c753-4667-9471-7ee82f198fd5" width="200" alt="Themes" />
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
