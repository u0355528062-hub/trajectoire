class_name Hotspot
extends Area3D
## Zone du corps d'un patient sur laquelle on peut appliquer un outil.

const LAYER := 3

var spot_id := ""
var character: Character
var active := false:
	set(v):
		active = v
		collision_layer = (1 << (LAYER - 1)) if v else 0


func _init() -> void:
	collision_mask = 0
	monitoring = false
	monitorable = true
	collision_layer = 0


func display_name() -> String:
	return ExamDB.SPOTS.get(spot_id, {}).get("name", spot_id)


## Crée toutes les zones d'examen sur un personnage, ainsi qu'un volume de
## collision pour le corps (le joueur ne le traverse pas, et il masque les
## zones situées de l'autre côté).
static func attach_all(c: Character) -> Array[Hotspot]:
	var out: Array[Hotspot] = []
	var sk := c.skeleton
	var attachments := {}
	for id in ExamDB.SPOTS.keys():
		var d: Dictionary = ExamDB.SPOTS[id]
		var bone: String = d["bone"]
		var bi := sk.find_bone(bone)
		if bi < 0:
			continue
		var att: BoneAttachment3D = attachments.get(bone)
		if att == null:
			att = BoneAttachment3D.new()
			att.bone_name = bone
			att.name = "Att_" + bone.replace(" ", "_")
			sk.add_child(att)
			attachments[bone] = att
		var rest_basis := sk.get_bone_global_rest(bi).basis
		var off_model := Vector3.ZERO
		var o = d["offset"]
		if o is Vector3:
			off_model = o
		else:
			# Milieu ou extrémité de l'os (vers l'os enfant).
			var child := -1
			for ci in sk.get_bone_count():
				if sk.get_bone_parent(ci) == bi:
					child = ci
					if "Finger2" in sk.get_bone_name(ci):
						break
			if child >= 0:
				var a := sk.get_bone_global_rest(bi).origin
				var b := sk.get_bone_global_rest(child).origin
				off_model = (b - a) * (0.5 if o == "mid" else 1.25)
		var h := Hotspot.new()
		h.spot_id = id
		h.character = c
		h.name = "Spot_" + id
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = d["r"]
		cs.shape = sh
		h.add_child(cs)
		h.position = rest_basis.inverse() * off_model
		att.add_child(h)
		out.append(h)

	# Volume du tronc.
	var spine := sk.find_bone("Bip01 Spine1")
	if spine >= 0:
		var att2: BoneAttachment3D = attachments.get("Bip01 Spine1")
		if att2 == null:
			att2 = BoneAttachment3D.new()
			att2.bone_name = "Bip01 Spine1"
			sk.add_child(att2)
		var body := StaticBody3D.new()
		body.name = "TorsoBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs2 := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.15
		cap.height = 0.62
		cs2.shape = cap
		body.add_child(cs2)
		var rb := sk.get_bone_global_rest(spine).basis
		body.transform = Transform3D(rb.inverse(), rb.inverse() * Vector3(0, 0.02, -0.01))
		att2.add_child(body)
	return out
