class_name AncientClue
extends StoryInteractable
## The Phase 1 final clue (altar with glowing relief). Reusable scene: AncientClue.tscn.

func _init() -> void:
	style = "altar"
	lore_id = "final_clue"
	objective_id = "altar"
	required_objective = "altar"
	prompt_text = "Examine the relief"
	interact_radius = 3.4
