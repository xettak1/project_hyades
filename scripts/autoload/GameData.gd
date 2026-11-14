extends Node
## All game numbers live here, one block per mission.
## Values are simplified game numbers, anchored to real missions where noted
## (Planet Dove, Sentinel-1, LRO, SpaceX rideshare pricing). The Data team tunes them.
## Units: mass kg, power W, energy Wh, cost $M, data GB/day, radio Mbps,
## orbit times in minutes, lifetime in years, delta-v in m/s, resolution in metres.

# Only Flood & Crop Watch is playable for now. The radar and lunar data below is kept for later.
const MISSION_ORDER := ["flood_watch"]

const MISSIONS := {
	# ------------------------------------------------------------------ EASY
	"flood_watch": {
		"name": "Flood & Crop Watch",
		"difficulty": "Easy",
		"spacecraft_class": "6U CubeSat",
		"objective": "Image a farming region to spot floods and check crop health.",
		"challenge": "DATA: a tiny radio struggles to send all your images home.",
		"budget": 5.0, "mass_limit": 8.0, "base_mass": 1.5, "base_cost": 0.2,
		"ops_cost_per_year": 0.3,
		"orbits": ["leo_550", "sso_550"],
		"rockets": ["rideshare_leo", "rideshare_sso"],
		"requirements": {"max_revisit_days": 3, "min_data_delivered": 2.0, "min_lifetime": 2, "max_resolution_m": 10.0},
		"req_text": ["See the farm region at least every %d days", "Deliver %.1f GB of useful images to Earth per day", "Keep working for at least %d years", "Image detail of %.0f m or better"],
		"comparison": {"name": "Planet Dove CubeSats",
			"text": "Planet's Doves are ~5 kg 3U CubeSats that image Earth's land at 3-5 m resolution. Their biggest problem was yours: getting the images down, so Planet built its own fast X-band radio."},
		"env": {"title": "CUBESAT INTEGRATION LAB", "room": Vector3(20, 6, 18),
			"wall": Color(0.85, 0.87, 0.9), "floor": Color(0.55, 0.57, 0.6), "accent": Color(0.3, 0.65, 1.0),
			"light": Color(1, 1, 1), "sat_style": "cubesat", "sat_y": 1.3, "part_scale": 1.0,
			"table": Color(0.3, 0.32, 0.36), "stripes": false,
			"orbit_model": "sc_cubesat",
			# Exhibits: [model, x, z, height m, yaw, plaque]. z is measured from the front wall (lab) or "mc" for Mission Control.
			"exhibits": [["ex_astronaut", -6.0, 2.5, 1.8, 30.0, "Spacesuit (EMU)"],
				["ex_friendship7", 6.0, 2.5, 1.6, -30.0, "Mercury capsule Friendship 7 (1962)"],
				["ex_dsn34", 6.8, "mc", 2.6, -60.0, "Ground segment: Deep Space Network 34 m antenna"]]},
	},
	# ------------------------------------------------------------------ MEDIUM
	"radar_mapper": {
		"name": "Radar Ocean & Ice Mapper",
		"difficulty": "Medium",
		"spacecraft_class": "Small radar satellite",
		"objective": "Map sea ice and oil spills through clouds and darkness with imaging radar.",
		"challenge": "POWER: radar is hungry. Panels, battery and orbit must keep it running.",
		"budget": 180.0, "mass_limit": 550.0, "base_mass": 40.0, "base_cost": 30.0,
		"ops_cost_per_year": 4.0,
		"orbits": ["leo_500", "sso_700"],
		"rockets": ["electron", "rideshare_sso_big", "falcon9"],
		"requirements": {"max_revisit_days": 6, "min_data_delivered": 40.0, "min_lifetime": 5, "max_resolution_m": 20.0},
		"req_text": ["Map the ice region at least every %d days", "Deliver %.0f GB of useful radar data per day", "Keep working for at least %d years", "Radar detail of %.0f m or better"],
		"comparison": {"name": "ESA Sentinel-1",
			"text": "Sentinel-1 flies a C-band radar in a dawn-dusk sun-synchronous orbit at ~700 km, so its panels almost never see eclipse. Its radar draws ~3.9 kW, it stores 1,410 Gb and downlinks at 2 x 260 Mbps. It is much bigger than yours (2,300 kg)."},
		"env": {"title": "SATELLITE INTEGRATION HALL", "room": Vector3(26, 8, 22),
			"wall": Color(0.5, 0.5, 0.48), "floor": Color(0.32, 0.33, 0.35), "accent": Color(1.0, 0.6, 0.15),
			"light": Color(1.0, 0.95, 0.85), "lamp": 1.2, "sat_style": "smallsat", "sat_y": 1.7, "part_scale": 1.5,
			"table": Color(0.45, 0.35, 0.2), "stripes": true,
			"orbit_model": "sc_landsat8",
			"exhibits": [["ex_ares1", -8.5, 2.8, 7.0, 0.0, "Ares I rocket (scale model)"],
				["ex_acrimsat", 8.5, 2.8, 1.6, -30.0, "AcrimSAT: a small Sun-watching satellite"],
				["ex_dsn_antenna", 8.0, "mc", 3.0, -60.0, "Ground segment: ground station antenna"],
				["ex_tdrs", -8.0, "mc", 2.2, 40.0, "TDRS relay satellite: talks to other spacecraft"]]},
	},
	# ------------------------------------------------------------------ HARD
	"lunar_mapper": {
		"name": "Lunar Mapper",
		"difficulty": "Hard",
		"spacecraft_class": "Lunar orbiter",
		"objective": "Map the Moon in high detail from a low polar orbit to find safe landing sites.",
		"challenge": "FUEL: braking into lunar orbit eats propellant. Mass, tanks and trajectory decide how long you last.",
		"budget": 600.0, "mass_limit": 2000.0, "base_mass": 500.0, "base_cost": 250.0,
		"ops_cost_per_year": 20.0,
		"orbits": ["lunar_direct", "lunar_low_energy"],
		"rockets": ["falcon9_tli", "heavy_tli"],
		"requirements": {"max_revisit_days": 30, "min_data_delivered": 50.0, "min_lifetime": 1, "max_resolution_m": 2.0},
		"req_text": ["Map the whole Moon within %d days", "Deliver %.0f GB of useful images per day", "Work in lunar orbit for at least %d year(s)", "Image detail of %.1f m or better"],
		"comparison": {"name": "NASA Lunar Reconnaissance Orbiter (LRO)",
			"text": "LRO launched at 1,916 kg with a dry mass of 1,018 kg: almost half was fuel. It mapped from a 50 km polar orbit, where its narrow-angle cameras see 0.5 m details."},
		"env": {"title": "DEEP SPACE MISSION HANGAR", "room": Vector3(28, 10, 24),
			"wall": Color(0.12, 0.14, 0.22), "floor": Color(0.1, 0.11, 0.15), "accent": Color(0.75, 0.6, 1.0),
			"light": Color(0.8, 0.85, 1.0), "lamp": 1.6, "sat_style": "orbiter", "sat_y": 2.2, "part_scale": 1.6,
			"table": Color(0.2, 0.22, 0.3), "stripes": false,
			"orbit_model": "sc_mro",
			"exhibits": [["ex_sls", -9.0, 3.0, 9.0, 0.0, "Space Launch System: the Artemis Moon rocket"],
				["ex_pioneer10", 9.5, 3.0, 2.6, -30.0, "Pioneer 10: first probe to Jupiter (1972)"],
				["ex_dsn70", 9.0, "mc", 3.6, -60.0, "Ground segment: Deep Space Network 70 m dish"]]},
	},
}

