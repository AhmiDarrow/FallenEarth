# Image Vision Memory

## Problem
The error: `Cannot read "C:\Users\Administrator\OneDrive\Pictures\Screenshots\Screenshot 2026-07-16 000754.png"` - the model doesn't support direct image input from file paths.

## Solution Pattern
Use **pixellab_create_map_object** with a `background_image` parameter that accepts base64-encoded PNG data, not raw file paths.

## Workflow
1. Read the file content (using `read` skill) to get the exact bytes
2. Convert to base64
3. Pass to pixellab as `{"type": "base64", "base64": "..."}`
