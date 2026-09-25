extends Node
## Game definitions (mushrooms, potions, creatures, nights) and the state that
## carries from day to day. Registered as the "Data" autoload in project.godot.
## Most balance tuning happens in this file.

const HUT_HP := 5
const NIGHTS := 40
## When mushrooms unlock, in ingredient_order: three on night 1, one more on
## night 2 and night 3, then one every UNLOCK_EVERY nights (6, 9, ... 33).
const EARLY_UNLOCKS := [1, 1, 1, 2, 3]
const UNLOCK_EVERY := 3

var moss := Color("465a4b")
var parchment := Color("f5f1e8")
var lantern := Color("d19e60")
var twilight := Color("5c4b6e")
var magic := Color("8bc5c3")
var ink := Color("2b3329")

# Real mushroom species, in unlock order. weight = how often it turns up on a
# forage walk (Ghost Fungus is the rare one: at most one per walk). The facts are
# shown when a mushroom is first found.
var ingredient_order := ["puffball", "fly_agaric", "chanterelle", "ghost_fungus", "shaggy_ink_cap",
	"scarlet_elf_cup", "turkey_tail", "amethyst_deceiver", "morel", "chicken_of_the_woods",
	"indigo_milk_cap", "porcini", "parasol", "lions_mane", "bleeding_tooth"]
var ingredients := {
	"puffball": {"name": "Common Puffball", "short": "Puffball", "latin": "Lycoperdon perlatum", "color": Color("efe6cf"),
		"weight": 3.0, "fact": "Squeeze a ripe one and a cloud of spores puffs out of the top."},
	"fly_agaric": {"name": "Fly Agaric", "short": "Fly Agaric", "latin": "Amanita muscaria", "color": Color("d8322a"),
		"weight": 3.0, "fact": "The classic red-and-white toadstool of fairy tales. Poisonous."},
	"chanterelle": {"name": "Chanterelle", "short": "Chanterelle", "latin": "Cantharellus cibarius", "color": Color("f0b23a"),
		"weight": 3.0, "fact": "Golden and faintly apricot-scented, with wrinkly ridges instead of true gills."},
	"ghost_fungus": {"name": "Ghost Fungus", "short": "Ghost", "latin": "Omphalotus nidiformis", "color": Color("c8f5d8"),
		"weight": 0.0, "fact": "Really glows green in the dark (bioluminescence). Poisonous."},
	"shaggy_ink_cap": {"name": "Shaggy Ink Cap", "short": "Ink Cap", "latin": "Coprinus comatus", "color": Color("f2efe8"),
		"weight": 2.0, "fact": "Within a day of picking it dissolves itself into black ink, once used for writing."},
	"scarlet_elf_cup": {"name": "Scarlet Elf Cup", "short": "Elf Cup", "latin": "Sarcoscypha austriaca", "color": Color("e0283a"),
		"weight": 2.0, "fact": "Bright red cups that appear on mossy fallen twigs in the middle of winter."},
	"turkey_tail": {"name": "Turkey Tail", "short": "Turkey Tail", "latin": "Trametes versicolor", "color": Color("a8845c"),
		"weight": 2.0, "fact": "Grows in stripy bands of colour, like a turkey's fanned-out tail."},
	"amethyst_deceiver": {"name": "Amethyst Deceiver", "short": "Deceiver", "latin": "Laccaria amethystina", "color": Color("8a4fc8"),
		"weight": 2.0, "fact": "Vivid purple when fresh, but it fades as it ages and becomes hard to recognise."},
	"morel": {"name": "Morel", "short": "Morel", "latin": "Morchella esculenta", "color": Color("b8935a"),
		"weight": 1.5, "fact": "Its honeycomb-pitted cap is completely hollow inside."},
	"chicken_of_the_woods": {"name": "Chicken of the Woods", "short": "Chicken", "latin": "Laetiporus sulphureus", "color": Color("f5902a"),
		"weight": 1.5, "fact": "Bright orange-yellow shelves on tree trunks, also called the sulphur shelf."},
	"indigo_milk_cap": {"name": "Indigo Milk Cap", "short": "Milk Cap", "latin": "Lactarius indigo", "color": Color("4a6ad0"),
		"weight": 1.5, "fact": "Oozes blue milk when it is cut or broken."},
	"porcini": {"name": "Porcini", "short": "Porcini", "latin": "Boletus edulis", "color": Color("8a5a32"),
		"weight": 3.5, "fact": "Has a spongy layer of tiny pores under its cap instead of gills. Also called the penny bun."},
	"parasol": {"name": "Parasol", "short": "Parasol", "latin": "Macrolepiota procera", "color": Color("c8a878"),
		"weight": 1.5, "fact": "Its cap can grow as wide as a dinner plate, on a stem with a snakeskin pattern."},
	"lions_mane": {"name": "Lion's Mane", "short": "Lion's Mane", "latin": "Hericium erinaceus", "color": Color("f5efe0"),
		"weight": 1.0, "fact": "Grows as a cascade of soft, white, icicle-like spines instead of a cap."},
	"bleeding_tooth": {"name": "Bleeding Tooth", "short": "Bl. Tooth", "latin": "Hydnellum peckii", "color": Color("c82838"),
		"weight": 1.0, "fact": "Young ones ooze bright red droplets, like strawberry jam on cream."},
}

