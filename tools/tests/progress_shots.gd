extends SceneTree
## Captures de l'avancement (interface visible) : écran titre, ou un chapitre de campagne joué sans pilote automatique.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 30 --resolution 1280x720 -s tools/tests/progress_shots.gd -- <dossier> <titre|n° de chapitre> <images entre deux captures> <nombre>
var frame := 0
var out_dir := "user://progress"
var mode := "titre"
var every := 120
var count := 6
var main: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out_dir = a[0]
	if a.size() > 1: mode = a[1]
	if a.size() > 2: every = int(a[2])
	if a.size() > 3: count = int(a[3])
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "titre":
		TitleScreen.force_show = true
	else:
		Campaign.new_game()
		Campaign.chapter = int(mode)
		Campaign.begin_chapter()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _process(_d: float) -> bool:
	frame += 1
	if frame % every == 0:
		var k := frame / every
		var img := root.get_texture().get_image()
		img.save_png(out_dir.path_join("%s_%02d.png" % [mode, k]))
		print("PHOTO ", mode, " ", k)
		if k >= count:
			return true
	return false
