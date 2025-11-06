# Elyrii  —  Your personal AI assistant

*End‑of‑Study Master Project – EPITECH Paris*

## Table of Contents
- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Architecture Diagram](#architecture-diagram)
- [Tech Stack](#tech-stack)
  - [Mobile](/docs/mobile/index.md)
  - [Backend](/docs/backend/index.md)
  - [AI](/docs/ai/index.md)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#backend-setup)
  - [Mobile App Setup](#mobile-app-setup)
- [Running the Application](#running-the-application)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Project Overview

Elyrii is a cross‑platform mobile application built with Flutter that offers an AI‑powered personal assistant aimed at helping young people who feel socially isolated. The app combines a conversational chatbot with a gamified system of daily objectives and quests to keep users engaged and motivated.

The backend is implemented as a set of lightweight Hono micro‑services (TypeScript) handling authentication, user data, quest logic, and communication with a custom Mistral‑7B‑based language model.

> *This repository represents the final master‑level project for the EPITECH Paris PGE program, developed by a multidisciplinary student team.*

## Key Features

| Category | Feature |
|---|---|
| Chatbot | • Real‑time conversational AI powered by a fine‑tuned Mistral‑7B model.• Context‑aware replies, sentiment detection, and safe‑guard filters. |
| Gamification | • Daily objectives (e.g., “Talk about your mood”, “Share a hobby”).• Quest system with progressive milestones and reward badges.• Leaderboard (optional) for friendly competition. |
| User Management | • Secure email/password login via JWT.• Optional social login (Google/Apple). |
| Data Persistence | • PostgreSQL for user profiles, quest progress, and chat logs.• Prisma ORM for type‑safe DB interactions. |
| Micro‑service Architecture | • Separate services for Auth, Chat, Quest, and Notification.• Each service runs independently behind an API gateway (Hono). |
| Cross‑Platform UI | • Flutter UI with Material Design on Android & iOS.• Adaptive layout for tablets and phones.• Voice input (speech‑to‑text) integration. |
| Privacy‑First | • End‑to‑end encryption for chat transcripts.• GDPR‑compliant data handling. |

## Architecture Diagram

```
+-------------------+           +-------------------+
|   Flutter Mobile  | <--API--> |   API Gateway     |
|   (Dart/Flutter)  |           |   (Hono)          |
+-------------------+           +-------------------+
          |                               |
  +-------+--------+-----------+----------+--------+
  |                |           |                   |
+------+        +------+    +------+            +------+
| Auth |        | Chat |    | Quest|            | Notif|
| Srv  |        | Srv  |    | Srv  |            | Srv  |
+------+        +------+    +------+            +------+
    |               |           |                  |
 +------------+   +-------+   +------------+   +----------+
 | PostgreSQL |   | Redis |   | PostgreSQL |   | Firebase |
 +------------+   +-------+   +------------+   +----------+
```

Each service is a separate Hono micro‑service containerized with Docker.

## Tech Stack

| Layer | Technology                                         | Reason |
|---|----------------------------------------------------|---|
| Frontend | Flutter 2.10+, Dart                                | Single codebase for iOS & Android, expressive UI |
| Backend | TypeScript 5, Hono (tiny HTTP framework)           | Minimal overhead, fast cold starts, easy routing |
| Auth | JWT, bcrypt, optional OAuth2 (Google/Apple)        | Industry‑standard token‑based security |
| Database | PostgreSQL 15 + Drizzle ORM                        | Strong relational schema, type safety |
| Cache / PubSub | Redis                                              | Session store, rate‑limiting, real‑time notifications |
| AI Model | Custom fine‑tuned Mistral‑7B (via 🤗 Transformers) | Open‑source, high‑quality LLM with controllable size |
| Containerisation | Docker & Docker‑Compose                            | Consistent dev/prod environments |
| CI/CD | GitHub Actions (build, test, lint)                 | Automated quality gates |
| Testing | Jest (backend), Flutter test (frontend)            | Unit & integration coverage |
| Version Control | Git (GitHub)                                       | Collaboration & history tracking |


## Getting Started

### Prerequisites

- **TypeScript 5**
- **Docker & docker‑compose** (for local services)
- **Flutter SDK ≥ 3.13** (stable channel)
- **Python 3.10+** (only if you want to run the model locally)
- **Git**

### Backend Setup

- Clone the repo

```bash
git clone https://github.com/elyrii-epitech/Elyrii.git
cd Elyrii/elyrii_server
```

- Start services with Docker Compose

```bash
docker compose up --build
```

### Mobile App Setup

- Navigate to the Flutter project

```bash
cd ../elyrii_app
```

- Install dependencies

```bash
flutter pub get
```

- Run the app

```bash
flutter run
```

Choose an emulator/device (iOS simulator, Android Studio, or physical device).

## Running the Application

TODO

## Development Workflow

- **Branching** – follow GitFlow (feature/\*, bugfix/\*, release/\*).
- **Linting** – npm run lint (backend) / flutter analyze (mobile) / black (Python Pep8).
- **Testing** – npm test (Jest) and flutter test. Aim for >80 % coverage.
- **Commit messages** – conventional commits (feat:, fix:, docs:).
- **Pull Requests** – require at least three reviewer and successful CI checks.

## Testing

- Backend:

```bash
npm run test   # runs Jest unit & integration tests
```

- Mobile:

```bash
flutter test   # widget & unit tests
```

## Contributing

We welcome contributions from fellow students, researchers, and open‑source enthusiasts.

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/name/awesome‑thing`).
3. Commit your changes with clear messages.
4. Push to your fork and open a Pull Request.

Please adhere to the project's coding style and include relevant tests.

## License

This project is released under the ? License – see the LICENSE file for details.

## Acknowledgements

- **EPITECH Paris** – for providing the academic framework and mentorship.
- **Mistral AI** – for the open‑source Mistral‑7B model.
- All open‑source libraries listed in `package.json` and `pubspec.yaml`.

Happy coding! If you encounter any issues, feel free to open an issue on GitHub or contact the project maintainers.
