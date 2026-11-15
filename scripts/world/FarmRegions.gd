class_name FarmRegions
extends RefCounted
## The four farming regions the mission watches (real flood-prone farmland in West and Central Africa).
## Level 2 photographs them from orbit, Level 4 analyses their plots. What is really happening on each
## plot is fixed here, so the farmland seen from orbit, from the analysis centre window and on the
## analysis screens always agree.

const REGIONS := [
	{"id": "volta", "name": "Volta Basin", "country": "Ghana", "lat": 8.0, "lon": -0.3,
		"crops": "maize, yam, rice", "risk": "Lake Volta spill-over floods"},
	{"id": "niger_delta", "name": "Niger Inland Delta", "country": "Mali", "lat": 14.5, "lon": -4.5,
		"crops": "rice, millet", "risk": "seasonal river floods"},
	{"id": "benue", "name": "Benue-Niger confluence", "country": "Nigeria", "lat": 7.8, "lon": 6.7,
		"crops": "rice, cassava, maize", "risk": "river floods"},
	{"id": "chad", "name": "Lake Chad Basin", "country": "Chad / Nigeria", "lat": 13.0, "lon": 14.5,
		"crops": "sorghum, flood-recession farms", "risk": "lake level swings"},
]
const PLOTS_PER_REGION := 6
const COLORS := {"healthy": Color("#22c55e"), "stressed": Color("#eab308"), "flooded": Color("#3b82f6"), "waterlogged": Color("#60a5fa"), "none": Color(0.35, 0.37, 0.4)}

static func region(id: String) -> Dictionary:
	for r in REGIONS:
		if r["id"] == id:
			return r
	return {}

## True state of every plot: [{id, region, state}] (24 plots, A1..D6, one letter per region).
static func truth() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2027
	var bag := ["healthy", "healthy", "healthy", "stressed", "stressed", "flooded", "waterlogged", "healthy"]
	var out: Array = []
	for ri in REGIONS.size():
		for k in PLOTS_PER_REGION:
			var st: String = bag[rng.randi() % bag.size()]
			if k == 0 and ri % 2 == 0:
				st = "flooded"   # every other region has at least one flooded plot
			out.append({"id": "%s%d" % [char(65 + ri), k + 1], "region": REGIONS[ri]["id"], "state": st})
	return out

static func is_flood(state: String) -> bool:
	return state == "flooded" or state == "waterlogged"

## Chance of thick cloud over a region on a given pass (seeded, so it is the same every game).
static func cloud_cover(region_index: int, pass_no: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (region_index + 1) + 104729 * (pass_no + 1)
	return rng.randf()
