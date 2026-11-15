# HYADES: Flood Monitoring Mission (Godot 4, first person)

An educational space-mission game for the NASA Space Apps Challenge. You are the mission director of a small
satellite that watches farmland in West Africa: you design it, launch it, fly it, bring its data home and
turn that data into flood warnings for farmers. Every decision carries forward, so a weak choice in Level 1
shows up as missing data in Level 4.

Tested on Godot 4.3 and 4.7.2. Built for a MacBook Pro with 16 GB RAM (all scenes are generated in code,
plants and trees use MultiMesh, heavy models are used sparingly).

## How to play it
**Option 1: download a build (no install).** Open the [Releases](https://github.com/xettak1/project_hyades/releases)
page, download the zip for your system, unzip it and run the game.
- On a Mac, the first time, right-click the app and choose **Open** (the app is not signed by Apple).
- On Windows, if SmartScreen appears, click **More info → Run anyway**.

**Option 2: run from the source code.**
1. Download **Godot 4.3 or newer** (free, no install needed): https://godotengine.org/download
2. Download this repository (**Code → Download ZIP**) and unzip it, or `git clone` it.
3. Open Godot, click **Import**, select `project.godot` in this folder, then press **Play** (F5).
   The first import takes a minute while Godot processes the 3D models.

A mouse and keyboard are needed (see *Controls* below). A full playthrough of the four levels takes about 20–30 minutes.

## Game flow
1. **Title screen** (`scenes/Main.tscn`, `scripts/Title.gd`): H.Y.A.D.E.S logo over Earth at sunrise, with an
   astronaut, satellites and the Moon. Menu: **New Game**, **Continue**, **Options**, **Exit**.
2. **Mission select**: four missions as image cards in a 2×2 grid that fits any screen size.
   - **Flood Monitoring** is the only playable mission (glowing card, *Play Mission*).
   - **Ocean & Ice Radar**, **Lunar Mapper** and **Wildfire Watch** are locked (muted, lock icon, not clickable).
3. **Cinematic trailer** (`scenes/Intro.tscn`, about 40 s): West Africa from space, farmland, a flood,
   a satellite in orbit, then "You are the mission director". **Skip** button (or Space / Esc / Enter).
4. **Four levels**, each opening with a preview card: title, goal, three objectives and why the level matters.
5. **Mission debrief** (`scripts/sim/Debrief.gd`): one card per level with a GOOD / FAIR / POOR verdict,
   a 0–100 level score, the key numbers, up to two **Did right** points and up to two **Could improve** points,
   all worked out from what you actually did (design checks, clear scans, data brought down, floods found,
   false alarms, the warning you chose). The mission score out of 1000 is the average of the four levels.

The game saves at the start of each level; **Continue** resumes there.

## The four levels
| Level | Where you are | What you do | What it teaches |
|---|---|---|---|
| 1 · Launch Segment | Launch control centre overlooking a coastal launch pad (blue metal-plate building) | Install a part in every slot (nothing is preselected), choose orbit, rocket and lifetime, then launch | Every part costs money, mass and power |
| 2 · Space Segment | Inside the satellite, 700 km above Africa | Pick farm regions that are in view, scan them, avoid clouds, watch power and memory | A satellite only sees what passes beneath it |
| 3 · Ground Segment | Satellite ground station with tracking dishes | Choose what comes down first (floods or crops), start the pass | The radio link is the bottleneck |
| 4 · User Segment | Agricultural analysis centre overlooking the farms | Mark flooded plots, choose how to warn people, deliver the report | Data only helps if it reaches people in time |

Level 1 ends with a launch sequence: countdown, ignition, liftoff, and a chase camera into space.

## Interface
- **Top:** mission progress bar (four levels, overall status).
- **Left:** resources for the current level only (budget and mass in Level 1; battery, power, storage and
  observation progress in Level 2; onboard data, link capacity, received and remaining data in Level 3;
  coverage, floods found and confidence in Level 4). Press **I** to collapse.
- **Right:** *Mission Instructions*: the objective, the current task and the next one, with progress.
  Tasks tick themselves off from real gameplay. Press **O** to collapse.
- **Right, when you look at a part:** *Decision card*: name, cost, one advantage, one disadvantage and the
  resource impact. Press **F** for more details.
- **Bottom:** *Mission Tutor*: one short message at a time, key words and numbers highlighted, Next and
  Got it buttons, reacting to your real decisions. Press **T** to hide it.

## Equipment displays
Every screen is a piece of equipment with a casing that matches its room (gunmetal console, white flight
panel, rack-mount unit or slim monitor), a glowing screen behind glass, status lights and buttons.
All readings come from the live game state (`MissionState`).
- **Level 1 launch console:** Mission Budget, Payload Monitor, Rocket Status (countdown, GO / NO-GO), Mission Overview.
- **Level 2 flight displays:** Electrical Power (battery, solar, consumption, sun or eclipse), Data & Instruments,
  Orbital Position map, plus the live satellite camera with telemetry.
- **Level 3 station equipment:** Signal & Antenna Tracking (sky plot, signal graph), Communication Window
  (countdown, bandwidth), Data Downlink (the bottleneck shown as a store draining through a narrow link).
- **Level 4 workstations:** Satellite Image Viewer (region buttons on the desk), Crop Health (NDVI), Flood
  Detection, Analysis Results (image quality, data confidence).

Look at any screen and press **E** to open it full view; click buttons on it. E, Esc or right-click closes it.

## Controls
WASD / arrows: walk · Mouse: look · **E** or left-click: use / install · **Esc**: pause menu
**T** tutor · **O** instructions · **I** resources · **F** decision-card details · **Enter** next tutor message

## Options
Mission Tutor on/off, story intro on/off, fullscreen, music volume, mouse speed, and how to play.
Saved to `user://settings.cfg`; progress to `user://progress.json`.

## Data (edited by the data team, no code needed)
| File | What it holds |
|---|---|
| `data/tables/*.csv` | Missions, parts, orbits, rockets, rocket capacity, scoring, thresholds (green / amber / red / critical) |
| `data/dialogue/tutor_dialogue.json` | Every Mission Tutor line, step and reaction (`**word**` = highlighted) |
| `data/dialogue/decision_cards.json` | Decision-card wording: one advantage and one disadvantage per part |

## Code map
| File | What it does |
|---|---|
| `scripts/autoload/GameData.gd` | Loads the CSV tables; mission, part, orbit and rocket data |
| `scripts/autoload/MissionState.gd` | Current design, resource maths (`compute()`), thresholds (`assess()`), launch review (`gate()`) |
| `scripts/autoload/LevelFlow.gd` | The four levels in order, level preview cards and transitions |
| `scripts/autoload/SaveGame.gd` | Settings and Continue |
| `scripts/autoload/AudioManager.gd` | Music and launch audio |
| `scripts/Title.gd`, `scripts/ui/MissionCard.gd`, `scripts/ui/MenuButtonBar.gd` | Title screen, mission-select cards, menu buttons |
| `scripts/Intro.gd` | Cinematic trailer |
| `scripts/world/Lab.gd`, `LaunchComplex.gd`, `LaunchSequence.gd` | Level 1 building, launch pad, launch sequence |
| `scripts/levels/SpaceSegment.gd`, `GroundSegment.gd`, `UserSegment.gd` | Levels 2–4 (including the Level 2 power model) |
| `scripts/world/SegmentRoom.gd` | Shared base for Levels 2–4 |
| `scripts/world/Screen3D.gd` | Monitor hardware and screens |
| `scripts/panels/AV.gd` | Instrument kit: gauges, meters, readouts, annunciator lamps, graphs, sky plot |
| `scripts/panels/LaunchInstruments.gd`, `SpaceInstruments.gd`, `GroundInstruments.gd`, `UserInstruments.gd` | Equipment displays per level |
| `scripts/panels/ObservationPanel.gd`, `AnalysisPanel.gd`, `ConsolePanel.gd` | Interactive consoles |
| `scripts/ui/MissionTutor.gd`, `TutorDialogueManager.gd` | Mission Tutor UI and logic |
| `scripts/ui/MissionInstructions.gd`, `InstrumentationPanel.gd`, `MissionProgressBar.gd` | Instructions, resources, progress bar |
| `scripts/world/DecisionCard.gd`, `scripts/ui/Consequences.gd` | Decision card and consequence text |
| `scripts/world/Outdoor.gd`, `EarthGlobe.gd`, `FarmRegions.gd` | Skies, terrain, plants, Earth, the four farm regions |
| `scripts/world/Player.gd`, `PauseMenu.gd`, `HUD.gd` | Player, pause menu, crosshair |

## Tests (run from the editor or headless)
| Scene | What it checks |
|---|---|
| `tests/FlowTest.tscn` | Plays all four levels end to end |
| `tests/SelectFlow.tscn` | Mission select → trailer → Skip → Level 1; locked cards do nothing |
| `tests/Smoke.tscn` | Design scenarios and scores |
| `tests/ScreenShots.tscn` | Photographs every screen in a level (`LEVEL=launch|space|ground|user`) |
| `tests/UIShots.tscn`, `tests/TitleShot.tscn` | Interface and title-screen screenshots |
| `tests/DebriefShot.tscn` | Renders the debrief with sample results (`CASE=good|mixed`) |
| `tests/MissionArt.tscn` | Renders the mission-card images (`ART=flood|radar|lunar|wildfire`) |

## Assets
- **Fonts:** Brogame (game font), Inter, JetBrains Mono (`assets/fonts`).
- **Models:** NASA 3D Resources (https://science.nasa.gov/3d-resources/): CubeSat, Landsat 8, MRO, SLS,
  DSN dishes, astronaut, Mercury capsule and others; Earth and Moon models; Poly Haven plants
  (`weed_plant.glb`, `searsia_shrub.glb`). Follow each source's usage guidelines.
- **Textures:** blue metal plate (walls and roof), diamond-plate floor, mission-card images rendered in game.
- Godot cannot read Draco-compressed `.glb` files; decompress them first (e.g. with gltf-transform).
  Models are loaded by `scripts/world/ModelLib.gd`, which scales any `.glb` to fit.

## Team
- Kwadwo Addo Adomako
- Kwame Emmanuel Adi
- Ntow Emmanuel Akyea
- Godwin Egyir
- Solomon Frimpong

## Credits and sources
**Data.** Every number in `data/tables/*.csv` has its source in the `source` column. Main sources:
NASA (LRO, PDS, NSSDC archive, NASA Small Spacecraft State of the Art), ESA eoPortal (Planet Dove, LRO),
the ANDES 6U CubeSat platform (UNLP), EnduroSat, CubeSatShop, satsearch, SatCatalog, WMO OSCAR,
ICEYE, Arizona State University (LROC), and SpaceNexus and New Space Economy for launch prices.
Values marked *estimate* or *game value* in the tables are our own, chosen to keep the game balanced.

**3D models.** NASA 3D Resources (https://science.nasa.gov/3d-resources/). Plants from Poly Haven, CC0
(https://polyhaven.com/a/weed_plant_02, https://polyhaven.com/a/searsia_lucida, https://polyhaven.com/a/tree_small_02).

**Textures.** Poly Haven, CC0 (https://polyhaven.com/textures).

**Fonts.** Inter (https://rsms.me/inter/) and JetBrains Mono (https://www.jetbrains.com/lp/mono/), both SIL Open Font
License (licence files in `assets/fonts`). Brogame (game display font).

**Tools.** Godot Engine 4, GDScript, Blender, glTF-Transform, Python with trimesh, Git and GitHub.
Claude (Anthropic) was used as a coding assistant.

Made for the NASA International Space Apps Challenge 2026.

