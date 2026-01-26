# Elyrii Mobile Features

Detailed description of all mobile application features.

## Auth (Authentication)

**Location:** `lib/features/auth/`

### Features

**Login:**
- Email/password login
- Client-side validation
- Error handling

**Register:**
- Email registration
- Field validation
- Email verification
- Profile creation

**Session:**
- JWT token stored in SharedPreferences
- Automatic refresh
- Logout
- Session expiration

### Screens

- Login Page
- Register Page

---

## Chatbot (AI Assistant)

**Location:** `lib/features/chatbot/`

### Features

**Conversation:**
- Real-time chat with AI
- Message history
- Auto-scroll
- Typing indicator

**AI Integration:**
- Connection to Mistral-7B backend
- Sentiment detection
- Contextual responses
- Safe-guard filters

**Interface:**
- Message bubbles
- Timestamp
- Mascot avatar
- Input with suggestions

### Screens

- Chat Page
- Conversation History

---

## Coach (Personal Coach)

**Location:** `lib/features/coach/`

### Features

**Guidance:**
- Personalized advice
- Progress tracking
- Recommended goals
- Motivating feedback

**Interface:**
- Coaching overview
- Daily tips
- Session history

### Screens

- Coach Dashboard
- Session Details

---

## Dashboard (Dashboard)

**Location:** `lib/features/dashboard/`

### Features

**Overview:**
- Activity summary
- Daily goals
- Statistics
- Quick access to features

**Widgets:**
- Progress card
- Current quests
- Mood of the day
- Streak (consecutive days)

**Navigation:**
- Bottom navigation bar
- Accès à toutes les features
- Notifications badge

### Screens

- Home Dashboard
- Profile Overview

---

## Gamification (Game System)

**Location:** `lib/features/gamification/`

### Features

**Quests:**
- Daily objectives
- Weekly challenges
- Quests spéciales
- Real-time progression

**Rewards:**
- Experience points (XP)
- Badges and achievements
- User levels
- Collectible items

**Leaderboard:**
- User ranking
- Comparison with friends
- Popular achievements

**Progression:**
- Progress bar
- Achievement history
- Statistics détaillées

### Screens

- Quest List
- Quest Details
- Rewards Page
- Leaderboard
- Achievements Gallery

---

## Journal (Personal Journal)

**Location:** `lib/features/journal/`

### Features

**Entries:**
- Free writing
- Mood tracking
- Tags and categories

**Organization:**
- Calendar view
- Date filters
- Entry search
- Archives

**Analysis:**
- Mood trends
- Statistics d'utilisation
- Personalized insights

### Screens

- Journal Home
- Create Entry
- Entry Details
- Calendar View
- Mood Tracker

---

## Mascot (Interactive Mascot)

**Location:** `lib/features/mascot/`

### Features

**Interaction:**
- State-based animation
- Action reactions
- Contextual messages
- Emotional states

**States:**
- Idle (rest)
- Happy
- Thinking
- Sleeping
- Excited

**Animations:**
- Lottie animations
- Smooth transitions
- Micro-interactions

### Usage

Present in:
- Chat (avatar)
- Dashboard (companion)
- Achievements (célébration)

---

## Meditation (Guided Meditation)

**Location:** `lib/features/meditation/`

### Features

**Sessions:**
- Guided meditations
- Breathing exercises
- Customizable timer
- Soothing sounds

**Tracking:**
- Session history
- Total meditation time
- Streaks
- Progression

### Screens

- Meditation List
- Session Player
- Stats Overview

---

## Notifications

**Location:** `lib/features/notifications/`

### Features

**Types:**
- Goal reminders
- New chatbot messages
- Unlocked achievements
- Meditation reminders

**Management:**
- Notification center
- Mark as read
- Clear all
- Notification preferences

**Push notifications:**
- Local notifications

---

## Settings (Settings)

**Location:** `lib/features/settings/`

### Features

**Account:**
- Personal information
- Profile modification
- Password change
- Account deletion

**Preferences:**
- Theme (light/dark/auto)
- Language
- Notifications
- Sounds and vibrations

**Privacy:**
- Personal data
- Chat history
- Data export
- RGPD compliance

**Application:**
- App version
- About
- Terms of use
- Privacy policy

### Screens

- Settings Home
- Account Settings
- Preferences
- Privacy Settings
- About

---

## Navigation between features

### Routes

Defined in `lib/routes/app_routes.dart`:

```dart
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/';
  static const String chat = '/chat';
  static const String journal = '/journal';
  static const String quests = '/quests';
  static const String settings = '/settings';
  // etc.
}
```
