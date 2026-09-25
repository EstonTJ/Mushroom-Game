extends Node
## Game definitions (mushrooms, potions, creatures, nights) and the state that
## carries from day to day. Registered as the "Data" autoload in project.godot.
## Most balance tuning happens in this file.

## Shown on the title screen and in the menu, so players can tell whether
## their browser has the latest update. Bump it with each release.
const VERSION := "0.19"
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
# forage walk (Ghost Fungus is the rare one: at most one per walk). Names,
# edibility, range, season, habitat, facts and lookalikes were checked against
# the listed sources (2026-09-25); the first fact shows on the unlock screen and
# everything shows in the Field Guide.
var ingredient_order := ["puffball", "fly_agaric", "chanterelle", "ghost_fungus", "shaggy_ink_cap",
	"scarlet_elf_cup", "turkey_tail", "amethyst_deceiver", "morel", "chicken_of_the_woods",
	"indigo_milk_cap", "porcini", "parasol", "lions_mane", "bleeding_tooth"]
var ingredients := {
	"puffball": {"name": "Common Puffball", "short": "Puffball", "latin": "Lycoperdon perlatum", "color": Color("efe6cf"),
		"weight": 3.0, "edibility": "Edible if an expert identifies it", "where": "Worldwide: Europe, Asia, Africa, Australia, New Zealand and the Americas",
		"season": "Summer to autumn", "habitat": "On the ground in woodland leaf litter, grassy clearings, fields and gardens",
		"facts": ["When it is ripe, a hole opens on top. Raindrops or a squeeze puff out a smoky cloud of spores.", "One puff can release more than a million spores."],
		"lookalike": "Young deadly Amanitas (like the death cap) can look like puffball buttons; so can poisonous earthballs.",
		"sources": ["https://en.wikipedia.org/wiki/Lycoperdon_perlatum", "https://www.first-nature.com/fungi/lycoperdon-perlatum.php"]},
	"fly_agaric": {"name": "Fly Agaric", "short": "Fly Agaric", "latin": "Amanita muscaria", "color": Color("d8322a"),
		"weight": 3.0, "edibility": "Poisonous", "where": "Temperate and northern forests of Europe, Asia and North America",
		"season": "Late summer to autumn", "habitat": "Under birch, pine and spruce, and also oak, fir and cedar",
		"facts": ["Its name comes from an old trick: pieces were put in milk to kill flies.", "The white spots are leftovers of a skin that wrapped the baby mushroom. Rain can wash them off."],
		"lookalike": "",
		"sources": ["https://en.wikipedia.org/wiki/Amanita_muscaria", "https://www.first-nature.com/fungi/amanita-muscaria.php"]},
	"chanterelle": {"name": "Chanterelle", "short": "Chanterelle", "latin": "Cantharellus cibarius", "color": Color("f0b23a"),
		"weight": 3.0, "edibility": "Edible if an expert identifies it", "where": "Europe, from Scandinavia to the Mediterranean",
		"season": "Summer to autumn", "habitat": "In broadleaf and conifer woods on acid soil, often with oak, chestnut or hazel",
		"facts": ["Golden and faintly apricot-scented, with wrinkly ridges instead of true gills.", "It lives in partnership with trees, trading nutrients with their roots."],
		"lookalike": "The poisonous jack-o'-lantern mushroom; also the false chanterelle, which has true gills.",
		"sources": ["https://en.wikipedia.org/wiki/Cantharellus_cibarius", "https://www.first-nature.com/fungi/cantharellus-cibarius.php"]},
	"ghost_fungus": {"name": "Ghost Fungus", "short": "Ghost", "latin": "Omphalotus nidiformis", "color": Color("c8f5d8"),
		"weight": 0.0, "edibility": "Poisonous", "where": "Southern Australia and Tasmania",
		"season": "Autumn and winter", "habitat": "In clusters on pine stumps, at the base of living gum trees and on dead wood",
		"facts": ["Its gills glow a ghostly green in the dark. One person said it was bright enough to read a watch by.", "Some Aboriginal peoples called it chinga, meaning spirit."],
		"lookalike": "Edible oyster mushrooms. People have been poisoned after mistaking ghost fungus for them.",
		"sources": ["https://en.wikipedia.org/wiki/Omphalotus_nidiformis", "https://www.environment.sa.gov.au/goodliving/posts/2018/05/ghost-mushrooms", "https://fungimap.org.au/omphalotus-nidiformis-ghost-fungus/"]},
	"shaggy_ink_cap": {"name": "Shaggy Ink Cap", "short": "Ink Cap", "latin": "Coprinus comatus", "color": Color("f2efe8"),
		"weight": 2.0, "edibility": "Edible if an expert identifies it", "where": "Across the Northern Hemisphere; brought to Australia and New Zealand",
		"season": "Spring to autumn, mostly summer and autumn", "habitat": "Lawns, grass verges, path edges, gravel and open woodland",
		"facts": ["Within hours of being picked, it turns black and melts into an inky goo full of spores.", "Its shaggy white cap looks like an old-fashioned lawyer's wig, one of its nicknames."],
		"lookalike": "The poisonous magpie ink cap.",
		"sources": ["https://en.wikipedia.org/wiki/Coprinus_comatus", "https://www.first-nature.com/fungi/coprinus-comatus.php"]},
	"scarlet_elf_cup": {"name": "Scarlet Elf Cup", "short": "Elf Cup", "latin": "Sarcoscypha austriaca", "color": Color("e0283a"),
		"weight": 2.0, "edibility": "Inedible", "where": "Europe and northeastern North America",
		"season": "Winter to early spring", "habitat": "On rotting hardwood twigs and branches half-buried in moss, in damp shady places",
		"facts": ["Its bright red cups pop up in winter and early spring, on rotting twigs hidden in moss.", "Its twin, the ruby elf cup, looks the same. You need a microscope to tell them apart!"],
		"lookalike": "",
		"sources": ["https://en.wikipedia.org/wiki/Sarcoscypha_austriaca", "https://www.first-nature.com/fungi/sarcoscypha-austriaca.php"]},
	"turkey_tail": {"name": "Turkey Tail", "short": "Turkey Tail", "latin": "Trametes versicolor", "color": Color("a8845c"),
		"weight": 2.0, "edibility": "Inedible", "where": "Worldwide",
		"season": "All year, best in autumn and winter", "habitat": "In overlapping layers on dead hardwood logs and stumps, such as beech and oak",
		"facts": ["Its stripy bands of colour look like a turkey's fanned tail. Versicolor means of several colours.", "Too tough to eat, but scientists study it as a possible medicine."],
		"lookalike": "",
		"sources": ["https://en.wikipedia.org/wiki/Trametes_versicolor", "https://www.first-nature.com/fungi/trametes-versicolor.php"]},
	"amethyst_deceiver": {"name": "Amethyst Deceiver", "short": "Deceiver", "latin": "Laccaria amethystina", "color": Color("8a4fc8"),
		"weight": 2.0, "edibility": "Edible if an expert identifies it", "where": "Temperate Europe, Asia, and North and South America",
		"season": "Summer to early winter", "habitat": "In leaf litter in all kinds of woodland, especially under beech",
		"facts": ["Bright purple when fresh, but it fades as it dries or ages. That is why it is called a deceiver.", "It is a tree partner, especially of beech, trading nutrients with the tree's roots."],
		"lookalike": "The lilac bonnet, which contains a toxin called muscarine.",
		"sources": ["https://en.wikipedia.org/wiki/Laccaria_amethystina", "https://www.first-nature.com/fungi/laccaria-amethystina.php"]},
	"morel": {"name": "Morel", "short": "Morel", "latin": "Morchella esculenta", "color": Color("b8935a"),
		"weight": 1.5, "edibility": "Edible only when cooked", "where": "Europe, also reported from Asia; other morel species grow in North America",
		"season": "Spring", "habitat": "On chalky soil under broadleaf trees such as ash, elm and apple",
		"facts": ["Its honeycomb-pitted cap and its stem are both hollow inside.", "Morels are poisonous raw. They must always be cooked well before anyone eats them."],
		"lookalike": "The deadly poisonous false morel, which has a brain-like, not pitted, cap.",
		"sources": ["https://en.wikipedia.org/wiki/Morchella_esculenta", "https://www.first-nature.com/fungi/morchella-esculenta.php"]},
	"chicken_of_the_woods": {"name": "Chicken of the Woods", "short": "Chicken", "latin": "Laetiporus sulphureus", "color": Color("f5902a"),
		"weight": 1.5, "edibility": "Edible only when cooked", "where": "Europe and North America",
		"season": "Summer to autumn", "habitat": "On dead or dying hardwood trees such as oak, sweet chestnut, beech, cherry and willow; also on yew",
		"facts": ["Also called the sulphur shelf, it grows in bright orange-yellow tiers on tree trunks.", "Some people say it tastes like chicken, which is how it got its name."],
		"lookalike": "Never eat one growing on a yew tree, which is poisonous; also the giant polypore.",
		"sources": ["https://en.wikipedia.org/wiki/Laetiporus_sulphureus", "https://www.first-nature.com/fungi/laetiporus-sulphureus.php"]},
	"indigo_milk_cap": {"name": "Indigo Milk Cap", "short": "Milk Cap", "latin": "Lactarius indigo", "color": Color("4a6ad0"),
		"weight": 1.5, "edibility": "Edible if an expert identifies it", "where": "Southern and eastern North America, Mexico and Guatemala",
		"season": "Summer to autumn, in the rainy season", "habitat": "In oak and pine forests",
		"facts": ["When cut, it oozes indigo-blue milk that slowly turns green in the air.", "Its blue colour comes from a special chemical found in no other mushroom."],
		"lookalike": "",
		"sources": ["https://en.wikipedia.org/wiki/Lactarius_indigo"]},
	"porcini": {"name": "Porcini", "short": "Porcini", "latin": "Boletus edulis", "color": Color("8a5a32"),
		"weight": 3.5, "edibility": "Edible if an expert identifies it", "where": "Northern Hemisphere: Europe, Asia and North America, south to Mexico",
		"season": "Summer to autumn", "habitat": "Under pine, spruce, fir and hemlock, and under oak and beech",
		"facts": ["Has a spongy layer of tiny pores under its cap instead of gills. Also called the penny bun.", "Big ones can weigh more than 3 kilograms!"],
		"lookalike": "The poisonous devil's bolete (red stem, bruises blue); also the very bitter bitter bolete.",
		"sources": ["https://en.wikipedia.org/wiki/Boletus_edulis"]},
	"parasol": {"name": "Parasol", "short": "Parasol", "latin": "Macrolepiota procera", "color": Color("c8a878"),
		"weight": 1.5, "edibility": "Edible if an expert identifies it", "where": "Temperate Europe and Asia; also reported from North America",
		"season": "Summer to autumn", "habitat": "In pastures, grassy woodland clearings and sand dunes, sometimes in fairy rings",
		"facts": ["Its cap can grow up to 25 cm wide, about the size of a dinner plate.", "Its tall stem has a snakeskin pattern and a ring you can slide up and down."],
		"lookalike": "The poisonous green-spored parasol; also deadly Amanitas and small Lepiotas.",
		"sources": ["https://en.wikipedia.org/wiki/Macrolepiota_procera", "https://www.first-nature.com/fungi/macrolepiota-procera.php"]},
	"lions_mane": {"name": "Lion's Mane", "short": "Lion's Mane", "latin": "Hericium erinaceus", "color": Color("f5efe0"),
		"weight": 1.0, "edibility": "Edible if an expert identifies it", "where": "North America, Europe and Asia",
		"season": "Late summer to winter", "habitat": "On dead or dying hardwood trees, especially beech, oak and maple",
		"facts": ["Grows as a cascade of soft, white, icicle-like spines instead of a cap.", "It is rare in Britain and protected by law there, so it must not be picked."],
		"lookalike": "",
		"sources": ["https://en.wikipedia.org/wiki/Hericium_erinaceus", "https://www.first-nature.com/fungi/hericium-erinaceus.php"]},
	"bleeding_tooth": {"name": "Bleeding Tooth", "short": "Bl. Tooth", "latin": "Hydnellum peckii", "color": Color("c82838"),
		"weight": 1.0, "edibility": "Inedible", "where": "North America and Europe (in Britain, only Scotland); also Iran and Korea",
		"season": "Late summer to autumn", "habitat": "On mossy soil under conifers, especially pine and spruce",
		"facts": ["Young ones ooze bright red droplets, so it is nicknamed strawberries and cream.", "Under its cap are little teeth, not gills. It tastes fiery hot, so it is not for eating!"],
		"lookalike": "",
		"sources": ["https://en.wikipedia.org/wiki/Hydnellum_peckii", "https://www.first-nature.com/fungi/hydnellum-peckii.php"]},
}

