# TALK-ON: design summary

Short version of the design doc, kept next to the code.

## Pillars

1. **The procedure is the game.** One strike takes eight to ten manual
   steps. Nothing is automated, and skipping a step has a visible cost.
2. **Everything is a physical object.** No HUD and no menus during play.
   Numbers live on dials, cards, maps and the radio's own lamps.
3. **You never leave the room.** The tower is the only set. The war is
   something you see through glass and hear through a headset.
4. **Slow machines create planning.** The radio warms up, aircraft take
   time to arrive, the scope traverses slowly. Good players use the wait.

## Setting

Tower 9, a concrete observation post above a contested river valley in an
invented war, alternate 1950s. Valve radios, brass and bakelite. You are the
lone air controller. The stairwell is sealed; supplies come up by dumbwaiter.

## The strike loop

1. Take the request (teleprinter or ground unit).
2. Find the target (binoculars, then the tripod scope).
3. Fix its position (bearing ring, rangefinder, paper map).
4. Read the air (wind vane, anemometer, light).
5. Choose aircraft and weapon (tasking board).
6. Fill in the strike card.
7. Raise the pilot and read the card.
8. Check the readback.
9. Mark and clear, or abort.
10. Assess and correct.

## Three clocks

- **Ground clock**: the unit that asked for help is losing ground.
- **Fuel clock**: a flight can only hold for so long.
- **Exposure clock**: every transmission helps the enemy find the tower.

## What the prototype covers

| Design element | In the prototype | Still to build |
| --- | --- | --- |
| Tower room | Grey-box room with observation slit | Final art, lighting, wear |
| Binoculars | Hold right mouse | Sway, focus |
| Scope and rangefinder | Bearing ring, split-line range drum | Physical crank and wheel, true split image |
| Map table | Protractor, grid, pencil to card | Grease pencil marks, ruler, wipe |
| Wind | Wall dials with needle wobble | Gusts, cloud base, daylight |
| Radio | Generator, warm-up, tuning, readback, clearance, abort | Antenna crank, valve and fuse faults, jamming, audio |
| Strike card | Grid, flight, heading, mark | Target description, friendly positions, danger-close line |
| Aircraft | Four types with different blast, accuracy, arrival | Fuel windows, multiple passes, corrections from the mark |
| Smoke | Red smoke that drifts with wind | Colours, flares at dusk |
| Exposure | Mortar near-misses, tower knocked out | Cracked glass, cut phone line, antenna knocked off line |
| Missions | Three, data-driven | Twelve-mission campaign, tool unlocks, endless mode |
| Feedback | Text log standing in for voices | Recorded voice fragments, static, generator and valve sound |

## Build order

1. **Grey-box prototype** (this repository). Gate: is one strike fun with
   no art at all?
2. **Vertical slice.** One finished mission with final art, sound and
   voice. Gate: do testers finish it and ask for more?
3. **Store page and demo.** Gate: are wishlists and demo playtime growing?
4. **Content.** Remaining missions, tool unlocks, faults, endless mode.
   Gate: a full playthrough in 6 to 10 hours.
5. **Polish and release.** Tutorial, settings, controller and Steam Deck
   checks, localisation. Gate: Valve's build review passes.

## Suggested next steps in code

- Replace the flat station panels with in-world, grabbable controls.
- Add audio: generator, valve hum, static tied to tuning, pilot voices.
- Let the player give corrections from the smoke mark.
- Add the field telephone, signal lamp and tasking board as stations.
- Move key bindings into the Input Map so they can be rebound.
