# Mushroom Moon: first playable (grey-box)

Forage by day. Brew your defenses. Protect the witch's hut by night.

This is the "first playable version" from the pitch, drawn with simple shapes
instead of art: 1 hut, 2 paths, 5 ingredients, 4 potions, 3 nights. It exists
to answer one question: **is making a potion satisfying on its own, and does
seeing that potion save the hut make the next brew more exciting?**

Built with Godot 4.7 (GDScript), portrait 720x1280, Compatibility renderer
(runs on older phones and exports to the web).

## Run it

1. Open Godot, click **Import**, pick this folder's `project.godot`.
2. Press **F5** (or the play button, top right).

A mouse click stands in for a finger tap.

## How a day plays

| Phase | What you do |
|---|---|
| Forage (20 s) | Tap ingredients before they fade. One rare Moonglow shows up per walk and fades fast. |
| Brew | Drag two ingredients into the cauldron, then circle your finger around it 3 times. Known pairs make a bottle; anything else is sludge. |
| Fortify | Tap a bottle, then a glowing spot on a path. It bursts when a creature gets close. Moon Ward goes on the hut. Tap a placed bottle to take it back. |
| Night | Creatures walk both paths. Tap a bottle, then tap anywhere to throw it. |

Unused bottles carry over to the next day. Losing a night restarts that day
with the ingredients and bottles you had that morning; discovered recipes stay.

**Recipes (spoilers):** Spore Cloud = Puffcap + Dewmoss (slows, drowsy),
Sticky Syrup = Honeyroot + Dewmoss (stops them), Ember Burst = Emberleaf +
Puffcap (instant scare), Moon Ward = Moonglow + Honeyroot (hut blocks 3 hits).

## Where to change things

| To change | Edit |
|---|---|
| Potion strength, recipes, night difficulty | `scripts/data.gd` (all numbers in one place) |
| Forage length and spawn rate | constants at the top of `scripts/forage.gd` |
| Stir turns needed | `STIR_TURNS` in `scripts/brew.gd` |
| Placeholder shapes (swap for real art later) | `scripts/art.gd` |
| Phase order and top bar | `scripts/main.gd` |

## Tests

Plays one full day with scripted input and prints PASS/FAIL (no window):

```
Godot --headless --path . --quit-after 3000 res://tests/smoke_test.tscn
```

Saves a screenshot of each phase (opens a window briefly):

```
Godot --path . --quit-after 2000 res://tests/screenshots.tscn -- /path/to/folder
```

## Getting it onto a phone

- **Android:** Project > Export > Android. Godot walks you through installing
  the Android build tools the first time. After that, one-click deploy to a
  phone plugged in by USB.
- **iOS:** Project > Export > iOS makes an Xcode project; build it from Xcode
  onto your iPhone. Needs a free Apple ID to test on your own phone, and the
  $99/year developer account to share or publish.
- **Quickest for playtesting (web):** the web build lives in `docs/`, ready
  for GitHub Pages (Settings > Pages > branch `main`, folder `/docs`). Pages
  on a free account needs the repository to be public. To rebuild it:

  ```
  Godot --headless --path . --export-release "Web" docs/index.html
  ```

  The "Web" preset uses the single-threaded template, which runs on any
  static host and in iPhone Safari without special server headers.
  `docs/.gdignore` stops Godot importing the build as game assets.

The first export of any kind needs Godot's export templates
(Editor > Manage Export Templates; for web, only "Web Single-Threaded").