# "Did you know?" facts about the fungi kingdom (Field Guide and unlock screen).
# Sources: Wikipedia articles Fungus, Mushroom, Mycorrhiza, Armillaria ostoyae,
# Saccharomyces cerevisiae, Penicillin and Lichen (checked 2026-09-25).
var kingdom_facts := [
	"Fungi are more closely related to animals than to plants.",
	"Fungi cannot make food from sunlight like plants do. They soak up food from around them.",
	"Fungi build their cell walls from chitin, not the cellulose that plants use.",
	"A mushroom is just the fruiting body of a fungus. Its job is to make and spread spores.",
	"The main body of a fungus is mycelium: a hidden web of tiny threads called hyphae.",
	"Fungi are nature's main recyclers. They break down dead things so nutrients can be used again.",
	"About 80% of plant species team up with fungi on their roots, trading sugar for water and nutrients.",
	"A honey fungus in Oregon, USA, covers about 9 square kilometres and is thousands of years old.",
	"Only about 148,000 kinds of fungi have been named, but there may be 2.2 to 3.8 million.",
	"Baker's yeast is a tiny fungus. The gas it makes is what makes bread dough rise.",
	"In 1928 Alexander Fleming saw a mould killing germs. This led to penicillin, a life-saving medicine.",
	"A lichen is a team: a fungus living together with algae or cyanobacteria.",
]

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
# armor: share of burst damage it shrugs off. resist: potion families that do
# nothing to it. split: on being scared off it bursts into this many of
# split_kind. first_night: the night it starts turning up; share: its part of
# the night's creatures once it has fully arrived. coins and bone_chance: loot
# when scared off by a potion (not when blocked by a ward).
# Bosses (boss: true) come alone, one every 3rd night, with a health bar and
# summon: {kind, every (seconds), count} minions as they walk.
var creature_order := ["mischief", "scuttler", "stumpling", "moth", "thornback", "wisp", "puffling", "troll"]
var boss_order := ["mischief_king", "moth_queen", "elder_stumpling"]
var creatures := {
	"mischief": {"name": "Mischief", "desc": "A hooded prankster.",
		"speed": 1.0, "courage": 1.0, "size": 42.0, "flying": false, "heavy": false, "damage": 1,
		"first_night": 1, "share": 0.0, "coins": 2, "bone_chance": 0.3},
	"scuttler": {"name": "Scuttler", "desc": "Fast but timid. Comes in pairs.",
		"speed": 1.7, "courage": 0.5, "size": 34.0, "flying": false, "heavy": false, "damage": 1,
		"first_night": 3, "share": 0.2, "coins": 1, "bone_chance": 0.2},
	"stumpling": {"name": "Stumpling", "desc": "Slow and stubborn. Too heavy to stick. Hits twice as hard.",
		"speed": 0.6, "courage": 2.0, "size": 58.0, "flying": false, "heavy": true, "damage": 2,
		"first_night": 9, "share": 0.1, "coins": 5, "bone_chance": 1.0},
	"moth": {"name": "Dusk Moth", "desc": "Flies over traps and syrup. Throw at it!",
		"speed": 1.15, "courage": 0.8, "size": 46.0, "flying": true, "heavy": false, "damage": 1,
		"first_night": 6, "share": 0.12, "coins": 3, "bone_chance": 0.4},
	"thornback": {"name": "Thornback", "desc": "Armoured: bursts only do half. Wear it down with spores and syrup.",
		"speed": 0.85, "courage": 1.6, "size": 52.0, "flying": false, "heavy": true, "damage": 2, "armor": 0.5,
		"first_night": 12, "share": 0.1, "coins": 4, "bone_chance": 0.5},
	"wisp": {"name": "Will-o'-Wisp", "desc": "A fast floating flame. It doesn't breathe, so spores do nothing.",
		"speed": 1.5, "courage": 0.9, "size": 40.0, "flying": true, "heavy": false, "damage": 1, "resist": ["spore"],
		"first_night": 15, "share": 0.1, "coins": 3, "bone_chance": 0.3},
	"puffling": {"name": "Puffling", "desc": "A walking puffball. Scare it and it bursts into two Scuttlers!",
		"speed": 0.9, "courage": 1.3, "size": 46.0, "flying": false, "heavy": false, "damage": 1,
		"split": 2, "split_kind": "scuttler",
		"first_night": 18, "share": 0.08, "coins": 2, "bone_chance": 0.2},
	"troll": {"name": "Bramble Troll", "desc": "Huge and mossy. Too heavy to stick, tough, and it hits three times.",
		"speed": 0.45, "courage": 3.5, "size": 80.0, "flying": false, "heavy": true, "damage": 3, "armor": 0.25,
		"first_night": 21, "share": 0.06, "coins": 8, "bone_chance": 1.0},
	"mischief_king": {"name": "The Mischief King", "desc": "Boss! He summons Mischief as he marches.", "boss": true,
		"speed": 0.55, "courage": 14.0, "size": 96.0, "flying": false, "heavy": true, "damage": 4,
		"summon": {"kind": "mischief", "every": 4.0, "count": 2}, "coins": 25, "bone_chance": 1.0, "bones": 3},
	"moth_queen": {"name": "The Moth Queen", "desc": "Boss! She flies over traps and calls her moths.", "boss": true,
		"speed": 0.6, "courage": 12.0, "size": 100.0, "flying": true, "heavy": false, "damage": 4,
		"summon": {"kind": "moth", "every": 4.5, "count": 2}, "coins": 25, "bone_chance": 1.0, "bones": 3},
	"elder_stumpling": {"name": "The Elder Stumpling", "desc": "Boss! Ancient, armoured and far too heavy to stick.", "boss": true,
		"speed": 0.35, "courage": 20.0, "size": 110.0, "flying": false, "heavy": true, "damage": 5, "armor": 0.4,
		"summon": {"kind": "stumpling", "every": 7.0, "count": 1}, "coins": 25, "bone_chance": 1.0, "bones": 3},
}

