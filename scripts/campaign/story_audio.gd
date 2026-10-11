class_name StoryAudio
extends Node
## Son de l'histoire : ambiances par lieu et moment (pluie, nuit, supermarché, bar, JT), musiques d'ambiance
## sobres des cinématiques et du bilan. VERSION SQUELETTE (muette) : le module Audio la remplace en gardant l'interface.

var director: ChapterDirector


func bind(d: ChapterDirector) -> void:
	director = d


func music(_id: String) -> void:
	pass


func ambience(_id: String) -> void:
	pass


func stop_music(_fade := 1.0) -> void:
	pass
