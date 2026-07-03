# Graphical Improvements Plan — Fallen Earth

**Version:** 0.1.0  
**Author:** Qwythos / Remedy  
**Date:** 2026-07-02  
**Status:** Pending user approval

---

## Overview

The procedural drawing system (GraphicsManager + ProceduralTile + LocalMapRenderer) currently produces flat, uniform tiles. This plan introduces:

- **Noise texture overlay** for organic ground detail per biome
- **Grit (sdf-based) overlay** for consistent grain
- **Parallax layer** (two-noise fog+ground) for depth
- **Shader overhaul** to mix these layers in a fragment shader
- **Vignette gradient** instead of flat black rect
- **Pulsing rift marker** with time-based shader
- **Optional biome overlays** (frost tint, void fog)

All changes are additive; existing fallbacks remain for missing assets.

---

## Implementation Steps

### 1. Extend GraphicsManager

**Add methods:**
- `get_grit_texture(size: int, biome: String)` → returns a shared `NoiseTexture` with SDF grain pattern, seeded per biome
- `get_parallax_layer(biome: String)` → returns a dict `{ "fog": NoiseTexture, "ground": NoiseTexture }` with different frequencies/amounts tuned per biome
- `get_biome_overlay(biome: String)` → returns a `NoiseTexture` (light blue for frost, purple for void) or `null`

**Tune parameters per biome:**
- Grit: `frequency = 3.0`, `amount = 0.025`, `seed = biome-specific`
- Parallax fog: `frequency = 0.8`, `amount = 0.08`, `seed = shared`
- Parallax ground: `frequency = 1.2`, `amount = 0.06`, `seed = shared`
- Frost overlay: `frequency = 2.0`, `amount = 0.03`, tint `Color(0.75, 0.85, 1.0)`
- Void overlay: `frequency = 1.5`, `amount = 0.04`, tint `Color(0.6, 0.5, 0.8)`

### 2. Refactor ProceduralTile

**Current state:** extends `ColorRect`, draws base color, cross-hatch lines, detail dots, rift polygon, rune marker, edge vignette.

**Changes:**
- Replace `ColorRect` with `CanvasTexture` node
- In `draw()`, construct a `ShaderMaterial` with:
  - `ALBEDO` texture: base color (from palette)
  - `PARALLAX` texture: parallax layer from step 1
  - `NOISE` texture: grit overlay from step 1
  - `OVERLAY` texture: biome overlay (frost/void) or `null`
  - `VIGNETTE` texture: gradient shader (see step 4)
- Shader mixes:
  - parallax fog at `0.55 * parallax.fog.amount`
  - parallax ground at `0.45 * parallax.ground.amount`
  - grit noise at `0.4 * grit.amount`
  - overlay tint blended over base with `0.6 * overlay.amount`
- Keep existing cross-hatch, detail dots, rift marker, rune marker as draw calls on top of the shader output
- Vignette now uses a `ShaderMaterial` that outputs a radial gradient (dark corners to center)

### 3. Update LocalMapRenderer

- Keep chunk structure, but when loading a chunk, instantiate `CanvasTexture` nodes instead of `ProceduralTile` ColorRects
- Pass the same tile data dictionary to a new `ProceduralTile` class (or keep existing as a facade)
- `ProceduralTile` now exposes `get_shader_params()` returning the dict for the shader

### 4. Add Vignette Shader

**Shader fragment (simplified):**
```glsl
uniform sampler2D uVignette;
void fragment() {
  vec4 base = texture(uVignette, uv);
  float alpha = smoothstep(0.0, 0.8, length(uv - vec2(0.5)));
  gl_FragColor = base * vec4(1.0, 1.0, 1.0, alpha);
}
```

**GDScript setup:**
```gdscript
var vignette := ShaderMaterial.new()
vignette.shader_code = """
shader_type canvas_texture;

uniform sampler2D uVignette;

void fragment() {
  vec4 base = texture(uVignette, uv);
  float alpha = smoothstep(0.0, 0.8, length(uv - vec2(0.5)));
  gl_FragColor = base * vec4(1.0, 1.0, 1.0, alpha);
}
"""
vignette.set_shader_param("uVignette", vignette)
```

### 5. Shader Overhaul for Mixing

**Full shader (simplified):**
```glsl
shader_type canvas_texture;

uniform sampler2D uAlbedo;
uniform sampler2D uParallax;
uniform sampler2D uNoise;
uniform sampler2D uOverlay;
uniform vec4 uOverlayColor;
uniform float uOverlayAmount;

void fragment() {
  vec3 albedo = texture(uAlbedo, uv).rgb;

  vec3 parallax = texture(uParallax, uv).rgb;
  parallax = mix(parallax, vec3(0.0), 0.55 * texture(uParallax, uv).a);

  vec3 noise = texture(uNoise, uv).rgb * 0.4;

  vec3 overlay = texture(uOverlay, uv).rgb;
  overlay = mix(overlay, albedo, 0.6 * uOverlayAmount);

  gl_FragColor = vec4(albedo + parallax + noise, 1.0);
}
```

### 6. Testing & Validation

- Run `check_compile.py` after each step
- Perform F5 playthrough (NEXT_TASKS P0) and visually inspect tile variation
- Compare against baseline screenshots (optional)

### 7. Risks & Considerations

- Shader size: custom shaders in Godot are text-only; no asset caching (unlike NoiseTexture)
- Performance: mixing multiple textures per tile; acceptable at 64×64 chunks
- Memory: parallax layers per biome (~10–15 KB each); negligible compared to asset packs
- Backwards compatibility: all changes optional; existing fallbacks preserved

---

## Expected Improvements

| Feature | Before | After |
|---|---|---|
| Ground texture | Flat color | Noise overlay + grit |
| Depth | None | Parallax fog + ground |
| Biome atmosphere | None | Frost tint / void fog |
| Edge fade | Black rect | Gradient vignette |
| Rift marker | Static polygon | Pulsing shader |

---

## Next Actions

1. User approves plan → proceed with implementation
2. Implement step 1 (GraphicsManager extensions)
3. Implement step 2 (ProceduralTile shader refactor)
4. Implement step 3 (LocalMapRenderer update)
5. Implement step 4 (vignette shader)
6. Implement step 5 (full shader mixing)
7. Validate & test
8. Update CHANGELOG.md on release
