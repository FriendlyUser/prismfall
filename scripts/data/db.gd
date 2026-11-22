class_name DB
extends RefCounted
## Data-driven content: sectors (levels), enemies, bosses, upgrades and the armory shop.
## Add content by adding entries here - gameplay code reads everything from these tables.

# Bullet colour indices (see Art.BULLET_COLORS):
# 0 pink, 1 orange, 2 violet, 3 cyan, 4 yellow, 5 green, 6 red, 7 white

const ENEMIES := {
	"drone": {"name": "Drone", "hp": 16.0, "speed": 105.0, "radius": 15.0, "color": Color(1.0, 0.25, 0.75), "xp": 1, "shape": "diamond", "score": 10},
	"mite": {"name": "Mite", "hp": 6.0, "speed": 190.0, "radius": 10.0, "color": Color(1.0, 0.6, 0.15), "xp": 1, "shape": "arrow", "score": 5},
	"spitter": {"name": "Spitter", "hp": 32.0, "speed": 80.0, "radius": 17.0, "color": Color(0.7, 0.4, 1.0), "xp": 3, "shape": "hex", "score": 25, "fire": 2.1},
	"bloom": {"name": "Bloom", "hp": 24.0, "speed": 120.0, "radius": 15.0, "color": Color(1.0, 0.9, 0.25), "xp": 2, "shape": "star", "score": 20},
	"spinner": {"name": "Spinner", "hp": 110.0, "speed": 42.0, "radius": 22.0, "color": Color(1.0, 0.28, 0.28), "xp": 6, "shape": "shuriken", "score": 60, "spin": 1.7},
}

const LEVELS := [
	{
		"name": "COBALT DRIFT", "sector": "SECTOR I",
		"desc": "Drones and spitters patrol the blue void. The Warden waits at its heart.",
		"duration": 120.0, "boss": "warden",
		"bg_a": Color(0.01, 0.02, 0.08), "bg_b": Color(0.05, 0.08, 0.30), "bg_c": Color(0.0, 0.35, 0.6), "grid": Color(0.2, 0.55, 1.0),
		"planet": Vector3(-470.0, -250.0, 230.0), "planet_col": Color(0.2, 0.35, 0.9), "planet_rim": Color(0.4, 0.9, 1.0), "rings": 0.0,
		"hp_mult": 1.0, "bullet_speed": 1.0, "music_pitch": 1.0, "spitter_shots": 3, "bloom_burst": 10, "spinner_arms": 3,
		"waves": [
			{"kind": "drone", "from": 0.0, "every": 1.5, "count": 2},
			{"kind": "mite", "from": 10.0, "every": 7.0, "count": 7, "cluster": true},
			{"kind": "spitter", "from": 18.0, "every": 4.0, "count": 1},
			{"kind": "bloom", "from": 40.0, "every": 5.0, "count": 2},
			{"kind": "spinner", "from": 80.0, "every": 18.0, "count": 1},
		],
		"events": [
			{"t": 35.0, "kind": "mite", "ring": 20},
			{"t": 70.0, "kind": "drone", "ring": 18},
			{"t": 100.0, "kind": "bloom", "ring": 12},
		],
	},
	{
		"name": "CRIMSON NEBULA", "sector": "SECTOR II",
		"desc": "A burning cloud of turrets and swarms. Faster bullets, no mercy. Home of the Hydra Core.",
		"duration": 150.0, "boss": "hydra",
		"bg_a": Color(0.06, 0.0, 0.03), "bg_b": Color(0.32, 0.03, 0.1), "bg_c": Color(0.75, 0.25, 0.05), "grid": Color(1.0, 0.3, 0.35),
		"planet": Vector3(520.0, 230.0, 300.0), "planet_col": Color(0.85, 0.3, 0.12), "planet_rim": Color(1.0, 0.65, 0.3), "rings": 1.0,
		"hp_mult": 1.7, "bullet_speed": 1.12, "music_pitch": 1.06, "spitter_shots": 5, "bloom_burst": 14, "spinner_arms": 4,
		"waves": [
			{"kind": "drone", "from": 0.0, "every": 1.2, "count": 3},
			{"kind": "mite", "from": 5.0, "every": 6.0, "count": 10, "cluster": true},
			{"kind": "spitter", "from": 8.0, "every": 3.0, "count": 1},
			{"kind": "bloom", "from": 22.0, "every": 4.0, "count": 2},
			{"kind": "spinner", "from": 35.0, "every": 11.0, "count": 1},
		],
		"events": [
			{"t": 30.0, "kind": "mite", "ring": 28},
			{"t": 60.0, "kind": "spitter", "ring": 8},
			{"t": 95.0, "kind": "bloom", "ring": 16},
			{"t": 128.0, "kind": "drone", "ring": 30},
		],
	},
	{
		"name": "VOID BLOOM", "sector": "SECTOR III",
		"desc": "The edge of the signal. Bullet curtains bloom like flowers. The Seraph sings here.",
		"duration": 165.0, "boss": "seraph",
		"bg_a": Color(0.02, 0.0, 0.06), "bg_b": Color(0.2, 0.03, 0.32), "bg_c": Color(0.05, 0.55, 0.4), "grid": Color(0.65, 0.35, 1.0),
		"planet": Vector3(-430.0, 260.0, 210.0), "planet_col": Color(0.45, 0.2, 0.75), "planet_rim": Color(0.4, 1.0, 0.8), "rings": 1.0,
		"hp_mult": 2.6, "bullet_speed": 1.22, "music_pitch": 1.12, "spitter_shots": 5, "bloom_burst": 18, "spinner_arms": 4,
		"waves": [
			{"kind": "drone", "from": 0.0, "every": 1.0, "count": 3},
			{"kind": "mite", "from": 0.0, "every": 5.0, "count": 12, "cluster": true},
			{"kind": "spitter", "from": 5.0, "every": 2.4, "count": 1},
			{"kind": "bloom", "from": 12.0, "every": 3.2, "count": 2},
			{"kind": "spinner", "from": 15.0, "every": 10.0, "count": 1},
		],
		"events": [
			{"t": 25.0, "kind": "bloom", "ring": 14},
			{"t": 55.0, "kind": "mite", "ring": 36},
			{"t": 85.0, "kind": "spitter", "ring": 10},
			{"t": 115.0, "kind": "spinner", "ring": 4},
			{"t": 145.0, "kind": "drone", "ring": 36},
		],
	},
]