# ---------------------------------------------------------------------- PARTS
# One dictionary per mission: category -> part id -> stats.
# "model" picks the 3D model in PartModels (defaults to the part id).
const PARTS := {
	"flood_watch": {
		"payload": {
			"cam_basic": {"name": "Multispectral camera", "tier": "simple", "mass": 1.0, "power": 4.0, "cost": 0.5, "data": 3.0, "resolution": 10.0,
				"tooltip": "Colour and near-infrared images at 10 m: enough to see floodwater and healthy crops."},
			"cam_hd": {"name": "High-resolution camera", "tier": "advanced", "mass": 1.8, "power": 7.0, "cost": 1.2, "data": 8.0, "resolution": 3.0,
				"tooltip": "3 m detail shows individual fields, but every picture is a much bigger file to send home."},
		},
		"solar": {
			"solar_body": {"name": "Body-mounted panels (10 W)", "tier": "simple", "mass": 0.5, "power_gen": 10.0, "cost": 0.1,
				"tooltip": "Solar cells fixed to the outside of the CubeSat. Light and cheap, but small."},
			"solar_deploy": {"name": "Deployable wings (30 W)", "tier": "advanced", "mass": 1.2, "power_gen": 30.0, "cost": 0.4,
				"tooltip": "Panels that unfold in space: three times the power for more mass and cost."},
		},
		"battery": {
			"bat_10": {"name": "10 Wh battery", "tier": "simple", "mass": 0.2, "energy": 10.0, "cost": 0.05,
				"tooltip": "Keeps the spacecraft running while Earth blocks the Sun (eclipse)."},
			"bat_30": {"name": "30 Wh battery", "tier": "advanced", "mass": 0.4, "energy": 30.0, "cost": 0.1,
				"tooltip": "Three times the energy: survives long eclipses and solar storms better."},
		},
		"comms": {
			"radio_uhf": {"name": "UHF radio (0.01 Mbps)", "tier": "simple", "mass": 0.2, "power": 1.0, "cost": 0.05, "mbps": 0.0096,
				"tooltip": "Simple and reliable, but far too slow for images."},
			"radio_s": {"name": "S-band radio (2 Mbps)", "tier": "simple", "mass": 0.5, "power": 3.0, "cost": 0.3, "mbps": 2.0,
				"tooltip": "A common CubeSat radio. Sends well under 1 GB per day."},
			"radio_x": {"name": "X-band radio (20 Mbps)", "tier": "advanced", "mass": 0.8, "power": 6.0, "cost": 0.7, "mbps": 20.0,
				"tooltip": "High-speed radio built for imaging missions. Uses a lot of power while transmitting."},
		},
		"computer": {
			"obc_std": {"name": "Computer, 32 GB storage", "tier": "simple", "mass": 0.2, "power": 1.0, "cost": 0.1, "storage": 32.0,
				"tooltip": "Runs the spacecraft and stores images until the next ground station pass."},
			"obc_big": {"name": "Computer, 128 GB storage", "tier": "advanced", "mass": 0.3, "power": 2.0, "cost": 0.2, "storage": 128.0,
				"tooltip": "More storage means fewer images lost when the radio falls behind."},
		},
		"adcs": {
			"adcs_basic": {"name": "Basic pointing", "tier": "simple", "mass": 0.6, "power": 1.0, "cost": 0.2, "pointing": 0.7, "revisit_bonus": 0,
				"tooltip": "Magnetic torquers keep it roughly pointed at Earth. About 30% of images miss or blur."},
			"adcs_precise": {"name": "Precise pointing", "tier": "advanced", "mass": 1.2, "power": 3.0, "cost": 0.6, "pointing": 1.0, "revisit_bonus": 1,
				"tooltip": "Reaction wheels + star tracker. Every image is sharp, and it can tilt sideways to revisit a day sooner."},
		},
		"propulsion": {
			"prop_none": {"name": "No propulsion", "tier": "simple", "mass": 0.0, "power": 0.0, "cost": 0.0, "life_bonus": 0,
				"tooltip": "Lighter and cheaper, but air drag slowly pulls the CubeSat down."},
			"prop_small": {"name": "Small thruster", "tier": "advanced", "mass": 1.0, "power": 1.0, "cost": 0.3, "life_bonus": 2,
				"tooltip": "Small pushes keep the orbit from decaying, adding about 2 years of life."},
		},
	},
	"radar_mapper": {
		"payload": {
			"sar_small": {"name": "Compact X-band radar", "tier": "simple", "model": "sar_small", "mass": 120.0, "power": 300.0, "cost": 25.0, "data": 60.0, "resolution": 10.0, "revisit_bonus": 0,
				"tooltip": "A 3 m radar antenna. Sees through clouds and at night with 10 m detail. Average 300 W (much more while imaging)."},
			"sar_large": {"name": "Wide-swath C-band radar", "tier": "advanced", "model": "sar_large", "mass": 230.0, "power": 650.0, "cost": 60.0, "data": 150.0, "resolution": 5.0, "revisit_bonus": 6,
				"tooltip": "A 5 m radar antenna with a wide swath: covers the region twice as often, but needs over twice the power."},
		},
		"solar": {
			"rsolar_fixed": {"name": "Fixed panels (800 W)", "tier": "simple", "model": "solar_body", "mass": 50.0, "power_gen": 800.0, "cost": 8.0,
				"tooltip": "Panels fixed to the body. They only point at the Sun some of the time."},
			"rsolar_wing": {"name": "Sun-tracking wing (2 kW)", "tier": "advanced", "model": "solar_deploy", "mass": 110.0, "power_gen": 2000.0, "cost": 22.0,
				"tooltip": "A deployable wing that rotates to face the Sun: much more power."},
		},
		"battery": {
			"rbat_1k": {"name": "1 kWh battery", "tier": "simple", "model": "bat_10", "mass": 10.0, "energy": 1000.0, "cost": 1.0,
				"tooltip": "Enough for short eclipses."},
			"rbat_4k": {"name": "4 kWh battery", "tier": "advanced", "model": "bat_30", "mass": 35.0, "energy": 4000.0, "cost": 3.0,
				"tooltip": "Keeps a power-hungry radar alive through long eclipses."},
		},
		"comms": {
			"rradio_s": {"name": "S-band radio (2 Mbps)", "tier": "simple", "model": "radio_s", "mass": 5.0, "power": 20.0, "cost": 2.0, "mbps": 2.0,
				"tooltip": "Fine for commands and health data. Hopeless for radar images."},
			"rradio_x": {"name": "X-band radio (150 Mbps)", "tier": "simple", "model": "radio_x", "mass": 12.0, "power": 60.0, "cost": 8.0, "mbps": 150.0,
				"tooltip": "The standard Earth-observation downlink."},
			"rradio_ka": {"name": "Ka-band radio (500 Mbps)", "tier": "advanced", "model": "dish_big", "mass": 20.0, "power": 110.0, "cost": 15.0, "mbps": 500.0,
				"tooltip": "Very fast, but needs precise pointing and more power."},
		},
		"computer": {
			"robc_256": {"name": "Data unit, 256 GB", "tier": "simple", "model": "obc_std", "mass": 15.0, "power": 40.0, "cost": 2.0, "storage": 256.0,
				"tooltip": "Stores radar data between ground passes."},
			"robc_2t": {"name": "Data unit, 2 TB", "tier": "advanced", "model": "obc_big", "mass": 25.0, "power": 60.0, "cost": 5.0, "storage": 2000.0,
				"tooltip": "Holds days of radar data, so outages lose nothing."},
		},
		"adcs": {
			"radcs_std": {"name": "Standard attitude control", "tier": "simple", "model": "adcs_basic", "mass": 25.0, "power": 60.0, "cost": 6.0, "pointing": 0.85, "revisit_bonus": 0,
				"tooltip": "Good enough for most images; some scenes are blurred."},
			"radcs_precise": {"name": "Precise attitude control", "tier": "advanced", "model": "adcs_precise", "mass": 45.0, "power": 90.0, "cost": 15.0, "pointing": 1.0, "revisit_bonus": 0,
				"tooltip": "Big reaction wheels and star trackers: every radar scene is usable."},
		},
		"propulsion": {
			"rprop_small": {"name": "Hydrazine kit, 30 kg", "tier": "simple", "model": "prop_small", "mass": 30.0, "power": 10.0, "cost": 5.0, "life_bonus": 2,
				"tooltip": "Fuel to fight drag and keep the orbit: about 2 extra years."},
			"rprop_large": {"name": "Hydrazine kit, 80 kg", "tier": "advanced", "model": "tank_s", "mass": 80.0, "power": 10.0, "cost": 10.0, "life_bonus": 6,
				"tooltip": "Enough fuel for a long mission: about 6 extra years."},
		},
	},
	"lunar_mapper": {
		"payload": {
			"wac": {"name": "Wide-angle camera", "tier": "simple", "model": "cam_basic", "mass": 2.0, "power": 5.0, "cost": 8.0, "data": 20.0, "resolution": 100.0,
				"tooltip": "Maps the whole Moon in colour at 100 m per pixel. Too coarse to judge landing sites."},
			"nac": {"name": "Narrow-angle camera pair", "tier": "advanced", "model": "telescope", "mass": 20.0, "power": 15.0, "cost": 40.0, "data": 250.0, "resolution": 0.5,
				"tooltip": "Two telescopes that see 0.5 m details (like LRO's LROC NAC), producing huge amounts of data."},
		},
		"solar": {
			"lsolar_1": {"name": "Single solar wing (800 W)", "tier": "simple", "model": "solar_body", "mass": 40.0, "power_gen": 800.0, "cost": 10.0,
				"tooltip": "One wing. Light, but a big orbiter is power hungry."},
			"lsolar_2": {"name": "Twin solar wings (1.8 kW)", "tier": "advanced", "model": "solar_deploy", "mass": 75.0, "power_gen": 1800.0, "cost": 20.0,
				"tooltip": "Two wings, like LRO's array."},
		},
		"battery": {
			"lbat_1": {"name": "1.2 kWh battery", "tier": "simple", "model": "bat_10", "mass": 15.0, "energy": 1200.0, "cost": 2.0,
				"tooltip": "The Moon blocks the Sun for up to ~48 minutes of each 2-hour orbit."},
			"lbat_3": {"name": "3 kWh battery", "tier": "advanced", "model": "bat_30", "mass": 30.0, "energy": 3000.0, "cost": 4.0,
				"tooltip": "Comfortable margin for lunar eclipses."},
		},
		"comms": {
			"lradio_x": {"name": "X-band low-gain antenna (2 Mbps)", "tier": "simple", "model": "radio_s", "mass": 5.0, "power": 40.0, "cost": 5.0, "mbps": 2.0,
				"tooltip": "384,000 km is far: a small antenna only manages a trickle of data."},
			"lradio_ka": {"name": "Ka-band high-gain dish (100 Mbps)", "tier": "advanced", "model": "dish_big", "mass": 35.0, "power": 120.0, "cost": 25.0, "mbps": 100.0,
				"tooltip": "A big steerable dish, like LRO's 100 Mbps Ka-band link."},
		},
		"computer": {
			"lobc_100": {"name": "Recorder, 100 GB", "tier": "simple", "model": "obc_std", "mass": 5.0, "power": 30.0, "cost": 3.0, "storage": 100.0,
				"tooltip": "Stores images while the Moon hides you from Earth."},
			"lobc_1t": {"name": "Recorder, 1 TB", "tier": "advanced", "model": "obc_big", "mass": 8.0, "power": 40.0, "cost": 6.0, "storage": 1000.0,
				"tooltip": "Big buffer for a data-heavy camera."},
		},
		"adcs": {
			"ladcs_std": {"name": "Standard attitude control", "tier": "simple", "model": "adcs_basic", "mass": 20.0, "power": 50.0, "cost": 8.0, "pointing": 0.85, "revisit_bonus": 0,
				"tooltip": "Some high-detail images smear."},
			"ladcs_precise": {"name": "Precise attitude control", "tier": "advanced", "model": "adcs_precise", "mass": 40.0, "power": 80.0, "cost": 18.0, "pointing": 1.0, "revisit_bonus": 0,
				"tooltip": "Star trackers and big wheels for sharp 0.5 m images."},
		},
		"propulsion": {
			"tank_small": {"name": "Fuel tank, 400 kg hydrazine", "tier": "simple", "model": "tank_s", "mass": 60.0, "power": 20.0, "cost": 20.0, "fuel": 400.0, "isp": 220.0,
				"tooltip": "Propellant to brake into lunar orbit and to keep the orbit from decaying."},
			"tank_large": {"name": "Fuel tank, 900 kg hydrazine", "tier": "advanced", "model": "tank_l", "mass": 90.0, "power": 20.0, "cost": 30.0, "fuel": 900.0, "isp": 220.0,
				"tooltip": "More fuel = longer life, but a much heavier spacecraft at launch."},
		},
	},
}

