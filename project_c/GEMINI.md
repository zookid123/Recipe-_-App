# GEMINI.md

## Project Overview
This is a Flutter-based recipe application called `flutter_application_1` (display name usually "레시피" or similar). It features a robust backend integration using **Firebase** (Firestore, Auth, Storage) and **Kakao SDK** for authentication. The app allows users to browse recipes, sync data from a public API, and will eventually include community features and a personalized "My Page".

### Main Technologies
- **Frontend:** Flutter (Dart)
- **Backend:** Firebase Firestore (Database), Firebase Auth (Authentication), Firebase Storage (Images)
- **Authentication Providers:** Google Sign-In, Kakao Login
- **Data Source:** Public API (Ministry of Agriculture, Food and Rural Affairs - 농림축산식품부)
- **Local Storage:** Shared Preferences (for session management)

## Architecture

### Navigation & Shell
- `main.dart` contains the `MainShell`, which uses an `IndexedStack` to manage four main tabs:
  - **Home (HomeScreen):** Curated content and highlights.
  - **Recipes (RecipeListScreen):** Searchable and filterable grid of recipes.
  - **Community (CommunityScreen):** Placeholder for user interaction.
  - **My Page (MyPageScreen):** User profile and authentication status.

### State Management
- **AuthService:** A `ChangeNotifier` singleton (`lib/services/auth_service.dart`) that manages the authentication state across Google and Kakao. It handles session restoration (`init()`), login, and logout.
- **UI State:** Primarily managed using `StatefulWidget` combined with `StreamBuilder` or `FutureBuilder` for real-time Firestore synchronization.

### Data Synchronization
- **External Sync Script:** Data is synchronized using a dedicated Node.js script (`test_app/sync_recipes.js`).
  - Fetches and merges data from three public API endpoints.
  - Handles pagination (1,000 items per fetch) for completeness.
  - Implements an "Image-Safe" policy: preserves existing `imgUrl` and statistical data (view counts) in Firestore.
  - Skips incomplete recipes (e.g., 0kcal).
  - Executed via: `node sync_recipes.js` from the `test_app/` directory.

## Roadmap & Missing Features

Based on the current architecture and common recipe app requirements (PRD standards), the following features are pending implementation:

1.  **Personalization (P0):**
    *   **Bookmarks/Favorites:** Allow logged-in users to save recipes.
    *   **Recent Activity:** Tracking recently viewed recipes for easy access.
2.  **Community & Social (P1):**
    *   **Interactive Community Screen:** Transitioning from "준비 중" to a functional user post board.
    *   **Recipe Reviews/Comments:** Enabling user feedback and photo reviews on individual recipes.
3.  **Advanced Search (P1):**
    *   **Fridge Management:** Selecting available ingredients to find matching recipes with a "matching percentage".
4.  **UX Enhancement (P2):**
    *   **Cooking Mode:** A simplified, high-contrast, large-font UI for use while cooking.
    *   **Shopping List:** Adding ingredients from a recipe to a persistent shopping list.

## Firestore Schema

### `recipes` Collection
- **ID:** `RECIPE_ID` (from API)
- **Fields:** `name`, `summary`, `imgUrl`, `calorie`, `qnt`, `time`, `timeMinutes`, `level`, `nation`, `type`, `ingredients` (Array), `steps` (Array), `viewCount`, `todayViewCount`, `yesterdayViewCount`, `todayDate`, `timestamp`.

### `users` Collection
- **ID:** `uid` (Google) or `kakao_{id}` (Kakao)
- **Fields:** `nickname`, `email`, `profileImageUrl`, `provider`, `lastLoginAt`.

## Building and Running

### Prerequisites
- Flutter SDK (^3.9.2)
- Firebase project configuration (already initialized in `main.dart`)
- Kakao Native App Key (already initialized in `main.dart`)

### Key Commands
- **Install Dependencies:** `flutter pub get`
- **Run App:** `flutter run`
- **Run on Web (with Security Disabled):** `flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080 --web-browser-flag "--disable-web-security"` (configured in `.vscode/launch.json`)
- **Analyze Code:** `flutter analyze`
- **Test:** `flutter test`

## Development Conventions

### Coding Style
- Follows standard Flutter/Dart linting rules defined in `analysis_options.yaml` (includes `package:flutter_lints/flutter.yaml`).
- **Scroll Behavior:** Uses a custom `_AppScrollBehavior` to allow mouse dragging on desktop/web environments.
- **UI Components:** Reusable widgets should be placed in `lib/widgets/`.

### Testing Practices
- Widget tests are located in the `test/` directory.
- Verify changes by running `flutter test` before committing.

### Authentication setup (Manual Steps)
- For new environments, ensure the Android Key Hash is registered in the Kakao Developers console and Google SHA-1 is registered in the Firebase console.
- The `AuthService` prints the Kakao Key Hash to the debug console during initialization for easy setup.