# Boss pattern types: spiral, ring, fan, stream, flower, rain, layers, summon.
# Optional keys: delay, spin, accel, curve, alt (alternate curve sign), cycle [on, off].
const BOSSES := {
	"warden": {
		"name": "THE WARDEN", "title": "Sentinel of the Cobalt Drift", "hp": 9000.0, "radius": 50.0,
		"color": Color(0.3, 0.85, 1.0), "color2": Color(1.0, 0.35, 0.8), "points": 6, "spin": 0.6, "xp": 0, "score": 5000,
		"phases": [
			{"at": 1.0, "patterns": [
				{"type": "spiral", "arms": 4, "every": 0.11, "spin": 1.3, "speed": 150.0, "size": 7.0, "color": 3},
				{"type": "fan", "n": 5, "spread": 0.7, "every": 1.5, "speed": 230.0, "size": 9.0, "color": 0, "delay": 1.0},
			]},
			{"at": 0.62, "patterns": [
				{"type": "ring", "n": 22, "every": 0.9, "speed": 140.0, "size": 8.0, "color": 2, "curve": 0.45, "alt": true},
				{"type": "stream", "every": 0.08, "speed": 330.0, "size": 5.0, "color": 1, "jitter": 0.06, "cycle": [1.1, 1.5]},
			]},
			{"at": 0.28, "patterns": [
				{"type": "spiral", "arms": 4, "every": 0.09, "spin": -1.9, "speed": 165.0, "size": 6.0, "color": 0},
				{"type": "spiral", "arms": 4, "every": 0.09, "spin": 1.9, "speed": 165.0, "size": 6.0, "color": 3},
				{"type": "fan", "n": 3, "spread": 0.3, "every": 1.2, "speed": 280.0, "size": 12.0, "color": 4},
			]},
		],
	},
	"hydra": {
		"name": "HYDRA CORE", "title": "Furnace of the Crimson Nebula", "hp": 22000.0, "radius": 56.0,
		"color": Color(1.0, 0.35, 0.2), "color2": Color(1.0, 0.85, 0.3), "points": 9, "spin": -0.5, "xp": 0, "score": 12000,
		"phases": [
			{"at": 1.0, "patterns": [
				{"type": "flower", "n": 16, "every": 1.0, "speed": 130.0, "size": 8.0, "color": 6, "curve": 0.6},
				{"type": "fan", "n": 7, "spread": 1.0, "every": 1.3, "speed": 240.0, "size": 8.0, "color": 1, "delay": 0.6},
			]},
			{"at": 0.66, "patterns": [
				{"type": "spiral", "arms": 3, "every": 0.06, "spin": 2.6, "speed": 190.0, "size": 6.0, "color": 1},
				{"type": "ring", "n": 30, "every": 1.6, "speed": 90.0, "size": 10.0, "color": 6, "accel": 45.0},
				{"type": "summon", "kind": "mite", "n": 6, "every": 6.0},
			]},
			{"at": 0.33, "patterns": [
				{"type": "rain", "n": 9, "every": 0.2, "speed": 180.0, "size": 7.0, "color": 4},
				{"type": "spiral", "arms": 6, "every": 0.13, "spin": -1.2, "speed": 150.0, "size": 7.0, "color": 6},
				{"type": "fan", "n": 9, "spread": 1.4, "every": 1.2, "speed": 260.0, "size": 8.0, "color": 1, "cycle": [3.0, 2.0]},
			]},
		],
	},
	"seraph": {
		"name": "SERAPH", "title": "The Song at the Edge of the Void", "hp": 36000.0, "radius": 60.0,
		"color": Color(0.75, 0.45, 1.0), "color2": Color(0.3, 1.0, 0.7), "points": 12, "spin": 0.35, "xp": 0, "score": 25000,
		"phases": [
			{"at": 1.0, "patterns": [
				{"type": "flower", "n": 20, "every": 0.95, "speed": 125.0, "size": 8.0, "color": 2, "curve": 0.8},
				{"type": "stream", "every": 0.07, "speed": 360.0, "size": 5.0, "color": 5, "jitter": 0.04, "cycle": [1.0, 1.6]},
			]},
			{"at": 0.75, "patterns": [
				{"type": "spiral", "arms": 7, "every": 0.15, "spin": 0.9, "speed": 140.0, "size": 7.0, "color": 5},
				{"type": "spiral", "arms": 7, "every": 0.15, "spin": -0.9, "speed": 140.0, "size": 7.0, "color": 2},
				{"type": "summon", "kind": "bloom", "n": 3, "every": 7.0},
			]},
			{"at": 0.5, "patterns": [
				{"type": "layers", "n": 22, "layers": 3, "every": 1.5, "speed": 100.0, "step": 40.0, "size": 8.0, "color": 4},
				{"type": "fan", "n": 5, "spread": 0.5, "every": 0.55, "speed": 300.0, "size": 7.0, "color": 0, "cycle": [2.2, 1.8]},
			]},
			{"at": 0.22, "patterns": [
				{"type": "spiral", "arms": 3, "every": 0.045, "spin": 3.1, "speed": 210.0, "size": 6.0, "color": 7},
				{"type": "flower", "n": 12, "every": 1.2, "speed": 120.0, "size": 10.0, "color": 2, "curve": 1.0},
				{"type": "summon", "kind": "spinner", "n": 1, "every": 9.0},
			]},
		],
	},
}

