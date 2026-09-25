extends Node
## Game definitions (ingredients, potions, nights) and the state that carries
## from day to day. Registered as the "Data" autoload in project.godot.
## Most balance tuning happens in this file.

const HUT_HP := 5

var moss := Color("465a4b")
var parchment := Color("f5f1e8")
var lantern := Color("d19e60")
var twilight := Color("5c4b6e")
var magic := Color("8bc5c3")
var ink := Color("2b3329")

var ingredient_order := ["puffcap", "honeyroot", "dewmoss", "emberleaf", "moonglow"]
var ingredients := {
	"puffcap": {"name": "Puffcap", "color": Color("b58fd6")},
	"honeyroot": {"name": "Honeyroot", "color": Color("e0a441")},
	"dewmoss": {"name": "Dewmoss", "color": Color("6fae8a")},
	"emberleaf": {"name": "Emberleaf", "color": Color("d9623b")},
	"moonglow": {"name": "Moonglow", "color": Color("9ff0f0")},
}

# Each potion is two ingredients, in either order. Any other pair makes sludge.
# radius/duration: the area the potion covers once it lands or is triggered.
# slow: speed multiplier inside the area (0 = stuck). dps: courage lost per second.
# burst: courage lost once, the moment it lands. ward: hits the hut shrugs off.
var potion_order := ["spore", "syrup", "ember", "ward"]
var potions := {
	"spore": {"name": "Spore Cloud", "color": Color("b58fd6"), "recipe": ["puffcap", "dewmoss"],
		"radius": 95.0, "duration": 6.0, "slow": 0.35, "dps": 0.8, "burst": 0.0, "ward": 0},
	"syrup": {"name": "Sticky Syrup", "color": Color("e0a441"), "recipe": ["honeyroot", "dewmoss"],
		"radius": 70.0, "duration": 5.0, "slow": 0.0, "dps": 0.4, "burst": 0.0, "ward": 0},
	"ember": {"name": "Ember Burst", "color": Color("e8703f"), "recipe": ["emberleaf", "puffcap"],
		"radius": 110.0, "duration": 0.6, "slow": 1.0, "dps": 0.0, "burst": 3.0, "ward": 0},
	"ward": {"name": "Moon Ward", "color": Color("9ff0f0"), "recipe": ["moonglow", "honeyroot"],
		"radius": 0.0, "duration": 0.0, "slow": 1.0, "dps": 0.0, "burst": 0.0, "ward": 3},
}

# One entry per night. courage = how much it takes to make a creature flee.
var nights := [
	{"count": 6, "interval": 2.2, "speed": 55.0, "courage": 2.0},
	{"count": 10, "interval": 1.7, "speed": 62.0, "courage": 3.0},
	{"count": 16, "interval": 1.3, "speed": 70.0, "courage": 3.0},
]

var day := 1
var inventory := {}
var bottles := {}
var discovered := {}
var _snapshot := {}


func reset_game() -> void:
	day = 1
	inventory.clear()
	bottles.clear()
	discovered.clear()
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
		var r: Array = potions[id]["recipe"]
		if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
			return id
	return ""