# Potions. recipes: pairs of mushrooms, in either order; any other pair makes
# sludge. family decides behaviour and look:
#   spore, syrup, ember, frost, befuddle: an area that lands where thrown or
#     where a trap bursts (radius, duration).
#   ward, mend: used on the hut (ward = hits it shrugs off, heal = hut repaired).
#   roar: night only, scares every creature on the map at once (burst).
# slow: speed multiplier inside the area (0 = stuck, negative = walks backward).
# dps: courage lost per second inside. burst: courage lost once, on landing.
# flying: also affects flying creatures. heavy: also holds heavy creatures.
var potion_order := ["spore", "syrup", "ember", "ward", "ink_pool", "frost", "great_ward", "befuddle",
	"spore_storm", "sulphur", "mend", "deep_freeze", "roar", "dragonfire"]
var potions := {
	"spore": {"name": "Spore Cloud", "family": "spore", "color": Color("b58fd6"),
		"recipes": [["puffball", "fly_agaric"], ["porcini", "puffball"]],
		"radius": 95.0, "duration": 6.0, "slow": 0.35, "dps": 0.8, "flying": true, "heavy": true},
	"syrup": {"name": "Sticky Syrup", "family": "syrup", "color": Color("e0a441"),
		"recipes": [["chanterelle", "puffball"], ["porcini", "chanterelle"]],
		"radius": 70.0, "duration": 5.0, "slow": 0.0, "dps": 0.4, "flying": false, "heavy": false},
	"ember": {"name": "Ember Burst", "family": "ember", "color": Color("e8703f"),
		"recipes": [["fly_agaric", "chanterelle"]],
		"radius": 110.0, "duration": 0.6, "burst": 3.0},
	"ward": {"name": "Moon Ward", "family": "ward", "color": Color("9ff0f0"),
		"recipes": [["ghost_fungus", "chanterelle"]], "ward": 3},
	"ink_pool": {"name": "Ink Pool", "family": "syrup", "color": Color("4a4060"),
		"recipes": [["shaggy_ink_cap", "chanterelle"]],
		"radius": 95.0, "duration": 7.0, "slow": 0.0, "dps": 0.5, "flying": false, "heavy": true},
	"frost": {"name": "Frost", "family": "frost", "color": Color("a8e0ff"),
		"recipes": [["scarlet_elf_cup", "puffball"]],
		"radius": 90.0, "duration": 3.0, "slow": 0.0, "dps": 0.3, "flying": true, "heavy": true},
	"great_ward": {"name": "Great Ward", "family": "ward", "color": Color("6fe0c8"),
		"recipes": [["turkey_tail", "ghost_fungus"]], "ward": 5},
	"befuddle": {"name": "Befuddle", "family": "befuddle", "color": Color("c77dff"),
		"recipes": [["amethyst_deceiver", "fly_agaric"]],
		"radius": 95.0, "duration": 4.0, "slow": -0.6, "dps": 0.3, "flying": true, "heavy": true},
	"spore_storm": {"name": "Spore Storm", "family": "spore", "color": Color("9b6fd6"),
		"recipes": [["morel", "puffball"]],
		"radius": 135.0, "duration": 8.0, "slow": 0.3, "dps": 1.2, "flying": true, "heavy": true},
	"sulphur": {"name": "Sulphur Blast", "family": "ember", "color": Color("f5d23a"),
		"recipes": [["chicken_of_the_woods", "fly_agaric"]],
		"radius": 140.0, "duration": 0.7, "burst": 5.0},
	"mend": {"name": "Mending Milk", "family": "mend", "color": Color("6a8ae0"),
		"recipes": [["indigo_milk_cap", "chanterelle"]], "heal": 2},
	"deep_freeze": {"name": "Deep Freeze", "family": "frost", "color": Color("e0f4ff"),
		"recipes": [["parasol", "scarlet_elf_cup"]],
		"radius": 140.0, "duration": 4.5, "slow": 0.0, "dps": 0.4, "flying": true, "heavy": true},
	"roar": {"name": "Lion's Roar", "family": "roar", "color": Color("f0c060"),
		"recipes": [["lions_mane", "morel"]], "burst": 2.0},
	"dragonfire": {"name": "Dragonfire", "family": "ember", "color": Color("ff4a2a"),
		"recipes": [["bleeding_tooth", "chicken_of_the_woods"]],
		"radius": 165.0, "duration": 0.8, "burst": 7.0},
}

