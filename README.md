# Shadow Fortress

A cinematic 2D action game inspired by classic 80s side-scrolling action, built in **Godot 4**. Timing-based combat with weight — block, perfect block, stamina and balance — against guards that patrol, hear you, investigate, and fight in coordinated turns.

> Work in progress. This repo currently contains the **foundation + a playable vertical slice**: the combat system, thinking enemy AI, and one screen you can actually play. Art is blockout (coloured rectangles); every system underneath is real.

## Run it

1. Open **Godot 4.3+**, choose *Import*, and select `project.godot`.
2. Press **F5**.

You start on one screen of Mountain Pass — your warrior versus two guards.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A / D | Left stick |
| Run | Shift | LB |
| Sneak | Ctrl | RB |
| Guard | K | LT |
| Light Punch | J | A / Cross |
| Heavy Punch | U | B / Circle |
| Front Kick | I | X / Square |
| Roundhouse | O | Y / Triangle |
| Sweep | L | RT |

## What works

- Timing combat: block (chip + stamina drain), **perfect block** (guard just before impact = no damage + counter window), sweeps break balance into a knockdown, whiffed heavies punish you.
- Enemy AI: patrol, vision cones, hearing, investigate, engage, defend, flee.
- **Attack tokens** — only two enemies commit at once, so group fights read as deliberate.
- Morale: hurt guards raise the alarm or flee; a death lowers nearby allies' morale.

## Design

See [`DESIGN_DOCUMENT.md`](DESIGN_DOCUMENT.md) for the full GDD, frame data, AI design, architecture, and roadmap.

## License

TODO — pick a license before making the repo public.