# ---------------------------------------------------------------------- ORBITS
# eclipse_min and contact_min_per_day should come from GMAT runs (Data tasks).
const ORBITS := {
	"leo_550": {"name": "Low Earth orbit 550 km (51.6 deg)", "body": "earth", "altitude_km": 550.0, "inclination": 51.6,
		"period_min": 95.6, "eclipse_min": 36.0, "contact_min_per_day": 30.0, "revisit_days": 5, "life_years": 4,
		"tooltip": "A common CubeSat orbit. It doesn't fly over every region often, and ground passes are short."},
	"sso_550": {"name": "Sun-synchronous orbit 550 km", "body": "earth", "altitude_km": 550.0, "inclination": 97.6,
		"period_min": 95.6, "eclipse_min": 35.0, "contact_min_per_day": 50.0, "revisit_days": 3, "life_years": 4,
		"tooltip": "Crosses each place at the same local time, so lighting matches between images. Polar ground stations see it often."},
	"leo_500": {"name": "Low Earth orbit 500 km (45 deg)", "body": "earth", "altitude_km": 500.0, "inclination": 45.0,
		"period_min": 94.6, "eclipse_min": 36.0, "contact_min_per_day": 40.0, "revisit_days": 8, "life_years": 3,
		"tooltip": "Cheap to reach, but a third of every orbit is in Earth's shadow and drag is strong."},
	"sso_700": {"name": "Dawn-dusk sun-synchronous 700 km", "body": "earth", "altitude_km": 700.0, "inclination": 98.2,
		"period_min": 98.7, "eclipse_min": 3.0, "contact_min_per_day": 60.0, "revisit_days": 12, "life_years": 10,
		"tooltip": "Rides the line between day and night, so the panels almost never see eclipse (like Sentinel-1)."},
	"lunar_direct": {"name": "Direct transfer, 50 km polar lunar orbit", "body": "moon", "altitude_km": 50.0, "inclination": 90.0,
		"period_min": 113.0, "eclipse_min": 48.0, "contact_min_per_day": 480.0, "revisit_days": 28, "life_years": 6,
		"transfer_days": 5, "delta_v_insert": 850.0, "delta_v_per_year": 150.0,
		"tooltip": "Fast 5-day trip like LRO, but braking into lunar orbit costs ~850 m/s of fuel."},
	"lunar_low_energy": {"name": "Low-energy transfer, 50 km polar lunar orbit", "body": "moon", "altitude_km": 50.0, "inclination": 90.0,
		"period_min": 113.0, "eclipse_min": 48.0, "contact_min_per_day": 480.0, "revisit_days": 28, "life_years": 6,
		"transfer_days": 100, "delta_v_insert": 650.0, "delta_v_per_year": 150.0,
		"tooltip": "A slow ~100-day path using the Sun's gravity. Saves ~200 m/s of braking fuel, but adds months of operations cost."},
}

