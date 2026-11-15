class_name ModelLib
extends RefCounted
## Loads .glb models from res://assets/models/ and fits them to a size.
## Downloaded models come in any size and with any pivot, so every model is
## measured and rescaled: fit("ex_sls", 9.0) gives an SLS 9 m tall standing on y = 0.
##
## Note: Godot cannot read Draco-compressed .glb files (KHR_draco_mesh_compression).
## Decompress them first (e.g. gltf-transform) before adding them here.

const DIR := "res://assets/models/%s.glb"
static var _cache: Dictionary = {}

static func exists(model_name: String) -> bool:
	return ResourceLoader.exists(DIR % model_name)

## mode "height": target is the height. "max": target is the largest side.
## "center": largest side = target and the model is centred on the origin (planets).
static func fit(model_name: String, target: float, mode: String = "max") -> Node3D:
	if not exists(model_name):
		return null
	if not _cache.has(model_name):
		_cache[model_name] = load(DIR % model_name)
	var scene: PackedScene = _cache[model_name]
	if scene == null:
		return null
	var inst: Node3D = scene.instantiate()
	var box := aabb_of(inst, Transform3D.IDENTITY)
	if box.size == Vector3.ZERO:
		return inst
	var size: float = box.size.y if mode == "height" else maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s: float = target / maxf(size, 0.000001)
	var holder := Node3D.new()
	holder.name = model_name
	inst.scale = Vector3.ONE * s
	var c := box.get_center()
	if mode == "center":
		inst.position = -c * s
	else:
		inst.position = -Vector3(c.x, box.position.y, c.z) * s   # stand on y = 0, centred
	holder.add_child(inst)
	return holder

## Bounding box of every mesh under a node, without needing the node in the scene tree.
static func aabb_of(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = t * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var a := aabb_of(c, t)
		if a.size == Vector3.ZERO:
			continue
		out = a if first else out.merge(a)
		first = false
	return out
