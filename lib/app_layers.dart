/// Layering for this codebase (MVC-style, Flutter-friendly).
///
/// | Layer | Directory | Responsibility |
/// |-------|-----------|----------------|
/// | **Model** | [models] | Data classes, enums, Firestore/API shapes |
/// | **Controller** | [controllers] | Validation, orchestration, navigation decisions |
/// | **View** | [views] | Full-page screens; large flows use subfolders (e.g. `views/donor_management/`) |
/// | **Services** | [services] | Auth, HTTP/Cloud Functions, FCM, storage I/O |
/// | **Widgets** | [widgets] | Reusable UI building blocks consumed by views |
/// | **Theme / utils** | [theme], [utils], [constants] | Cross-cutting helpers |
///
/// Prefer: **View** → calls **Controller** + **Services**; **Controller** stays UI-framework
/// agnostic where practical (no `BuildContext` in controllers).
library;