# ---------------------------------------------------------------------- ROCKETS
# cost = base cost + (mass above included_kg) x per_kg. Big launchers are game values.
const ROCKETS := {
	"rideshare_leo": {"name": "Rideshare to 51.6 deg LEO", "cost": 0.3, "included_kg": 12.0, "per_kg": 0.0,
		"capacity": {"leo_550": 12.0},
		"tooltip": "Share a rocket with other satellites. Cheap, but you go where the main passenger goes."},
	"rideshare_sso": {"name": "Rideshare to sun-synchronous orbit", "cost": 0.35, "included_kg": 50.0, "per_kg": 0.007,
		"capacity": {"sso_550": 50.0},
		"tooltip": "Real SpaceX rideshare price: about $350,000 for up to 50 kg to sun-synchronous orbit."},
	"electron": {"name": "Small launcher (Electron class)", "cost": 7.5, "included_kg": 300.0, "per_kg": 0.0,
		"capacity": {"leo_500": 300.0, "sso_700": 200.0},
		"tooltip": "A dedicated small rocket, about $7.5M: 300 kg to LEO or 200 kg to sun-synchronous orbit."},
	"rideshare_sso_big": {"name": "Rideshare to SSO (large slot)", "cost": 0.35, "included_kg": 50.0, "per_kg": 0.007,
		"capacity": {"sso_700": 800.0},
		"tooltip": "$350,000 for the first 50 kg, then $7,000 per extra kg. You go when the rideshare goes."},
	"falcon9": {"name": "Dedicated medium launcher (Falcon 9 class)", "cost": 70.0, "included_kg": 10000.0, "per_kg": 0.0,
		"capacity": {"leo_500": 10000.0, "sso_700": 7000.0},
		"tooltip": "A whole rocket to yourself, about $70M. Any orbit you like, at a price."},
	"falcon9_tli": {"name": "Medium launcher to the Moon (Falcon 9 class)", "cost": 70.0, "included_kg": 1700.0, "per_kg": 0.0,
		"capacity": {"lunar_direct": 1700.0, "lunar_low_energy": 1700.0},
		"tooltip": "Sends up to about 1,700 kg on a path to the Moon (game value)."},
	"heavy_tli": {"name": "Heavy launcher to the Moon (Falcon Heavy class)", "cost": 97.0, "included_kg": 5000.0, "per_kg": 0.0,
		"capacity": {"lunar_direct": 5000.0, "lunar_low_energy": 5000.0},
		"tooltip": "About $97M. Lifts far more mass toward the Moon (game value)."},
}

# Game settings (Data task DA-13 tunes these).
const USABLE_BATTERY_FRACTION := 0.6
const G0 := 9.81
const SCORE_WEIGHTS := {"requirements": 350, "data": 300, "efficiency": 200, "survival": 150}

func mission(id: String) -> Dictionary:
	return MISSIONS.get(id, {})

func parts_for(mission_id: String) -> Dictionary:
	return PARTS.get(mission_id, {})

func categories(mission_id: String) -> Array:
	return parts_for(mission_id).keys()

func part(category: String, id: String, mission_id: String = "") -> Dictionary:
	if mission_id == "":
		mission_id = MissionState.mission_id
	return parts_for(mission_id).get(category, {}).get(id, {})
