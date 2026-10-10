extends Node
## Progression data: talents, abilities, leveling.

const BRANCHES := [
    { "name": "fuerza", "color": Color(0.8, 0.2, 0.2) },
    { "name": "precision", "color": Color(0.8, 0.8, 0.2) },
    { "name": "devastador", "color": Color(0.8, 0.2, 0.8) },
    { "name": "concentracion", "color": Color(0.2, 0.8, 0.2) },
    { "name": "potencia", "color": Color(0.2, 0.2, 0.8) },
    { "name": "maestro", "color": Color(0.8, 0.5, 0.2) },
    { "name": "agilidad", "color": Color(0.2, 0.8, 0.8) },
    { "name": "cosechador", "color": Color(0.8, 0.6, 0.2) },
]

const TIER_REQ := [0, 3, 8] # points needed in branch to unlock tier 1,2,3

const TALENTS := {
    "fuerza_1": { "name": "Fuerza I", "branch": 0, "tier": 0, "max": 5, "desc": "+5% daño" },
    "fuerza_2": { "name": "Fuerza II", "branch": 0, "tier": 1, "max": 5, "desc": "+10% daño" },
    "fuerza_3": { "name": "Fuerza III", "branch": 0, "tier": 2, "max": 5, "desc": "+15% daño" },
    "precision_1": { "name": "Precisión I", "branch": 1, "tier": 0, "max": 5, "desc": "+3% crítica" },
    "precision_2": { "name": "Precisión II", "branch": 1, "tier": 1, "max": 5, "desc": "+6% crítica" },
    "precision_3": { "name": "Precisión III", "branch": 1, "tier": 2, "max": 5, "desc": "+9% crítica" },
    "devastador_1": { "name": "Devastador I", "branch": 2, "tier": 0, "max": 5, "desc": "+0.8x daño crítico" },
    "devastador_2": { "name": "Devastador II", "branch": 2, "tier": 1, "max": 5, "desc": "+1.0x daño crítico" },
    "devastador_3": { "name": "Devastador III", "branch": 2, "tier": 2, "max": 5, "desc": "+1.2x daño crítico" },
    "concentracion_1": { "name": "Concentración I", "branch": 3, "tier": 0, "max": 5, "desc": "-4% enfriamiento" },
    "concentracion_2": { "name": "Concentración II", "branch": 3, "tier": 1, "max": 5, "desc": "-8% enfriamiento" },
    "concentracion_3": { "name": "Concentración III", "branch": 3, "tier": 2, "max": 5, "desc": "-12% enfriamiento" },
    "potencia_1": { "name": "Potencia I", "branch": 4, "tier": 0, "max": 5, "desc": "+8% daño de habilidad" },
    "potencia_2": { "name": "Potencia II", "branch": 4, "tier": 1, "max": 5, "desc": "+16% daño de habilidad" },
    "potencia_3": { "name": "Potencia III", "branch": 4, "tier": 2, "max": 5, "desc": "+24% daño de habilidad" },
    "maestro_1": { "name": "Maestro I", "branch": 5, "tier": 0, "max": 5, "desc": "+15% daño de habilidad (ranura 3)" },
    "maestro_2": { "name": "Maestro II", "branch": 5, "tier": 1, "max": 5, "desc": "+30% daño de habilidad (ranura 3)" },
    "maestro_3": { "name": "Maestro III", "branch": 5, "tier": 2, "max": 5, "desc": "+45% daño de habilidad (ranura 3)" },
    "agilidad_1": { "name": "Agilidad I", "branch": 6, "tier": 0, "max": 5, "desc": "+4% velocidad de movimiento" },
    "agilidad_2": { "name": "Agilidad II", "branch": 6, "tier": 1, "max": 5, "desc": "+8% velocidad de movimiento" },
    "agilidad_3": { "name": "Agilidad III", "branch": 6, "tier": 2, "max": 5, "desc": "+12% velocidad de movimiento" },
    "cosechador_1": { "name": "Cosechador I", "branch": 7, "tier": 0, "max": 5, "desc": "-8% tiempo de recolección" },
    "cosechador_2": { "name": "Cosechador II", "branch": 7, "tier": 1, "max": 5, "desc": "-16% tiempo de recolección" },
    "cosechador_3": { "name": "Cosechador III", "branch": 7, "tier": 2, "max": 5, "desc": "-24% tiempo de recolección" },
}

const QUESTS := {}

# Abilities by class
const ABILITIES_BY_CLASS := {
    "Knight": [
        { "name": "Golpe Feroz", "type": "cone", "unlock": 1, "cd": 4.0, "range": 2.5, "cos": 0.7, "mult": 1.8 },
        { "name": "Onda de Choque", "type": "aoe_self", "unlock": 3, "cd": 6.0, "radius": 3.0, "mult": 1.5 },
        { "name": "Fuego Sagrado", "type": "buff", "unlock": 5, "cd": 8.0, "duration": 5.0, "dmg": 0.2, "aspd": 0.1 },
        { "name": "Luz Divina", "type": "projectile", "unlock": 7, "cd": 5.0, "kind": "Light", "color": Color(1.0, 1.0, 0.6), "speed": 20.0, "range": 15.0, "mult": 1.6 }
    ]
}

func abilities_of(class_name: String) -> Array:
    return ABILITIES_BY_CLASS.get(class_name, [])

func talent_rank(id: String) -> int:
    # This should be backed by GameState; we'll just return 0 for now.
    return 0

func can_spend(id: String) -> bool:
    return false

func spend_talent(id: String) -> void:
    pass

func reset_talents() -> void:
    pass

func points_in_branch(branch: int) -> int:
    return 0

func tier_req(tier: int) -> int:
    return TIER_REQ[tier] if tier < TIER_REQ.size() else 0