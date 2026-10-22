extends SceneTree

func _init() -> void:
	print("Starting Dark Gothic Texture Generation...")
	var dir := DirAccess.open("res://assets")
	if not dir.dir_exists("textures"):
		dir.make_dir("textures")

	_gen_stone_flagstones()
	_gen_village_cobble()
	_gen_primeval_moss_dirt()
	_gen_spider_chitin_rocks()
	_gen_burnt_wood_ash()
	_gen_citadel_marble()
	_gen_hero_chainmail()
	_gen_rogue_leather()
	_gen_mage_cloth()
	_gen_zombie_flesh()
	_gen_skeleton_bone()
	_gen_foliage_bush()

	print("All 12 textures generated successfully!")
	quit(0)

func _gen_stone_flagstones() -> void:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.04

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y) * 0.15
			var is_mortar := (x % 64 < 3) or (y % 64 < 3)
			var col: Color
			if is_mortar:
				col = Color(0.08, 0.09, 0.10, 1.0)
			else:
				var brick_var := sin(floor(x / 64.0) * 17.0 + floor(y / 64.0) * 31.0) * 0.05
				var v := clampf(0.22 + n + brick_var, 0.12, 0.45)
				col = Color(v * 0.95, v, v * 1.05, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_stone_flagstones.png")

func _gen_village_cobble() -> void:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 2048
	noise.frequency = 0.06

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y) * 0.18
			var cx := (x % 32) - 16
			var cy := (y % 32) - 16
			var dist := sqrt(cx * cx + cy * cy)
			var col: Color
			if dist > 14.5:
				# Mossy green-brown seam
				col = Color(0.12 + n * 0.5, 0.16 + n * 0.8, 0.10, 1.0)
			else:
				var v := clampf(0.30 - (dist / 16.0) * 0.08 + n, 0.16, 0.48)
				col = Color(v * 0.98, v * 0.95, v * 0.90, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_village_cobble.png")

func _gen_primeval_moss_dirt() -> void:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 999
	noise.frequency = 0.03

	for y in range(h):
		for x in range(w):
			var n1 := noise.get_noise_2d(x, y)
			var n2 := noise.get_noise_2d(x * 2.5, y * 2.5) * 0.5
			var blend := clampf(n1 + n2, -0.6, 0.6)
			var col: Color
			if blend > 0.1:
				# Lush damp emerald moss
				col = Color(0.12, 0.26 + blend * 0.25, 0.14, 1.0)
			else:
				# Peat soil & tangled roots
				col = Color(0.18 + blend * 0.1, 0.13 + blend * 0.08, 0.09, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_primeval_moss_dirt.png")

func _gen_spider_chitin_rocks() -> void:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 444
	noise.frequency = 0.08

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y)
			var is_web := (sin(x * 0.1 + y * 0.05) > 0.85) or (cos(x * 0.04 - y * 0.12) > 0.88)
			var col: Color
			if is_web:
				col = Color(0.75, 0.70, 0.85, 0.9)
			else:
				var v := clampf(0.14 + n * 0.12, 0.06, 0.30)
				# Violet-tinted cavern shale
				col = Color(v * 1.05, v * 0.85, v * 1.35, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_spider_chitin_rocks.png")

func _gen_burnt_wood_ash() -> void:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 777
	noise.frequency = 0.05

	for y in range(h):
		for x in range(w):
			var plank_seam := (x % 48 < 2)
			var n := noise.get_noise_2d(x, y)
			var col: Color
			if plank_seam:
				col = Color(0.04, 0.04, 0.04, 1.0)
			else:
				var is_ember := (n > 0.35 and (x + y) % 19 == 0)
				if is_ember:
					col = Color(0.95, 0.35, 0.05, 1.0) # Glowing ember speck
				else:
					var v := clampf(0.15 + n * 0.08, 0.07, 0.28)
					col = Color(v * 1.15, v * 0.9, v * 0.8, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_burnt_wood_ash.png")

func _gen_citadel_marble() -> void:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 888
	noise.frequency = 0.04

	for y in range(h):
		for x in range(w):
			var tile_x := int(floor(x / 64.0))
			var tile_y := int(floor(y / 64.0))
			var is_black_tile := ((tile_x + tile_y) % 2 == 0)
			var n := noise.get_noise_2d(x * 1.5, y * 1.5) * 0.08
			var is_gold_border := ((x % 64 < 2 or x % 64 > 61) or (y % 64 < 2 or y % 64 > 61))

			var col: Color
			if is_gold_border:
				col = Color(0.85, 0.70, 0.22, 1.0)
			elif is_black_tile:
				var v := clampf(0.10 + n, 0.04, 0.22)
				col = Color(v, v * 0.95, v * 1.05, 1.0)
			else:
				var v := clampf(0.38 + n, 0.25, 0.55)
				col = Color(v * 1.02, v * 0.96, v * 0.94, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_citadel_marble.png")

func _gen_hero_chainmail() -> void:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			var ring_x := (x % 16) - 8
			var ring_y := (y % 16) - 8
			var r := sqrt(ring_x * ring_x + ring_y * ring_y)
			var col: Color
			if r >= 4.5 and r <= 7.5:
				var shine := sin(float(x + y) * 0.4) * 0.2
				var v := clampf(0.65 + shine, 0.4, 0.9)
				col = Color(v, v * 1.02, v * 1.08, 1.0)
			else:
				col = Color(0.12, 0.14, 0.18, 1.0) # Dark under-padding
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_hero_chainmail.png")

func _gen_rogue_leather() -> void:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 333
	noise.frequency = 0.1

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y) * 0.06
			var is_stitch := (y % 32 == 0 and x % 8 < 5)
			var is_rivet := (x % 64 == 32 and y % 64 == 32)
			var col: Color
			if is_rivet:
				col = Color(0.85, 0.75, 0.3, 1.0)
			elif is_stitch:
				col = Color(0.72, 0.62, 0.45, 1.0)
			else:
				var v := clampf(0.18 + n, 0.12, 0.28)
				col = Color(v * 1.15, v * 0.85, v * 0.65, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_rogue_leather.png")

func _gen_mage_cloth() -> void:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 555
	noise.frequency = 0.08

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y) * 0.05
			var is_silver_border := (y < 6 or y > 249 or x < 6 or x > 249)
			var col: Color
			if is_silver_border:
				col = Color(0.85, 0.90, 1.0, 1.0)
			else:
				var v := clampf(0.24 + n, 0.15, 0.35)
				col = Color(v * 1.1, v * 0.6, v * 1.6, 1.0) # Deep mystic violet
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_mage_cloth.png")

func _gen_zombie_flesh() -> void:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 666
	noise.frequency = 0.06

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y)
			var vein := (sin(x * 0.15 + y * 0.08) > 0.88)
			var col: Color
			if vein:
				col = Color(0.35, 0.10, 0.40, 1.0) # Rotten purple vein
			elif n > 0.3:
				col = Color(0.40, 0.85, 0.20, 1.0) # Toxic pustule
			else:
				var v := clampf(0.24 + n * 0.08, 0.14, 0.38)
				col = Color(v * 0.7, v * 1.25, v * 0.6, 1.0)
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_zombie_flesh.png")

func _gen_skeleton_bone() -> void:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 111
	noise.frequency = 0.07

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y) * 0.12
			var crack := (noise.get_noise_2d(x * 4.0, y * 4.0) > 0.45)
			var col: Color
			if crack:
				col = Color(0.25, 0.22, 0.18, 1.0) # Bone crack/fissure
			else:
				var v := clampf(0.72 + n, 0.45, 0.88)
				col = Color(v, v * 0.95, v * 0.82, 1.0) # Ancient ivory bone
			img.set_pixel(x, y, col)
	img.save_png("res://assets/textures/tex_skeleton_bone.png")

func _gen_foliage_bush() -> void:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 222
	noise.frequency = 0.12

	for y in range(h):
		for x in range(w):
			var n := noise.get_noise_2d(x, y)
			var v := clampf(0.28 + n * 0.2, 0.12, 0.55)
			img.set_pixel(x, y, Color(v * 0.5, v * 1.2, v * 0.4, 1.0))
	img.save_png("res://assets/textures/tex_foliage_bush.png")
