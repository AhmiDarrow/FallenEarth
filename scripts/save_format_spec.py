#!/usr/bin/env python3
"""Save format specifications and JSON schema definitions for Fallen Earth RPG.

Defines:
- Appearance data structures (dict, model)
- Equipment data structures
- Validation utilities
- Default values for new saves

Usage:
    from scripts.save_format_spec import (
        CharacterAppearance,
        WeaponSlotConfig,
        EquipmentData,
        validate_character_appearance,
        DEFAULT_CHARACTER_APPEARANCE,
    )

    appearance = {"hair": "short_spiky", "eyes": "hazel", ...}
    is_valid, errors = validate_character_appearance(appearance)
"""

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple
import json


# =============================================================================
# APPEARANCE DATA STRUCTURES
# =============================================================================

@dataclass(frozen=True)
class CharacterAppearance:
    """Complete appearance configuration for a character."""

    hair: str
    eyes: str
    skin: str
    body_type: str

    # Optional extended fields (not in basic save format)
    face_shape: Optional[str] = None
    facial_features: Optional[Dict[str, Any]] = None
    body_features: Optional[Dict[str, Any]] = None


# Available appearance options by category
HAIR_OPTIONS: List[str] = ["bald", "short_spiky", "long_flowing", "messy_short", "afro"]
EYE_OPTIONS: List[str] = ["blue", "green", "brown", "hazel", "amber"]
SKIN_OPTIONS: List[str] = ["pale", "medium_tan", "dark_brown", "olive", "ruddy"]
BODY_TYPE_OPTIONS: List[str] = ["slim", "athletic", "muscular", "voluptuous", "broad_shouldered"]


# =============================================================================
# EQUIPMENT DATA STRUCTURES
# =============================================================================

@dataclass(frozen=True)
class WeaponSlotConfig:
    """Configuration for a specific weapon slot."""

    name: str  # e.g., "primary_hand", "secondary_hand"
    type: str  # e.g., "melee", "ranged", "magic"
    size_category: str  # e.g., "small", "medium", "large", "huge"


@dataclass(frozen=True)
class EquipmentData:
    """Equipment data for a character."""

    primary_hand: Optional[str] = None
    secondary_hand: Optional[str] = None
    
    # Optional extended fields (not in basic save format)
    armor_type: Optional[str] = None
    shield_type: Optional[str] = None


# Weapon slot configurations (matches game data structure)
WEAPON_SLOTS = [
    WeaponSlotConfig("primary_hand", "melee", "medium"),
    WeaponSlotConfig("secondary_hand", "ranged", "small"),
]


# =============================================================================
# DEFAULT VALUES FOR NEW SAVES
# =============================================================================

DEFAULT_CHARACTER_APPEARANCE: Dict[str, str] = {
    "hair": "short_spiky",
    "eyes": "hazel",
    "skin": "medium_tan",
    "body_type": "athletic"
}

DEFAULT_EQUIPMENT_DATA: EquipmentData = EquipmentData()


# =============================================================================
# VALIDATION UTILITIES
# =============================================================================

def validate_character_appearance(
    appearance: Dict[str, Any],
) -> Tuple[bool, List[str]]:
    """Validate that an appearance dictionary has all required parts with valid values.

    Args:
        appearance: Dictionary containing appearance data

    Returns:
        Tuple of (is_valid, list_of_errors)
    """
    errors = []

    # Check for required fields
    required_fields = ["hair", "eyes", "skin", "body_type"]
    for field_name in required_fields:
        if field_name not in appearance:
            errors.append(f"Missing required appearance field: {field_name}")

    # Validate each field value against allowed options
    valid_options_map = {
        "hair": HAIR_OPTIONS,
        "eyes": EYE_OPTIONS,
        "skin": SKIN_OPTIONS,
        "body_type": BODY_TYPE_OPTIONS,
    }

    for field_name in required_fields:
        if field_name in appearance:
            value = appearance[field_name]
            allowed = valid_options_map.get(field_name)
            if allowed and value not in allowed:
                errors.append(
                    f"Invalid {field_name} value '{value}' (allowed: {', '.join(allowed)})"
                )

    return len(errors) == 0, errors


def validate_equipment_data(
    equipment: Dict[str, Any],
) -> Tuple[bool, List[str]]:
    """Validate that an equipment dictionary has valid slot assignments.

    Args:
        equipment: Dictionary containing equipment data

    Returns:
        Tuple of (is_valid, list_of_errors)
    """
    errors = []

    # Check for None values in required slots
    if "primary_hand" in equipment and equipment["primary_hand"] is None:
        errors.append("primary_hand cannot be None")

    if "secondary_hand" in equipment and equipment["secondary_hand"] is None:
        errors.append("secondary_hand cannot be None (use empty string '')")

    # Validate slot values are non-empty strings
    for slot_name, value in [("primary_hand", "primary_hand"), ("secondary_hand", "secondary_hand")]:
        if slot_name in equipment and not isinstance(value, str):
            errors.append(f"{slot_name} must be a string (not {type(value).__name__})")

    return len(errors) == 0, errors


# =============================================================================
# SAVE FORMAT SPECIFICATIONS
# =============================================================================

SAVE_FORMAT_VERSION = "1.0"
DEFAULT_SAVE_TEMPLATE: Dict[str, Any] = {
    "version": SAVE_FORMAT_VERSION,
    "appearance": {
        "hair": "short_spiky",
        "eyes": "hazel",
        "skin": "medium_tan",
        "body_type": "athletic"
    },
    "equipment": DEFAULT_EQUIPMENT_DATA.__dict__,
}


def get_save_template() -> Dict[str, Any]:
    """Get the default template for a new save file."""
    return DEFAULT_SAVE_TEMPLATE.copy()


__all__ = [
    # Data structures
    "CharacterAppearance",
    "EquipmentData",
    "WeaponSlotConfig",
    # Constants
    "SAVE_FORMAT_VERSION",
    "DEFAULT_CHARACTER_APPEARANCE",
    "DEFAULT_EQUIPMENT_DATA",
    "HAIR_OPTIONS",
    "EYE_OPTIONS",
    "SKIN_OPTIONS",
    "BODY_TYPE_OPTIONS",
    # Validation
    "validate_character_appearance",
    "validate_equipment_data",
    # Utilities
    "get_save_template",
]