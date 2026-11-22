# PRISMFALL — Neon Bullet-Heaven (Godot 4, web)

## Source / template research
- Reference: **Survivors Template — Bullet-Heaven Kit for Godot 4** by saltmire — https://saltmire.itch.io/survivors-template-godot
- Download: paid only ($9.99+ via the itch.io "Buy Now" page → `saltmire-survivors-template.zip`, 51 kB, Godot 4.6+). License forbids redistributing the template itself, so this project is an **original implementation** of the same feature set (no template code copied). If the template is purchased later its `.tres`-driven content can be ported into `scripts/data/db.gd`.

| Template feature | PRISMFALL implementation |
|---|---|
| WASD/arrows/gamepad movement | Same + **Focus** (Shift) slow-move with visible hitbox |
| Auto-aim projectile w/ multishot, orbital weapon | Prism Bolts (auto-aim, split), Orbit Shards (also erase bullets), + Seeker Swarm, Nova Pulse |
| 5 data-driven enemies incl. boss | Drone, Mite, Spitter (aimed fans), Bloom (death ring), Spinner (spiral turret) + 3 multi-phase bosses |
| XP gems, magnet, choose 1 of 3 upgrades (8) | Same, 11 upgrades |
| Wave spawner w/ time scaling + boss waves | Per-level wave tables + formation events + boss at timer end |
| Meta currency + shop | Shards → Armory (6 permanent upgrades), saved to `user://` |
| Menu, pause, game over, restart, save/load | Same + level select & sector unlocks |
| Juice: hit flash, damage numbers, shake, particles | Same + bloom post-FX, chromatic aberration, grid shockwaves, hit-stop |

## Player fantasy & loop
Pilot a tiny prism ship through neon sectors. Weapons fire automatically; the player's skill is **dodging dense bullet patterns** (small hitbox, grazing rewards) while collecting XP to draft upgrades. Survive the sector timer, then defeat the sector boss.

- Controls: WASD/Arrows/left stick move · Shift/RB focus (slow, precise, tighter shots) · Space/X/A bomb (clears bullets) · Esc/P/Start pause · 1/2/3 or click to pick upgrades.
- Shields (HP) with i-frames + mercy bullet-clear on hit. Grazing bullets fills the bomb meter.
- Win: defeat boss → shards, next sector unlocked. Lose: shields depleted → partial shards, retry.

## Levels (difficult)
1. **Cobalt Drift** — 2:00 survival, boss **The Warden** (3 phases: spirals, curving rings, counter-spirals).
2. **Crimson Nebula** — 2:30, faster bullets, spinners, boss **Hydra Core** (3 phases, flowers + rain).
3. **Void Bloom** — 2:45, extreme density, boss **Seraph** (4 phases, bullet curtains).

## Visual direction
Geometry-Wars style neon vector art on deep space: additive glow sprites, FBM nebula + parallax stars + warping grid shader (shockwaves ripple the grid), screen-space bloom + chromatic aberration + vignette. Palette per sector (blue / crimson / violet-green). Player = cyan; player shots translucent cyan; enemy bullets saturated colours with white cores for readability.

## Asset list (all procedural — no image/audio generation model connected)
| Asset | Role | Source | Runtime |
|---|---|---|---|
| Glow/core radial textures | bullets, particles, glows | GradientTexture2D in code | `scripts/autoload/art.gd` |
| Ship, enemy, boss vector shapes | characters | polygons drawn in `_draw` | player.gd, enemies.gd, boss_brain.gd |
| Background nebula/grid/stars | sector backdrop | shader | `shaders/background.gdshader` |
| Post FX bloom/aberration | look | shader | `shaders/post.gdshader` |
| SFX (shot, hit, kill, boom, pickup, graze, level-up, hurt, bomb, warning, UI) + synthwave loop | audio | synthesized offline by `tools/bake_audio.tscn` (synth code in `scripts/autoload/sfx.gd`) | `audio/*.wav` |