# Creature types. speed and courage multiply the night's base values.
# flying: skips ground traps and most puddles. heavy: syrup only halves its speed.
# damage: hut hits (or ward charges) it costs when it reaches the hut.
# first_night: the night this type starts turning up; share: its part of the
# night's creatures once it has fully arrived.
var creature_order := ["mischief", "scuttler", "stumpling", "moth"]
var creatures := {
	"mischief": {"name": "Mischief", "desc": "A hooded prankster.",
		"speed": 1.0, "courage": 1.0, "size": 42.0, "flying": false, "heavy": false, "damage": 1,
		"first_night": 1, "share": 0.0},
	"scuttler": {"name": "Scuttler", "desc": "Fast but timid. Comes in pairs.",
		"speed": 1.7, "courage": 0.5, "size": 34.0, "flying": false, "heavy": false, "damage": 1,
		"first_night": 3, "share": 0.25},
	"stumpling": {"name": "Stumpling", "desc": "Slow and stubborn. Too heavy to stick. Hits twice as hard.",
		"speed": 0.6, "courage": 2.0, "size": 58.0, "flying": false, "heavy": true, "damage": 2,
		"first_night": 9, "share": 0.15},
	"moth": {"name": "Dusk Moth", "desc": "Flies over traps and syrup. Throw at it!",
		"speed": 1.15, "courage": 0.8, "size": 46.0, "flying": true, "heavy": false, "damage": 1,
		"first_night": 6, "share": 0.15},
}

var day := 1
var inventory := {}
var bottles := {}
var discovered := {}
var seen_creatures := {}
var _snapshot := {}


func reset_game() -> void:
	day = 1
	inventory.clear()
	bottles.clear()
	discovered.clear()
	seen_creatures.clear()
	for id in ingredient_order:
		inventory[id] = 0
	for id in potion_order:
		bottles[id] = 0


## Saved at the start of each day so a lost night can be retried.
## Discovered recipes are kept on a retry: the player still knows them.
func take_snapshot() -> void:
	_snapshot = {"inventory": inventory.duplicate(), "bottles": bottles.duplicate()}


func restore_snapshot() -> void:
	inventory = _snapshot["inventory"].duplicate()
	bottles = _snapshot["bottles"].duplicate()


func recipe_for(a: String, b: String) -> String:
	for id in potion_order:
		for r in potions[id]["recipes"]:
			if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
				return id
	return ""


## The night a mushroom becomes available.
func unlock_night(id: String) -> int:
	var i := ingredient_order.find(id)
	if i < EARLY_UNLOCKS.size():
		return EARLY_UNLOCKS[i]
	return EARLY_UNLOCKS[-1] + UNLOCK_EVERY * (i - EARLY_UNLOCKS.size() + 1)


func is_unlocked(id: String, night: int = -1) -> bool:
	return unlock_night(id) <= (day if night < 0 else night)


func unlocked_mushrooms(night: int = -1) -> Array:
	return ingredient_order.filter(func(id): return is_unlocked(id, night))


## Mushrooms that first appear on this night.
func new_mushrooms(night: int) -> Array:
	return ingredient_order.filter(func(id): return unlock_night(id) == night)


## The first night a potion can be brewed (when both mushrooms of any of its
## recipes are available).
func potion_night(id: String) -> int:
	var best := 999
	for r in potions[id]["recipes"]:
		best = mini(best, maxi(unlock_night(r[0]), unlock_night(r[1])))
	return best


## Settings for night n: more creatures each night, a little faster and braver,
## and new creature types easing in (2 on their first night, full share by the third).
func night_config(n: int) -> Dictionary:
	var count := 6 + int(round((n - 1) * 0.6))
	var waves := {}
	var used := 0
	for kind in creature_order:
		var info: Dictionary = creatures[kind]
		if kind == "mischief" or n < info["first_night"]:
			continue
		var ramp := minf(1.0, float(n - info["first_night"] + 1) / 3.0)
		var k := maxi(2, int(round(count * info["share"] * ramp)))
		waves[kind] = k
		used += k
	waves["mischief"] = maxi(2, count - used)
	return {"interval": maxf(0.9, 2.2 - (n - 1) * 0.035), "speed": minf(78.0, 55.0 + (n - 1) * 0.6),
		"courage": 2.0 + (n - 1) * 0.07, "waves": waves}