const UPGRADES := [
	{"id": "split", "name": "PRISM SPLIT", "desc": "+1 prism bolt per volley.", "max": 5, "color": Color(0.35, 0.9, 1.0)},
	{"id": "power", "name": "OVERCHARGE", "desc": "+25% damage for every weapon.", "max": 6, "color": Color(1.0, 0.4, 0.4)},
	{"id": "rate", "name": "RAPID CYCLE", "desc": "+18% fire rate.", "max": 5, "color": Color(1.0, 0.85, 0.3)},
	{"id": "orbit", "name": "ORBIT SHARDS", "desc": "+1 orbiting blade. Cuts enemies and ERASES bullets.", "max": 5, "color": Color(0.4, 1.0, 0.6)},
	{"id": "nova", "name": "NOVA PULSE", "desc": "Periodic shockwave that damages foes and wipes nearby bullets.", "max": 5, "color": Color(0.8, 0.5, 1.0)},
	{"id": "seeker", "name": "SEEKER SWARM", "desc": "+1 homing missile every volley.", "max": 5, "color": Color(1.0, 0.4, 0.85)},
	{"id": "pierce", "name": "PIERCING LIGHT", "desc": "Prism bolts pierce +1 enemy.", "max": 3, "color": Color(0.7, 0.95, 1.0)},
	{"id": "speed", "name": "ION THRUSTERS", "desc": "+10% move speed.", "max": 4, "color": Color(0.3, 0.7, 1.0)},
	{"id": "magnet", "name": "MAGNETAR", "desc": "+50% pickup range.", "max": 3, "color": Color(0.4, 1.0, 0.8)},
	{"id": "aegis", "name": "AEGIS CELL", "desc": "+1 max shield and fully repair shields.", "max": 3, "color": Color(0.5, 1.0, 1.0)},
	{"id": "graze", "name": "GRAZE ENGINE", "desc": "Grazing charges bombs 60% faster and yields XP.", "max": 3, "color": Color(1.0, 0.7, 0.3)},
]

const SHOP := [
	{"id": "hp", "name": "REINFORCED HULL", "desc": "+1 starting shield", "cost": [60, 140, 280]},
	{"id": "dmg", "name": "FOCUSING LENS", "desc": "+10% damage", "cost": [40, 80, 140, 220, 320]},
	{"id": "spd", "name": "VECTOR FINS", "desc": "+6% move speed", "cost": [50, 110, 200]},
	{"id": "mag", "name": "GRAVITY WELL", "desc": "+25% pickup range", "cost": [30, 70, 130]},
	{"id": "bomb", "name": "NOVA RESERVE", "desc": "+1 starting bomb", "cost": [120, 260]},
	{"id": "xp", "name": "DATA SIPHON", "desc": "+10% XP gain", "cost": [60, 130, 240]},
]


static func upgrade(id: String) -> Dictionary:
	for u: Dictionary in UPGRADES:
		if u.id == id:
			return u
	return {}


static func xp_needed(level: int) -> float:
	var l := float(level - 1)
	return 8.0 + 6.0 * l + 0.8 * l * l
