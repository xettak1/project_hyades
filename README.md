# Mission Control: Space Mission Design Game (Godot 4, first person)

Title screen -> choose a mission -> walk around that mission's building, install real-looking parts on
your spacecraft, launch it from the Mission Console, then watch it fly from Mission Control.
Tested on Godot 4.3 and 4.7.2.

| Mission | Difficulty | Where you build it | Main challenge |
|---|---|---|---|
| Flood & Crop Watch | Easy | CubeSat cleanroom lab | Data: small radio vs lots of images |
| Radar Ocean & Ice Mapper | Medium | Satellite integration hall (crane, pallets) | Power: hungry radar, eclipse, orbit choice |
| Lunar Mapper | Hard | Deep-space hangar | Fuel: braking into lunar orbit, tank size, trajectory |

Scenes: `scenes/Main.tscn` (title + mission select, `scripts/Title.gd`) and `scenes/Lab.tscn` (the mission world).
Esc in a mission opens the pause menu (resume, restart, choose another mission, quit).

## Controls
WASD / arrows: walk · Mouse: look · E or left-click: use · Esc: pause menu

## How to play
1. Read the **Briefing** screen on the front wall (objective + 3 requirements).
2. Walk to the shelves. Look at a part to see its specs, press **E** to install it.
   The CubeSat on the stand in the middle updates, and the **Resources** and **Advisors** screens update live.
3. At the **Mission Console** (right wall): pick orbit, rocket and lifetime, then press **LAUNCH**.
   Blocked designs are refused; designs with warnings need a second press.
4. You are taken to **Mission Control**: watch the orbit, use the desk buttons (1x, 10x, Skip).
5. Read the **Mission Report** on the big screen, walk back (or press BACK TO LAB), improve, relaunch.

## Code map
| File | What it does |
|---|---|
| `scripts/autoload/GameData.gd` | All numbers per mission: parts, orbits, rockets, room look (`env`), scoring. Data team edits this |
| `scripts/autoload/MissionState.gd` | Current design, resource maths (`compute()`), launch review (`gate()`) |
| `scripts/sim/Simulator.gd` | Day-by-day simulation, random events, score, "why" explanations |
| `scripts/sim/OrbitPath.gd` | Orbit points; loads GMAT CSV from `data/orbits/<orbit_id>_path.csv` |
| `scripts/world/Lab.gd` | Builds the mission's building from its `env` settings and runs launch/operations |
| `scripts/world/PauseMenu.gd` | Esc menu |
| `scripts/world/Player.gd` | First-person controller + "look at and press E" |
| `scripts/world/PartModels.gd` | 3D models of every part, built from simple shapes. Replace with .glb models later |
| `scripts/world/PartItem.gd` | A part on a shelf (specs label, install) |
| `scripts/world/Satellite.gd` | The CubeSat on the stand; where each part is mounted |
| `scripts/world/Button3D.gd` | Physical console buttons |
| `scripts/world/Screen3D.gd` | Wall monitors (2D panels or 3D views rendered onto a screen) |
| `scripts/world/OrbitView.gd` | Earth + orbit + spacecraft shown on the Mission Control screen |
| `scripts/panels/*.gd` | What each monitor shows (briefing, advisors, console, operations, report) |
| `tests/Smoke.tscn` | Automatic test of the whole flow (F6). `tests/Shots.tscn` saves screenshots |

## Plugging in team work
- Earth texture: NASA Blue Marble map saved as `assets/earth.jpg`.
- GMAT orbits: `data/orbits/leo_550_path.csv`, `sso_550_path.csv` (columns `t_sec,x_km,y_km,z_km`).
- Real 3D models: import a .glb into `assets/models/` and return it from `PartModels.build()` for that part id.

## 3D models (assets/models)
Loaded by `scripts/world/ModelLib.gd`, which measures each model and scales it to fit, so any size of `.glb` works.
- **Part models:** a file named after a part id (e.g. `radio_x.glb`, `tank_l.glb`, `bus_...`) replaces the built-in shape automatically (see `PartModels.GLB_SIZE`).
- **Orbit view spacecraft:** `env.orbit_model` per mission (`sc_cubesat`, `sc_landsat8`, `sc_mro`).
- **Planets:** `earth.glb` (and `moon.glb` if added).
- **Exhibits:** `env.exhibits` per mission (model, position, height, rotation, plaque text).
- Godot cannot read Draco-compressed `.glb` files. These were decompressed with gltf-transform first:
  cubesat, Landsat 8, Astronaut, Friendship 7, DSN 34 m, DSN antenna, Ares I, TDRS, Pioneer 10.

Model credits: NASA 3D Resources (https://science.nasa.gov/3d-resources/). Follow NASA's media usage guidelines.

## Screens
Look at any wall screen and press E to open it full view. Click buttons on it (Mission Console: orbit, rocket,
lifetime, LAUNCH; Operations: speed, skip; Report: back to lab). E, Esc or right-click closes it.
