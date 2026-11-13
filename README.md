# TALK-ON

A first-person forward air controller (JTAC) simulator in the style of
*Iron Nest: Heavy Turret Simulator*. You are alone in an observation tower.
You find the target, fix its position, and talk an aircraft onto it over a
heavy analog radio. Every strike is a manual procedure and the game never
does a step for you.

This repository is the **grey-box prototype**: one room, one valley, three
missions and the full strike loop, built from primitive shapes with no art
or audio yet. It exists to answer one question: is a single strike fun?

Built with **Godot 4.7** (GDScript, no plugins, no external assets).

## Play it

1. Install [Godot 4.7](https://godotengine.org/download) (standard build).
2. Open `project.godot` in the editor and press **F5**.

Or download a ready-made build from the **Actions** tab of this repository
(each run attaches Windows and Linux builds), or from **Releases**.

## How a strike works

| Step | Where | What you do |
| --- | --- | --- |
| 1 | Teleprinter | Read the orders, the air frequency and the flights on call |
| 2 | Scope | Find the target. Turn the range drum until the red half-line meets the black one. Press Space to note bearing and range |
| 3 | Map table | Swing the protractor to that bearing and range. Press Enter to pencil the grid on the strike card |
| 4 | Wind dials | Look at the west wall. Wind moves smoke and heavy bombs |
| 5 | Smoke launcher | Optional: fire red smoke at the card grid. A pilot told to use the mark bombs the smoke, wherever it has drifted |
| 6 | Radio | Start the generator, wait for the valves, tune to the frequency, choose flight, heading and mark |
| 7 | Radio | Key the handset. The pilot reads the card back, sometimes wrongly. Confirm it or make him say again |
| 8 | Radio | When he runs in, throw CLEARED HOT, or abort |
| 9 | Scope | Watch the strike land and judge the result |

Every transmission helps the enemy locate the tower. Too many and the
mortars find you. Friendly troops show yellow ground panels.

## Controls

| Key | Action |
| --- | --- |
| W A S D, mouse | Move and look |
| E | Use a station, or leave it |
| Right mouse or B | Binoculars |
| Esc | Pause (R restarts, Q quits) |
| Scope: A/D, W/S | Crank (hold Shift for slow) |
| Scope: mouse | Fine aim |
| Scope: wheel or Z/X | Range drum |
| Scope: Space | Note bearing and range |
| Map: A/D, W/S, Shift, Enter | Swing, slide, fine, pencil the grid |
| Radio: G, A/D, F, H, M | Generator, tune, flight, heading, mark |
| Radio: Space, Y, N, C, X | Transmit, confirm, say again, cleared hot, abort |

## Project layout

```
project.godot            Godot project file
export_presets.cfg       Windows and Linux export presets (used by CI)
scenes/main.tscn         The only scene; everything else is built in code
scripts/game.gd          Autoload "Game": missions, strike card, scoring
scripts/radio.gd         Radio state machine and the pilot conversation
scripts/strike.gd        Pure maths for where weapons land
scripts/main.gd          Builds the world, routes input between views
scripts/player.gd        First-person body and binoculars
scripts/tower.gd         The tower room and its stations
scripts/valley.gd        Ground, landmarks, units, strike effects
scripts/ui/              Scope, map, radio, teleprinter and menu views
data/missions.json       Missions: orders, targets, friendlies, wind, flights
data/aircraft.json       Flights: arrival time, weapon, blast, accuracy
data/valley.json         Landmarks, roads and the river
tests/smoke_test.*       Headless end-to-end test run by CI
tools/                   CI helper scripts
docs/DESIGN.md           Design summary and roadmap
```

New missions and aircraft are data only: edit the JSON files, no code needed.
All tuning numbers are game placeholders, not real-world figures.

## Continuous integration

`.github/workflows/build.yml` runs on every push and pull request:

1. **Test**: downloads Godot, imports the project and runs the headless
   smoke test, which loads the real scene, opens every view and flies one
   complete strike through the radio.
2. **Export**: builds Windows and Linux releases and attaches them to the
   run as artifacts (`talk-on-windows`, `talk-on-linux`).
3. **Release**: when you push a tag such as `v0.1.0`, zips both builds and
   publishes them as a GitHub release.

To use a newer Godot, change `GODOT_VERSION` at the top of the workflow.

Run the same checks locally (Linux or macOS, Godot on your PATH):

```
bash tools/ci_check.sh
```

## Pushing this to GitHub

Create an empty repository on GitHub (no README, no licence), then:

```
git init -b main
git add .
git commit -m "TALK-ON grey-box prototype"
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

The first build starts on its own. To cut a release:

```
git tag v0.1.0
git push origin v0.1.0
```

## Towards Steam

The exported Windows build is a normal standalone game folder, which is what
Steam's upload tool takes. Still to do before a store page: a Steamworks
account and app ID, the GodotSteam plugin for achievements and cloud saves,
and a CI step that uploads builds with `steamcmd`. See `docs/DESIGN.md`.

## Status

Prototype. No licence has been chosen yet, so all rights are reserved until
one is added.