## Lab upgrades sold at the dawn market. Bone Mortar lets a monster bone go
## into the cauldron to brew an Empowered potion.
var shop_items := {
	"bone_mortar": {"name": "Bone Mortar", "price": 30,
		"desc": "Grind monster bones into your brews. Adds a bone bowl to the cauldron: drop a bone in with two mushrooms to brew an Empowered potion (bigger, longer, stronger)."},
	"bone_appetit": {"name": "Bone Appétit", "price": 60, "requires": "bone_mortar",
		"desc": "Never forget a bone again. Drops a monster bone into every brew by itself, as long as you have one. Switch it off at the bone bowl to save bones."},
	"batch_brewer": {"name": "Loader of Mass Production", "price": 100,
		"desc": "Brew up to 5 potions at once. Set the batch dial by the cauldron: each potion in the batch uses one of each mushroom (and a bone, if one's in)."},
	"truffle_pig": {"name": "Truffle Pig", "price": 75, "kind": "Forest helper",
		"desc": "A keen-nosed pig joins your forest walks. It sniffs out the nearest mushroom and gathers it for you, then pauses to celebrate. Rocks and stumps are still up to you."},
}
## The most potions one batch can make (with the Batch Brewer).
const MAX_BATCH := 5
var shop_order := ["bone_mortar", "bone_appetit", "batch_brewer", "truffle_pig"]