## Graphics v2 (overhaul)
- **Sprite atlas** (`assets/gfx/atlas.png`, baked by `tools/bake_gfx.tscn`): orb glow/core, ring, rice glow/core, star, soft halo, anamorphic flare, sparkle. Everything additive draws from it so it batches.
- **Bullet shapes**: orb (rings/flowers), rice (oriented along travel: spirals, fans, streams, spinners), star (spinning: rain, bloom bursts). Spawn flash, pulsing white cores, extra ring on big bullets.
- **Ships/enemies/bosses**: radial gradient fills (triangle fans), double-stroke neon outlines, counter-rotating inner details, hit squash, thruster flames, spitter charge-up telegraph, warp-in brackets. Bosses: god rays, ticked outer ring, orbiting satellites, HP-tinted body, core that swells on each volley, hex shield during phase breaks.
- **Player**: banking hull, cockpit gem, twin engine flames + exhaust particles, ribbon trail, muzzle sparkles, shield bubble while invulnerable.
- **FX**: hull debris shards (each polygon edge tumbles away), soft smoke, lens flares on big explosions/bombs/phase breaks, bullet-cancel pops, scaling damage numbers.
- **Background**: 2 nebula layers with dust lanes, 3 star layers (diffraction crosses), lit planet with atmosphere rim and rings per sector, grid lit by dynamic lights (player, boss, explosion/bomb flash) with energy pulses racing along major lines.
- **Post**: soft-knee 3-ring bloom, chromatic aberration, shadow tint + filmic shoulder, vignette, film grain, flashes. Quality tiers Low/Medium/High (Low = no bloom/grain, fewer fbm octaves).
- **Camera**: zooms out during boss fights. **HUD**: angled glass panels, boss bar with delayed damage trail, glowing XP bar, safe-area aware. **Menu**: hyperspace warp intro, per-letter logo shine, rice-bullet flower, planet backdrop. Fade transitions between scenes.

## Mobile / release
- Touch controls (`scripts/ui/touch_controls.gd`): floating joystick (left half), BOMB, FOCUS toggle, PAUSE; auto-shown on first touch or on mobile. Android back = pause/back, app focus loss = pause. Sensor-landscape orientation, immersive mode.
- Settings page: graphics quality, music/SFX volume (audio buses), screen shake, touch mode, reset progress.
- Icons: SVG emblem rasterised to launcher/adaptive (fg/bg/monochrome)/store 512/splash PNGs.
- Export presets: `Web`, `Android` (APK, no Gradle), `Android-AAB` (Gradle, Play Store). CI: `.github/workflows/build.yml` (Pages deploy, signed APK/AAB from secrets, GitHub Release on `v*` tags). See README.md.
- Verified locally: debug APK + Gradle AAB export, APK running on an Android 16 emulator (host GPU) with touch joystick/buttons; Web release export.

## Implementation notes
- Entry: `main.tscn` → `main.gd` (global post-FX layer, swaps menu/run). Content tables: `scripts/data/db.gd`.
- Run loop: `scripts/game/run.gd` owns order: player → spawner/boss flow → enemies → shots → bullets (hit/graze) → gems → fx → camera/background.
- Bullets/shots/gems/particles are packed-array pools drawn in single additive batches (web-friendly).
- Audio is pre-rendered to WAV: runtime PCM synthesis in GDScript stalled the WebAssembly build. Re-run `tools/bake_audio.tscn` headless after changing the synth.
- Save: `user://prismfall_save.json` (shards, armory levels, unlocked sectors, best scores).

## Debug URL flags (web) / test scenes
`?level=2&t=145&god=1&lv=10&autopick=1&sim=40&fps=1&prof=1` — start sector at time t, invulnerable, N auto upgrades, auto-pick level-ups, N fixed sim substeps per frame (for throttled test browsers), FPS overlay, per-system timing. `tests/run_test.tscn` is a headless boss smoke test.

## Verification (playtest)
Checked in the web build: title, sector select, armory (layout, disabled buy states, keyboard nav), Sector I gameplay + Warden boss phases, Sector II level-up draft (key pick), pause, Sector III death → results, boss kill → SECTOR CLEARED → shards awarded + next sector unlocked. Script cost on web ≈1–2 ms/tick at Seraph-level bullet density.
