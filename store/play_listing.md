# Google Play listing - Prismfall

Play Console: gfleet developer account (studentdavidli), package `com.friendlyuser.prismfall`.

## Main store listing

**App name** (30 max)
Prismfall

**Short description** (80 max)
Dodge neon bullet curtains, draft upgrades and topple three sector bosses.

**Full description** (4000 max)
Light up the dark between the stars.

PRISMFALL is a neon bullet-heaven. Fly a prism ship through swarms of drones, mites and spinners while bullet curtains bloom across the screen. Your weapons fire on their own: your job is to weave, graze and survive.

THREE SECTORS, THREE BOSSES
- Cobalt Drift, Crimson Nebula and Void Bloom, each with its own enemies, bullet patterns and skies.
- Survive the sector to face its boss: The Warden, the Hydra Core and the Seraph, each with several phases of escalating bullet hell.

BUILD YOUR RUN
- Level up and draft from eleven upgrades: Prism Split, Overcharge, Rapid Cycle, Orbit Shards that erase bullets, Nova Pulse, Seeker Swarm, Piercing Light and more.
- Graze bullets on purpose to charge bombs that wipe the screen.
- Hold Focus to slow down and thread the tightest gaps.

GROW STRONGER
- Earn shards every run and spend them on permanent upgrades: hull, damage, speed, pickup range, extra bombs and XP gain.

MADE FOR PHONES
- Floating touch stick on the left, Bomb and Focus buttons on the right, Android back button pauses.
- Game controller support.
- Graphics quality, music, sound, screen shake and touch-control settings.

No ads. No in-app purchases. No data collection. Plays fully offline.

## Graphics (files in this folder)

| Field | File |
| --- | --- |
| App icon (512 x 512) | `assets/icons/icon_512.png` |
| Feature graphic (1024 x 500) | `store/feature_graphic_1024x500.png` |
| Phone and tablet screenshots (16:9, 1920 x 1080) | `store/screenshots/*.png` |

All art is drawn by the game's own code (`tools/bake_gfx.tscn` and shaders), so no assets are labelled as AI-generated.

## Store settings

- **App or game:** Game. **Category:** Arcade. **Free.**
- **Contact email:** davidli012345@gmail.com
- **Website:** https://friendlyuser.github.io/prismfall/
- **Privacy policy:** https://friendlyuser.github.io/prismfall/privacy.html (source: `docs/privacy.html`, deployed by CI)

## App content answers

- **Ads:** No. **Sign in details:** nothing restricted. **Advertising ID:** not used.
- **Data safety:** no data collected or shared; progress and settings stay in app-private storage.
- **Target audience:** 13-15, 16-17, 18 and over.
- **Content rating (IARC):** Game; violence only against non-human, abstract geometric enemies and machine bosses, fantasy setting, unrealistic, no blood. No fear, sex, gambling, language, substances, crude humor, purchases or user interaction.
- **Government / financial / health features:** none.

## Release

- Signed locally with the upload key `%USERPROFILE%\.android-keys\prismfall-upload.jks` (Play App Signing on).
- First bundle: `build/android/prismfall.aab`, version code 1, version name 1.0.0, target SDK 36.
- Later releases: CI's `version/code` is the workflow run number. Make sure each Play upload has a higher code than the last; tag builds need the signing secrets described in the README.