## How much stronger an Empowered potion (one brewed with a monster bone) is.
const EMPOWER := {"radius": 1.3, "duration": 1.4, "dps": 1.5, "burst": 1.5, "ward": 2, "heal": 1}

var day := 1
## The furthest day reached; nights up to this can be replayed from the menu.
var best_day := 1
var coins := 0
var bones := 0
var upgrades := {}
## Whether the Bone Appétit adds bones by itself (switch on the bone bowl).
var auto_bone := true
## Batch size chosen on the Batch Brewer's dial (1 = no batching).
var batch := 1
var _empowered := {}
var inventory := {}
var bottles := {}
var discovered := {}
var seen_creatures := {}
## The last day whose "new mushroom" screen has been shown.
var unlock_seen := 0
var _snapshot := {}


func reset_game() -> void:
	day = 1
	best_day = 1
	inventory.clear()
	bottles.clear()
	discovered.clear()
	seen_creatures.clear()
	unlock_seen = 0
	coins = 0
	bones = 0
	upgrades.clear()
	auto_bone = true
	batch = 1
	for id in ingredient_order:
		inventory[id] = 0
	for key in bottle_keys():
		bottles[key] = 0


const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
## In a browser the save is also kept in localStorage, which is written at
## once; Godot's own user:// storage (IndexedDB) is synced a moment later and
## can miss a save if the page is killed right after it.
const WEB_SAVE_KEY := "mushroom_moon_save"
const WEB_DIAG_KEY := "mushroom_moon_diag"
const WEB_EVENT_KEY := "mushroom_moon_event"

