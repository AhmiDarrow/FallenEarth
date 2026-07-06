## BossAI — Multi-phase boss behavior.
##
## Phase 1 (>50% HP): mostly AggressiveAI.
## Phase 2 (25-50% HP): mix aggressive + AOE skill spam.
## Phase 3 (<25% HP): enrage — +50% damage, prefer skills, may use
##                     signature ability once.
class_name BossAI extends CombatAI


const PHASE2_THRESHOLD := 0.5
const PHASE3_THRESHOLD := 0.25
const ENRAGE_DAMAGE_MULT := 1.5


var _signature_used: bool = false


func decide(state: Dictionary) -> Dictionary:
	var self_unit: Dictionary = state.get("self", {})
	var my_hp: int = int(self_unit.get("hp", 0))
	var my_max: int = int(self_unit.get("max_hp", my_hp))
	var my_ratio: float = float(my_hp) / float(maxi(1, my_max))
	# Route to a sub-archetype depending on phase.
	if my_ratio >= PHASE2_THRESHOLD:
		return _aggressive.decide(state)
	elif my_ratio >= PHASE3_THRESHOLD:
		# Use skills aggressively if available, else fall back.
		var caster: CasterAI = CasterAI.new()
		var caster_action: Dictionary = caster.decide(state)
		caster.free()
		if caster_action.get("type", "wait") == "skill":
			return caster_action
		return _aggressive.decide(state)
	else:
		# Enrage — prefer skills, then attack. If signature ability is
		# available, use it once.
		if not _signature_used:
			var abilities: Array = self_unit.get("abilities", []) as Array
			for ab in abilities:
				if bool(ab.get("is_signature", false)):
					var cost: int = int(ab.get("mp_cost", 0))
					var mp: int = int(self_unit.get("mp", 0))
					if mp >= cost:
						var skillable: Array = state.get("skillable", []) as Array
						if not skillable.is_empty():
							_signature_used = true
							return {
								"type": "skill",
								"skill_id": ab.get("id", ""),
								"target": skillable[0],
								"score": 999.0,
							}
		var caster2: CasterAI = CasterAI.new()
		var ca: Dictionary = caster2.decide(state)
		caster2.free()
		if ca.get("type", "wait") == "skill":
			return ca
		return _aggressive.decide(state)


var _aggressive: AggressiveAI = AggressiveAI.new()
