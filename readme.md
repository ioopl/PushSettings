# PushSettings

A Simple SwiftUI Push Notifications Enable/Disable screen.

- **Combined state from multiple backends:**  
- Two sources of truth: `PushAuthenticationUC` and `VendorUC`.
- Combine rules:
    - Only registered if **both** `.register`.
    - If one `.register` and one `.unregister` → treat as **unregister**.
    - If push says `.anotherDevice` then show **unregistered state** + **message** (and ignore vendor).

A model that **merge states correctly** (`isRegistered`, `infoMessage`).

- **Async flows with Combine / async logic:**  
- `SessionUC.fetchSession()` first.
- Then a **3 second delay** (side-effect timing).
- Then parallel checks of push + vendor registration.
- Then registration flow:
    - request notification permission + token,
    - fetch session again (with delay),
    - call two backends,
    - only succeed if both succeed.
    
Update the UI on the **main thread**

---

## Architecture explanation

The App follows a clean separation of concerns:
- **Domain / Use-Case Laye:** The system defines protocols such as `SessionUC`, `PushAuthenticationUC`, and `VendorUC`, which abstract backend interactions (session fetching, push registration status, and vendor registration). A dedicated `NotificationService` abstracts notification permission and token retrieval.
- **ViewModel:** `PushRegistrationViewModel` orchestrates all business logic. It consumes the use-case protocols, merges backend registration states, applies rules such as `.anotherDevice`, drives async registration/deregistration flows, and exposes observable state via `@Published` properties (`isRegistered`, `isLoading`, `infoMessage`, `errorMessage`). It also provides UI-ready helpers such as `toggleBinding` and `toggleLabelText`.
- **View:** `PushRegistrationScreen` is a declarative view that binds directly to the ViewModel. It renders state (loading indicator, toggle, messages) and forwards user actions through the toggle binding. The view contains no business logic, it simply reflects ViewModel state.


---
