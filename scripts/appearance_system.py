#!/usr/bin/env python3
"""Appearance and gender configuration for Fallen Earth RPG character creation."""

from dataclasses import dataclass
from typing import Any, Dict, List


@dataclass(frozen=True)
class AppearancePart:
    """A single appearance category (hair, eyes, skin, body)."""

    name: str
    options: list[str]
    default: str


@dataclass(frozen=True)
class AppearanceSet:
    """A complete appearance configuration combining all parts."""

    hair: str
    eyes: str
    skin: str
    body: str

    def to_dict(self) -> Dict[str, Any]:
        return {"hair": self.hair, "eyes": self.eyes, "skin": self.skin, "body": self.body}


class AppearanceSystem:
    """Manages appearance options and class defaults."""

    PARTS = [
        AppearancePart("hair", ["bald", "short_spiky", "long_flowing", "messy_short", "afro"], "short_spiky"),
        AppearancePart("eyes", ["blue", "green", "brown", "hazel"], "hazel"),
        AppearancePart("skin", ["pale", "medium_tan", "dark_brown"], "medium_tan"),
        AppearancePart("body", ["slim", "athletic", "muscular"], "athletic"),
    ]

    CLASS_GENDER_MAP: Dict[str, List[str]] = {
        "warrior": ["male", "female"],
        "paladin": ["male", "female"],
        "rogue": ["male", "female"],
        "hunter": ["male", "female"],
        "mage": ["male", "female"],
    }

    CLASS_APPEARANCE_MAP: Dict[str, AppearanceSet] = {
        "warrior": AppearanceSet("short_spiky", "hazel", "medium_tan", "muscular"),
        "paladin": AppearanceSet("messy_short", "blue", "pale", "athletic"),
        "rogue": AppearanceSet("afro", "green", "dark_brown", "slim"),
    }

    def get_default_appearance(self, class_name: str) -> AppearanceSet | None:
        """Get the default appearance for a given class."""
        if class_name not in self.CLASS_APPEARANCE_MAP:
            return None
        return self.CLASS_APPEARANCE_MAP[class_name]

    def get_allowed_genders(self, class_name: str) -> List[str]:
        """Get allowed gender options for a character class."""
        return self.CLASS_GENDER_MAP.get(class_name, ["male", "female"])

    def validate_appearance_set(
        self, appearance: Dict[str, Any],
    ) -> tuple[bool, List[str]]:
        """Validate that an appearance dictionary has all required parts with valid values.

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
            "hair": ["bald", "short_spiky", "long_flowing", "messy_short", "afro"],
            "eyes": ["blue", "green", "brown", "hazel"],
            "skin": ["pale", "medium_tan", "dark_brown"],
            "body_type": ["slim", "athletic", "muscular"],
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

    def get_valid_options(self, part_name: str) -> list[str]:
        """Get all valid options for a specific appearance part."""
        for part in self.PARTS:
            if part.name == part_name:
                return part.options
        return []


def main():
    system = AppearanceSystem()

    print("=== Fallen Earth RPG Appearance System ===\n")

    # Show hair options
    print(f"Available hair styles: {system.get_valid_options('hair')}")

    # Show warrior default appearance
    if (warrior_appearance := system.get_default_appearance("warrior")):
        print(f"\nWarrior default appearance:")
        for key, value in warrior_appearance.to_dict().items():
            print(f"  {key}: {value}")

    # Show paladin gender options
    if (paladin_gender_options := system.get_allowed_genders("paladin")):
        print(f"\nPaladin allowed genders: {paladin_gender_options}")


if __name__ == "__main__":
    main()