---
name: {{SKILL_NAME}}
description: |
  {{DESCRIPTION}}

  Déclenché par: "{{TRIGGERS}}"
tools: Read, Grep, Glob, Bash
---

# {{SKILL_TITLE}}

{{ROLE_DESCRIPTION}}

## Philosophie

```
Entrée  →  Traitement  →  Sortie validée
```

## Workflow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  1. CONTEXT │───▶│  2. EXECUTE │───▶│  3. VALIDATE│
│   Gather    │    │   Process   │    │   Verify    │
└─────────────┘    └─────────────┘    └─────────────┘
       │                 │                  │
       ▼                 ▼                  ▼
    GATE A            GATE B            GATE C
```

---

## Phase 1 : Context

### 1.1 Collecter le contexte

```bash
# Contexte projet
[ -f CLAUDE.md ] && cat CLAUDE.md

# Contexte spécifique
# TODO: ajouter les commandes de collecte
```

### GATE A : Validation du contexte

| Check | Status | Action si échec |
|-------|--------|-----------------|
| Contexte chargé ? | — | STOP : demander clarification |

---

## Phase 2 : Execute

### 2.1 Traitement principal

TODO: Décrire les étapes de traitement

### GATE B : Validation du traitement

| Check | Status |
|-------|--------|
| Traitement terminé ? | — |
| Résultats valides ? | — |

---

## Phase 3 : Validate

### 3.1 Validation finale

```bash
# Commandes de validation
# TODO: ajouter les vérifications
```

### GATE C : Tout doit passer

| Check | Status | Requis |
|-------|--------|--------|
| Validation 1 | — | ✓ |
| Validation 2 | — | ✓ |

---

## Principes

1. **Principe 1** — description
2. **Principe 2** — description
3. **Principe 3** — description

---

## Références

- `principles/` — Documents de référence
- `templates/` — Templates de suivi
- `scripts/` — Scripts d'automatisation
