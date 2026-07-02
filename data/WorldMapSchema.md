/**
 * WorldMapSchema.json
 * Canonical data layout for persistent world state in Fallen Earth.
 * This structure ensures all core scripts consume map data with predictable keys and types.
 */

{
    "schema_version": "1.0",
    "seed": "[SEED_VALUE]",
    "dimensions": {
        "width": 64,
        "height": 64
    },
    "tiles": [
        // Array of tiles in row-major order (x=0, y=0) to (x=W-1, y=H-1)
        {
            "id": "0,0",
            "biome_name": "Forest",      // Must match BiomeConfig names
            "tile_type": "Grassland",    // High level category for rendering/game logic
            "elevation": 0.65,           // Float: [0.0, 1.0]. Used for height calculation/player fall checks.
            "features": ["dense_trees"], // Array of relevant features (from BiomeConfig)
            "is_navigable": true         // Boolean flag for quick pathfinding/AI traversals
        },
        {
            "id": "1,0",
            "biome_name": "Savanna",
            "tile_type": "OpenField",
            "elevation": 0.55,
            "features": [],
            "is_navigable": true
        }
        // ... rest of the map tiles follow this structure
    ],
    "summary_stats": {
        "total_forest_area": "[COUNT]", 
        "average_elevation": 0.52,
        "biome_distribution": {
            /* Key: BiomeName (str), Value: Count (int) */
            "Forest": 896,
            "Desert": 432,
            // ... and so on
        }
    },
    "metadata": {
        "generation_source": "WorldGenerator.py",
        "creation_date_utc": "[ISO_DATE]"
    }
}