## Which screen the last save was made on ("forage", "brew" or "fortify"),
## so a reload resumes there.
var saved_phase := "forage"


func _web() -> bool:
	return OS.has_feature("web")


## Writes the current state to disk (and localStorage in a browser). phase is
## the screen to resume on after a reload; the start-of-day snapshot is saved
## too so "Retry day" still works after a reload.
func save_game(phase: String = "forage") -> void:
	var text := JSON.stringify({"version": SAVE_VERSION, "day": day, "phase": phase, "inventory": inventory,
		"bottles": bottles, "discovered": discovered, "seen_creatures": seen_creatures, "unlock_seen": unlock_seen,
		"coins": coins, "bones": bones, "upgrades": upgrades, "auto_bone": auto_bone, "batch": batch, "best_day": maxi(best_day, day), "snapshot": _snapshot})
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	if _web():
		JavaScriptBridge.eval("try { localStorage.setItem(%s, %s); } catch (e) {}" % [JSON.stringify(WEB_SAVE_KEY), JSON.stringify(text)])


func _read_save_text() -> String:
	if _web():
		var web_text = JavaScriptBridge.eval("(function(){ try { return localStorage.getItem(%s) || ''; } catch (e) { return ''; } })()"
			% JSON.stringify(WEB_SAVE_KEY))
		if typeof(web_text) == TYPE_STRING and web_text != "":
			return web_text
	if FileAccess.file_exists(SAVE_PATH):
		return FileAccess.get_file_as_string(SAVE_PATH)
	return ""


