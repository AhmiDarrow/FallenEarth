"""Character archetype definitions for Fallen Earth RPG."""

from dataclasses import dataclass, field
from typing import Dict, Any, Optional


@dataclass
class Stat:
    """Base stat value with potential modifiers."""
    name: str
    base_value: float
    display_name: str
    description: str


STATS = {
    "STR": Stat("strength", 10, "Strength", "Physical power and carrying capacity"),
    "CON": Stat("constitution", 8, "Constitution", "Health pool and endurance"),
    "DEX": Stat("dexterity", 7, "Dexterity", "Reflexes and agility"),
    "INT": Stat("intelligence", 6, "Intelligence", "Knowledge and analytical ability"),
    "WIS": Stat("wisdom", 7, "Wisdom", "Perception and intuition"),
    "CHA": Stat("charisma", 5, "Charisma", "Social influence and leadership"),
}


@dataclass
class EquipmentSlot:
    """Equipment slot type."""
    name: str
    primary_stat: str = ""
    secondary_stat: str = ""
    common_items: list[str] = field(default_factory=list)


SLOTS = {
    "HELMET": EquipmentSlot("helmet", primary_stat="DEX"),
    "BODY": EquipmentSlot("body armor", primary_stat="CON"),
    "ARMOR": EquipmentSlot("armored vest", primary_stat="STR"),
    "CHEST": EquipmentSlot("chest piece", primary_stat="CON"),
    "WEAPONSLOT1": EquipmentSlot("weapon slot 1"),
    "WEAPONSLOT2": EquipmentSlot("weapon slot 2"),
    "SHOES": EquipmentSlot("footwear", secondary_stat="DEX"),
}


@dataclass
class Archetype:
    """Base character archetype with stats and equipment preferences."""
    name: str
    tag: str
    stat_bonus: Dict[str, float]
    stat_focus: list[str]
    equipment_slots: list[str] = field(default_factory=list)
    starting_equipment: Optional[list[str]] = None
    description: str = ""


class Scavenger(Archetype):
    """Adaptable survivor who scours wasteland for resources."""

    def __init__(self, stats=None, overrides: Dict[str, float] = None):
        if stats is None:
            self.stats = {k: v.base_value + (v.name == "DEX") * 2.0 for k, v in STATS.items()}
        else:
            self.stats = stats

        # Stat bonuses from archetype
        bonus_str = overrides.get("STR", 3) if overrides else 3
        bonus_dex = overrides.get("DEX", 4) if overrides else 4

        self.stat_focus = ["DEX", "STR"]
        self.equipment_slots = ["WEAPONSLOT1", "CHEST", "SHOES"]
        self.description = (
            "Resourceful and adaptable, the Scavenger knows how to survive with whatever"
            " they can find. Balanced combatant who prioritizes mobility and durability."
        )

        # Calculate final stats with archetype bonuses
        if "STR" in self.stats:
            self.stats["STR"] += bonus_str
        if "DEX" in self.stats:
            self.stats["DEX"] += bonus_dex

    @property
    def primary_stat(self) -> str:
        return "DEX"

    @property
    def secondary_stat(self) -> str:
        return "STR"


class Technician(Archetype):
    """Former engineer who repurposes scavenged tech."""

    def __init__(self, stats=None, overrides: Dict[str, float] = None):
        if stats is None:
            self.stats = {k: v.base_value + (v.name == "INT") * 2.0 for k, v in STATS.items()}
        else:
            self.stats = stats

        # Stat bonuses from archetype
        bonus_int = overrides.get("INT", 4) if overrides else 4
        bonus_con = overrides.get("CON", 3) if overrides else 3

        self.stat_focus = ["INT", "CON"]
        self.equipment_slots = ["BODY", "HELMET", "WEAPONSLOT1"]
        self.description = (
            "Former engineer who maintains and repairs technology in the wasteland."
            " Prefers tools over weapons, using technical knowledge to survive."
        )

        # Calculate final stats with archetype bonuses
        if "INT" in self.stats:
            self.stats["INT"] += bonus_int
        if "CON" in self.stats:
            self.stats["CON"] += bonus_con

    @property
    def primary_stat(self) -> str:
        return "INT"

    @property
    def secondary_stat(self) -> str:
        return "CON"


class Survivor(Archetype):
    """Balanced character built for endurance and persistence."""

    def __init__(self, stats=None, overrides: Dict[str, float] = None):
        if stats is None:
            self.stats = {k: v.base_value for k, v in STATS.items()}
        else:
            self.stats = stats

        # Small bonuses across the board, but focus on stability
        small_bonus = 1.0

        self.stat_focus = ["CON", "WIS"]
        self.equipment_slots = ["BODY", "WEAPONSLOT2", "SHOES"]
        self.description = (
            "Pragmatic and resilient survivor who endures to another day."
            " No specializations, just determination and persistence."
        )

        # Calculate final stats with small archetype bonuses
        for stat in ["CON", "WIS"]:
            if stat in self.stats:
                self.stats[stat] += small_bonus

    @property
    def primary_stat(self) -> str:
        return "CON"

    @property
    def secondary_stat(self) -> str:
        return "WIS"


# Available archetypes for selection
AVAILABLE_ARCHETYPES = {
    "scavenger": Scavenger(),
    "technician": Technician(),
    "survivor": Survivor(),
}


def get_archetype(name: str, stats=None, overrides=None) -> Archetype:
    """Factory function to create an archetype by name.

    Args:
        name: One of 'scavenger', 'technician', or 'survivor'
        stats: Optional custom stat dictionary (overrides defaults)
        overrides: Optional stat adjustments per archetype (STR, DEX, etc.)

    Returns:
        Configured Archetype instance with all bonuses applied.

    Raises:
        ValueError: If name is not a valid archetype type.
    """
    if name not in AVAILABLE_ARCHETYPES:
        raise ValueError(f"Unknown archetype: {name}. Available: {list(AVAILABLE_ARCHETYPES.keys())}")
    return AVAILABLE_ARCHETYPES.get(name)  # Safe because we validated it exists above

__all__ = [
    "Stat",
    "EquipmentSlot",
    "Archetype",
    "STATS",
    "SLOTS",
    "AVAILABLE_ARCHETYPES",
    "Scavenger",
    "Technician",
    "Survivor",
]
