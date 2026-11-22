# PRISMFALL

A neon bullet-heaven for **Web** and **Android**, built with Godot 4.7 (Compatibility renderer).
Dodge bullet curtains, graze for bombs, draft upgrades, and defeat three multi-phase sector bosses.

| | |
|---|---|
| Engine | Godot **4.7.2-stable**, GL Compatibility |
| Platforms | Web (single-threaded, works on GitHub Pages), Android (APK + Play Store AAB) |
| Package | `com.friendlyuser.prismfall` (change `package/unique_name` in `export_presets.cfg` **before** your first Play upload) |

## Controls
- **Keyboard/gamepad:** WASD / arrows / left stick move · Shift / RB focus · Space / X / A bomb · Esc / P / Start pause
- **Touch (Android / mobile web):** drag anywhere on the left half to move (floating stick) · BOMB and FOCUS buttons bottom-right · pause button top-left · Android back button = pause

Settings (menu → SETTINGS): graphics quality (Low/Medium/High), music & SFX volume, screen shake, touch controls Auto/Always/Never.
Phones default to Medium quality.

## Project layout
```
main.gd / main.tscn        root: post-FX, fades, Android back/focus handling
scripts/autoload/          Game (save, settings, input), Art (atlas, UI theme), Sfx (audio)
scripts/data/db.gd         ALL content: sectors, enemies, bosses, upgrades, shop
scripts/game/              run loop, player, enemies, bosses, bullet/shot/gem/fx pools, HUD
scripts/ui/                menu, touch controls
shaders/                   background (nebula/planet/grid lighting) + post (bloom/grade)
assets/gfx/atlas.png       baked sprite atlas      (tools/bake_gfx.tscn)
assets/icons/              launcher/adaptive icons, splash (tools/bake_gfx.tscn)
audio/                     baked SFX + music       (tools/bake_audio.tscn)
```
Regenerate baked assets after changing their generators:
```
godot --headless --path . res://tools/bake_gfx.tscn
godot --headless --path . res://tools/bake_audio.tscn
```

## Releasing (GitHub Actions)
Workflow: `.github/workflows/build.yml`

| Trigger | Result |
|---|---|
| Pull request | Web + debug APK built as artifacts |
| Push to `main` | Same + **deploy to GitHub Pages** |
| Tag `v*` (e.g. `v1.0.0`) | Same + **GitHub Release** with web zip, APK and AAB |

### One-time setup
1. **Create the repo and push**
   ```
   git init && git add -A && git commit -m "PRISMFALL"
   gh repo create prismfall --public --source . --push
   ```
2. **GitHub Pages**: repo **Settings → Pages → Source: GitHub Actions**.
   The game is then served at `https://<user>.github.io/prismfall/`. (Set repository variable `DEPLOY_PAGES=false` to skip deploys.)
3. **Android signing** (needed for the release APK + AAB; without it CI still builds a debug-signed APK):
   ```
   powershell -ExecutionPolicy Bypass -File tools/android_keystore.ps1     # Windows
   bash tools/android_keystore.sh                                          # macOS/Linux
   ```
   This creates `prismfall-release.keystore` (git-ignored) and sets the secrets
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`.
   **Back the keystore up** - Play requires the same key for every update (or enrol in Play App Signing).

### Cutting a release
```
git tag v1.0.0
git push origin v1.0.0
```
`version/name` comes from the tag, `version/code` from the workflow run number (always increasing).

### Google Play checklist
- Upload `prismfall-<version>.aab` from the release (internal testing track first).
- Store icon: `assets/icons/icon_512.png`. Screenshots: capture from a device/emulator.
- Privacy policy: `docs/privacy.html`, deployed with the web build to `https://<user>.github.io/prismfall/privacy.html`.
- Still needed by you: 1024x500 feature graphic, content rating questionnaire.

## Local builds
Godot 4.7.2 with export templates installed (Editor → Manage Export Templates):
```
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-debug   "Android" build/android/prismfall-debug.apk
```
For the AAB locally: *Project → Install Android Build Template*, then export the `Android-AAB` preset.

## Debug URL flags (web)
`?level=2&t=145&god=1&lv=10&autopick=1&fps=1&quality=0&touch=1` - jump to a sector/time, invulnerable, auto-upgrades, FPS overlay, force quality/touch UI.