## Loads a saved game. Returns false (leaving state untouched) if there is no
## usable save. Unknown ids are ignored and missing ones start at 0, so saves
## survive new mushrooms or potions being added.
func load_game() -> bool:
	var text := _read_save_text()
	if text == "":
		return false
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	reset_game()
	day = clampi(int(data.get("day", 1)), 1, NIGHTS)
	best_day = clampi(int(data.get("best_day", day)), day, NIGHTS)
	unlock_seen = int(data.get("unlock_seen", 0))
	saved_phase = str(data.get("phase", "forage"))
	for id in ingredient_order:
		inventory[id] = int(data.get("inventory", {}).get(id, 0))
	for key in bottle_keys():
		bottles[key] = int(data.get("bottles", {}).get(key, 0))
	coins = int(data.get("coins", 0))
	auto_bone = bool(data.get("auto_bone", true))
	batch = clampi(int(data.get("batch", 1)), 1, MAX_BATCH)
	bones = int(data.get("bones", 0))
	for u in data.get("upgrades", {}):
		if shop_items.has(u):
			upgrades[u] = true
	for id in data.get("discovered", {}):
		if potions.has(id):
			discovered[id] = true
	for kind in data.get("seen_creatures", {}):
		if creatures.has(kind):
			seen_creatures[kind] = true
	var snap = data.get("snapshot", {})
	if typeof(snap) == TYPE_DICTIONARY and snap.has("inventory") and snap.has("bottles"):
		_snapshot = {"inventory": {}, "bottles": {}}
		for id in ingredient_order:
			_snapshot["inventory"][id] = int(snap["inventory"].get(id, 0))
		for key in bottle_keys():
			_snapshot["bottles"][key] = int(snap["bottles"].get(key, 0))
		_snapshot["coins"] = int(snap.get("coins", coins))
		_snapshot["bones"] = int(snap.get("bones", bones))
	else:
		take_snapshot()
	return true


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _web():
		JavaScriptBridge.eval("try { localStorage.removeItem(%s); } catch (e) {}" % JSON.stringify(WEB_SAVE_KEY))


