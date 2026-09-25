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
| Brew | Drag two mushrooms into the cauldron. Three bubbles rise one at a time: tap each as it fills its ring (the ring turns gold). Three Perfect pops make 2 bottles; otherwise 1. Known pairs make a bottle; anything else is sludge. |
| Fortify | Tap a bottle, then a glowing spot on a path. It bursts when a creature gets close. Moon Ward goes on the hut. Tap a placed bottle to take it back. |
| Night | Creatures walk both paths. Tap a bottle, then a glowing spot to place it as a trap (spots free up again once their trap bursts), or tap anywhere else to throw it. |

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

## Mushroom facts and sources

Every mushroom in the game is a real species. Names, Latin names, edibility,
range, season, habitat, facts and dangerous lookalikes (shown in the Field
Guide and on the unlock screen) were checked on 2026-09-25 against the sources
listed per species in `scripts/data.gd`, mainly Wikipedia, First Nature
(first-nature.com), Fungimap and the South Australian Department for
Environment. The "Did you know?" fungi facts come from the Wikipedia articles
Fungus, Mushroom, Mycorrhiza, Armillaria ostoyae, Saccharomyces cerevisiae,
Penicillin and Lichen. Notes from the check:

- Latin names follow current usage for Europe. North American golden
  chanterelles, morels and chickens of the woods are now separate species.
- Morels and Chicken of the Woods are poisonous raw; Chicken of the Woods on
  yew should never be eaten. Lion's Mane is protected by law in Britain.
- Most sources say Ghost Fungus glows green; Fungimap says white.
- No reliable source was found for the Indigo Milk Cap's season outside Mexico.

The game says it on every unlock card and Guide page: real wild mushrooms can
be deadly, so never eat one you find.

## Playtesting shortcuts (web)

- `?day=N` on the game's address starts a fresh run on day N with 5 of every
  potion available by then (e.g. `.../Mushroom-Game/?day=25`). It replaces
  your saved run.
- `?fps` shows a frame counter in the corner.
- After an unexpected reload the top bar says where the last session stopped
  (day, screen, frame rate, and whether Safari reported lost graphics).

## Performance notes

Phone browsers run GDScript far slower than desktop, so redrawing thousands
of shapes every frame is what made the game crawl (and get killed) on iPhone.
Scenery that rarely changes is painted once into an image (`scripts/baked.gd`)
and repainted only when it changes; creatures come from a cached sprite strip
(`scripts/sprites.gd`, 8 walk frames per kind). `tests/perf_test.tscn` times
each drawing layer.
