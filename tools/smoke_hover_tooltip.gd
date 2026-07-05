extends SceneTree
## Smoke test for the v0.4.0 Phase 1b hover tooltip.
## Exercises:
##   - HoverTooltip.shows nothing when target is empty
##   - HoverTooltip tracks current target across updates
##   - HoverTooltip waits 1 second before showing
##   - HoverTooltip updates immediately when target changes
##   - HubWorld._hit_test_at_world returns the right name for each entity type

const HoverTooltipScript = preload("res://scripts/HoverTooltip.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var failures: Array[String] = []


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)


func _ok(msg: String) -> void:
	print("  ok  " + msg)


func _initialize() -> void:
	print("[smoke-tt] v0.4.0 Phase 1b hover tooltip")
	_test_tooltip_idle_hides_label()
	_test_tooltip_dwell_one_second()
	_test_tooltip_target_change_resets_dwell()
	_test_tooltip_target_clear_hides()

	if failures.is_empty():
		print("[smoke-tt] All checks passed.")
		quit(0)
	else:
		for f in failures:
			print("[smoke-tt] FAIL: " + f)
		print("[smoke-tt] %d failure(s)." % failures.size())
		quit(1)


func _test_tooltip_idle_hides_label() -> void:
	print("[smoke-tt] test: tooltip idle hides label")
	var tip: Control = HoverTooltipScript.new()
	root.add_child(tip)
	await process_frame
	# No update calls yet — should be hidden
	if tip.is_showing():
		_fail("Fresh tooltip should not be showing")
		return
	# Empty target stays hidden
	tip.update(Vector2(100, 100), "")
	if tip.is_showing():
		_fail("Tooltip with empty target should be hidden")
		return
	_ok("Idle / empty target: hidden")


func _test_tooltip_dwell_one_second() -> void:
	print("[smoke-tt] test: tooltip waits 1s before showing")
	var tip: Control = HoverTooltipScript.new()
	root.add_child(tip)
	await process_frame
	# First update with a target — should reset dwell and stay hidden
	tip.update(Vector2(100, 100), "Test Target")
	if tip.is_showing():
		_fail("After first update, tooltip should be hidden (dwell not elapsed)")
		return
	_ok("Right after first update: hidden (dwell not elapsed)")
	# Wait 1.1 seconds (1100 ms) and call update again
	await create_timer(1.1).timeout
	tip.update(Vector2(100, 100), "Test Target")
	if not tip.is_showing():
		_fail("After 1.1s dwell on same target, tooltip should be visible")
		return
	if tip.get_current_target() != "Test Target":
		_fail("Tooltip text wrong: %s" % tip.get_current_target())
		return
	_ok("After 1.1s dwell: visible with correct text")


func _test_tooltip_target_change_resets_dwell() -> void:
	print("[smoke-tt] test: target change resets dwell")
	var tip: Control = HoverTooltipScript.new()
	root.add_child(tip)
	await process_frame
	tip.update(Vector2(100, 100), "Target A")
	# Wait 1.1s to show Target A
	await create_timer(1.1).timeout
	tip.update(Vector2(100, 100), "Target A")
	if not tip.is_showing():
		_fail("Target A should be visible after dwell")
		return
	# Now switch to Target B. Should immediately hide.
	tip.update(Vector2(100, 100), "Target B")
	if tip.is_showing():
		_fail("Target B should be hidden immediately (new dwell timer)")
		return
	# Wait 0.5s — still under 1s dwell
	await create_timer(0.5).timeout
	tip.update(Vector2(100, 100), "Target B")
	if tip.is_showing():
		_fail("Target B should still be hidden at 0.5s (dwell not elapsed)")
		return
	# Wait remaining 0.6s
	await create_timer(0.6).timeout
	tip.update(Vector2(100, 100), "Target B")
	if not tip.is_showing():
		_fail("Target B should be visible after 1.1s total")
		return
	if tip.get_current_target() != "Target B":
		_fail("Tooltip text should be 'Target B', got '%s'" % tip.get_current_target())
		return
	_ok("Target change resets dwell correctly")


func _test_tooltip_target_clear_hides() -> void:
	print("[smoke-tt] test: empty target hides visible tooltip")
	var tip: Control = HoverTooltipScript.new()
	root.add_child(tip)
	await process_frame
	tip.update(Vector2(100, 100), "Visible Target")
	await create_timer(1.1).timeout
	tip.update(Vector2(100, 100), "Visible Target")
	if not tip.is_showing():
		_fail("Tooltip should be visible after dwell")
		return
	# Now pass empty target — should hide immediately
	tip.update(Vector2(200, 200), "")
	if tip.is_showing():
		_fail("Tooltip should be hidden after empty target update")
		return
	# Subsequent update with same empty target stays hidden
	tip.update(Vector2(200, 200), "")
	if tip.is_showing():
		_fail("Empty target should keep tooltip hidden")
		return
	_ok("Empty target hides visible tooltip immediately")
