# NimbusApp

An iOS habit-tracking app with a gamified cloud companion named **Nimbos** that evolves as users complete daily habits. Users "light stars" (complete tasks) to power Nimbos through 4 evolution stages over 30 days.

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **State Management:** `@Observable` macro (iOS 17+)
- **Data Persistence:** SwiftData
- **Architecture:** MVVM
- **Dependencies:** None (pure Swift ecosystem)

## Project Structure

```
NimbusApp/
├── NimbusAppApp.swift          # App entry point
├── View/                       # SwiftUI views
│   ├── OnboardingFlowView.swift    # Multi-step onboarding coordinator
│   ├── IdentityView.swift          # User name input
│   ├── ConstellationView.swift     # Habit selection screen
│   ├── ViewCheckView.swift         # Vibe mode selection (Bestie/Boss)
│   ├── MainDashboardView.swift     # Primary dashboard with task list
│   ├── TaskRow.swift               # Individual task row component
│   ├── VibeBubble.swift            # Reusable habit selection bubble
│   └── NimbusView.swift            # Day 30 celebration view
├── ViewModel/
│   ├── HabitViewModel.swift        # Core habit logic & Nimbos evolution
│   └── NimbusViewModel.swift       # Nimbos-specific logic (placeholder)
├── HabitTask.swift                 # HabitTask model
└── Assets.xcassets/                # Images, icons, Nimbos stage assets
```

## Key Concepts

- **Stars:** Each completed habit task lights a star (50 total)
- **Nimbos Stages:** Cloud companion evolves through 4 stages based on stars lit
- **Vibe Modes:** "Bestie" (supportive) vs "Boss" (disciplinary) personality
- **Day 30:** Special celebration milestone view

## Build & Run

Open `NimbusApp.xcodeproj` in Xcode and press `Cmd+R` to run on simulator or device.

```bash
# Build from command line
xcodebuild -scheme NimbusApp -configuration Debug

# Release build
xcodebuild -scheme NimbusApp -configuration Release
```

## Design Conventions

- Glassmorphism UI with blur effects and dynamic gradients
- Haptic feedback for task completion interactions
- Smooth SwiftUI animations and transitions throughout
- All new views should follow the existing glassmorphic style
