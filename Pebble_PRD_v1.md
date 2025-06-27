rrrr
# Pebble Product Requirements Document (PRD)

## Version 1 (MVP)

### Overview
Pebble is a neurodiverse-friendly routine and task app designed for reassurance, calm, and accessibility. All data is stored locally on the device using Hive. No cloud sync in MVP.

### Core Features
- **Routine Management**
  - Create, edit, delete routines
  - Pin/unpin routines
  - Categorise routines
- **Task Management**
  - Add, edit, delete tasks within routines
  - Tasks can require optional photo confirmation
  - Tasks can include notes and categories
- **Routine Player**
  - Full-screen player with progress tracking
  - Mark tasks as complete (with optional photo)
- **Theming & Accessibility**
  - Light and dark mode (ThemeMode.system)
  - Material 3 design, soft colours, minimal distractions
  - Large touch targets, clear fonts, UK English spelling
- **Local Data Storage**
  - Uses Hive for all data (routines, tasks)
  - No cloud sync, no user accounts
- **Media Handling**
  - Use `image_picker` for photo capture
  - Use `path_provider` for local image storage
- **Testing**
  - Unit and widget tests for all models and major widgets
- **User Reassurance**
  - Clear messaging that data is private and local-only
  - Option to export/import data for backup

---

## Version 2 (Future/Upgrade Path)

### Cloud & Premium Features (Not in MVP)
- **Cloud Sync (Optional Future)**
  - Firebase or similar for cross-device sync
  - User authentication (email, Google, Apple, etc.)
  - Data privacy and GDPR compliance
  - Cost monitoring and budget alerts

- **Photo Retention & Premium Model**
  - Free users: Photos are retained for 48 hours, then auto-deleted
  - Premium users: Extended photo history (30 days, 90 days, or unlimited)
  - Scheduled cleanup of old photos (Cloud Functions or local job)
  - Clear UI messaging about retention policy
  - In-app purchase or subscription for premium tier
  - Option for users to export/download their photos

- **Other Premium Features (Ideas)**
  - Custom themes
  - Advanced analytics or insights
  - Priority support

---

## Notes
- Accessibility and reassurance for neurodiverse users is a key priority
- Minimise visual clutter, favour calm design
- All features must align with user privacy and data control principles

---

*This document is versioned. Reference the V2 section for future upgrades and premium features.* 