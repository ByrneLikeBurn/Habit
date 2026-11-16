# How scenes reach the device

Decided 16 November 2026. The owner asked whether only the chosen scene could be downloaded, and then deferred to the reviews. Three lenses answered: performance and app size, security and privacy, release engineer. All three chose the same course.

**Decision.** Every scene ships inside the app. Nothing is downloaded. The budget stays 300 KB per scene. The total rises from 1.5 MB for five scenes to 3.0 MB for ten. This moves into `docs/spec.md` and `docs/decisions.md` when this branch is merged.

**Why.**
- Extra scenes in the bundle do not change launch time, memory or scroll cost. Unused files stay on disk and are never decoded. One tinted scene is about 1.5 MB in memory whatever the count.
- In an asset catalog each device receives one scale: about 1.7 MB for ten scenes on a 3x device and 0.85 MB on 2x.
- Downloading would be the app's first network request, so "no network calls" would stop being true. Apple would learn which scene an account chose.
- Apple-hosted asset packs need the paid Developer Program and work only through TestFlight or the App Store. They are not available on watchOS. They add a downloader extension target and a separate upload and review step for each pack.

**If size ever matters.** Estimates from the performance lens: lossy greyscale HEIC at perhaps 40 to 70 KB per scene, or one scale only.

**Not verified.** What Apple logs for a pack download, and the cellular download threshold.