## Crash notes (browser only): every couple of seconds the game records where
## it is and how smoothly it's running. If the page dies, the next load can say
## where it happened.
func write_diag(phase: String) -> void:
	if not _web():
		return
	var note := JSON.stringify({"day": day, "phase": phase, "fps": Engine.get_frames_per_second(),
		"time": Time.get_unix_time_from_system()})
	JavaScriptBridge.eval("try { localStorage.setItem(%s, %s); } catch (e) {}" % [JSON.stringify(WEB_DIAG_KEY), JSON.stringify(note)])


## The last page event the web wrapper recorded ("graphics lost", "script
## error" or "page closed"), then cleared. Empty if none.
func take_last_event() -> Dictionary:
	if not _web():
		return {}
	var raw = JavaScriptBridge.eval("(function(){ try { var v = localStorage.getItem(%s) || ''; localStorage.removeItem(%s); return v; } catch (e) { return ''; } })()"
		% [JSON.stringify(WEB_EVENT_KEY), JSON.stringify(WEB_EVENT_KEY)])
	if typeof(raw) != TYPE_STRING or raw == "":
		return {}
	var d = JSON.parse_string(raw)
	return d if typeof(d) == TYPE_DICTIONARY else {}


## The note left by the previous session, then cleared. Empty if none.
func take_last_diag() -> Dictionary:
	if not _web():
		return {}
	var raw = JavaScriptBridge.eval("(function(){ try { var v = localStorage.getItem(%s) || ''; localStorage.removeItem(%s); return v; } catch (e) { return ''; } })()"
		% [JSON.stringify(WEB_DIAG_KEY), JSON.stringify(WEB_DIAG_KEY)])
	if typeof(raw) != TYPE_STRING or raw == "":
		return {}
	var d = JSON.parse_string(raw)
	return d if typeof(d) == TYPE_DICTIONARY else {}


## Saved at the start of each day so a lost night can be retried.
## Discovered recipes are kept on a retry: the player still knows them.
func take_snapshot() -> void:
	_snapshot = {"inventory": inventory.duplicate(), "bottles": bottles.duplicate(), "coins": coins, "bones": bones}


