
# The Task - A Push Registration Toggle Task

You are given the following protocols and enum:

```
enum RegistrationStatus {
    case register
    case unregister
    case anotherDevice
}

protocol PushAuthenticationUC {
    func getRegistrationStatus(session: String) -> AnyPublisher<RegistrationStatus, Error>
    func register(with uuid: String, session: String, token: String) -> AnyPublisher<Bool, Error>
    func deRegister(with uuid: String) -> AnyPublisher<Bool, Error>
}

protocol SessionUC {
    func fetchSession() -> AnyPublisher<String, Error>
}

protocol VendorUC {
    func checkRegistrationStatusPublisher(uuid: String) -> AnyPublisher<RegistrationStatus, Error>
    func registerUser(with uuid: String) -> AnyPublisher<Bool, Error>
    func deRegisterUser(with uuid: String) -> AnyPublisher<Bool, Error>
}
```

```
---

## Description

Create a simple SwiftUI screen that displays a **toggle** representing the users push registration state.

The toggles state depends on the following logic:

* The user is **registered** only if
  `PushAuthenticationUC.getRegistrationStatus(session:)` returns `.register` **and**
  `VendorUC.checkRegistrationStatusPublisher(uuid:)` returns `.register`.

* If one returns `.register` and the other `.unregister`, the combined state should be **unregister**.

* If `PushAuthenticationUC.getRegistrationStatus(session:)` returns `.anotherDevice`,
  the state should be **unregister**, and an appropriate **message** should be shown
  (e.g. Registered on another device).

---

## Additional Conditions

* `getRegistrationStatus` requires a valid `session`, obtained from `SessionUC.fetchSession()`.

* The session fetch is **slow**, so there must be a **3-second delay** after `fetchSession` completes
  before calling `getRegistrationStatus`.

---

## Toggle Behaviour

Once the current registration state is determined, the toggle can be used to **register** or **de-register**.

### De-registration Flow

* Calls both:

  * `PushAuthenticationUC.deRegister(with:)`
  * `VendorUC.deRegisterUser(with:)`
* De-registration succeeds only if **both calls return success**.

### Registration Flow

Registration requires:

* Notification permission via `UNNotificationSettings`
* Push token obtained from the same
* A valid `session` (with the same 3-second delay after fetching it)
* Calls both:

  * `PushAuthenticationUC.register(with:session:token:)`
  * `VendorUC.registerUser(with:)`
* Registration succeeds only if **both calls return success**.

---

## Expected Result

A SwiftUI screen that includes:

* One **toggle** showing the registration status
* A **message** when the state is `.anotherDevice`
* Ability to trigger **register** and **de-register** flows
* Handling for **loading** and **error** states


## Notes

* Focus on **clear analysis and structure** of the logic.
* You do **not** need to provide a working backend, mocks are fine.
* Think about how this screen would integrate in a **real app** (UI consistency, user flow, timing).
* You may include diagrams, pseudocode, or a brief explanation of your design.
```

# The Solution - PushSettings


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