func restore_snapshot() -> void:
	inventory = _snapshot["inventory"].duplicate()
	bottles = _snapshot["bottles"].duplicate()
	coins = int(_snapshot.get("coins", coins))
	bones = int(_snapshot.get("bones", bones))


## Badge colour for an edibility label: green edible, amber cook first,
## brown inedible, red poisonous.
func edibility_color(label: String) -> Color:
	if label.begins_with("Poison") or label.begins_with("Deadly"):
		return Color("c8402a")
	if label.contains("cooked"):
		return Color("c88a2a")
	if label.begins_with("Inedible"):
		return Color("8a7a60")
	return Color("4f8a44")


## Every bottle stock key: each potion id, and id + "+" for its Empowered form.
func bottle_keys() -> Array:
	var keys := []
	for id in potion_order:
		keys.append(id)
		keys.append(id + "+")
	return keys


func base_id(key: String) -> String:
	return key.trim_suffix("+")


func is_empowered(key: String) -> bool:
	return key.ends_with("+")


## A potion's stats by bottle key. For an Empowered key ("spore+") the stats
## are boosted by EMPOWER and the name gets a "+".
func potion_stats(key: String) -> Dictionary:
	if not is_empowered(key):
		return potions[key]
	if not _empowered.has(key):
		var d: Dictionary = potions[base_id(key)].duplicate(true)
		for stat in ["radius", "duration", "dps", "burst"]:
			if d.has(stat):
				d[stat] = d[stat] * EMPOWER[stat]
		if d.has("ward"):
			d["ward"] = int(d["ward"]) + EMPOWER["ward"]
		if d.has("heal"):
			d["heal"] = int(d["heal"]) + EMPOWER["heal"]
		d["name"] = d["name"] + "+"
		d["color"] = Color(d["color"]).lightened(0.15)
		d["empowered"] = true
		_empowered[key] = d
	return _empowered[key]


## Whether an item's prerequisite upgrade (if any) is owned.
func can_buy_after(item: String) -> bool:
	var needs: String = shop_items[item].get("requires", "")
	return needs == "" or upgrades.has(needs)


## Buy a lab upgrade. Returns false if already owned or not enough coins.
func buy(item: String) -> bool:
	if upgrades.has(item) or coins < int(shop_items[item]["price"]) or not can_buy_after(item):
		return false
	coins -= int(shop_items[item]["price"])
	upgrades[item] = true
	# Purchases are permanent: take the price off the start-of-day snapshot
	# too, so losing the night and retrying doesn't refund it.
	if _snapshot.has("coins"):
		_snapshot["coins"] = maxi(0, int(_snapshot["coins"]) - int(shop_items[item]["price"]))
	return true


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


## How many creatures come on night n: 10 on night 1, then 50% more on each
## of the next three nights (15, 23, 34), then 2 more every night after.
func night_count(n: int) -> int:
	if n <= 4:
		return int(round(10.0 * pow(1.5, n - 1)))
	return 34 + 2 * (n - 4)


## The boss for night n (every 3rd night, taking turns), or "" for none.
func night_boss(n: int) -> String:
	if n % 3 != 0:
		return ""
	return boss_order[(n / 3 - 1) % boss_order.size()]


## Settings for night n: the count above, arriving faster and in bunches
## ("group": up to that many at once, 0.35 s apart, then a lull of 1.2-2x
## interval), a little faster and braver each night. New creature types ease in
## (2 on their first night, full share by the third). On boss nights the boss
## arrives halfway through; each time a boss returns it is tougher.
func night_config(n: int) -> Dictionary:
	var count := night_count(n)
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
	return {"interval": maxf(0.6, 1.6 - (n - 1) * 0.03), "speed": minf(80.0, 56.0 + (n - 1) * 0.6),
		"courage": 2.0 + (n - 1) * 0.08, "group": mini(6, 3 + floori((n - 1) / 5.0)), "waves": waves,
		"boss": night_boss(n), "boss_scale": 1.0 + 0.5 * floori((n - 1) / 9.0)}
