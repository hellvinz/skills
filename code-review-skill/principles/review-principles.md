# Review Principles Reference

Ces principes sont cités en référence lors de la détection d'issues.

---

## Architecture & Design

| ID | Principe | Question clé |
|----|----------|--------------|
| #7 | **Remember the Big Picture** | Le changement s'inscrit-il dans l'architecture globale ? |
| #14 | **Good Design Is Easier to Change** | Le code reste-t-il facile à modifier ? |
| #17 | **Eliminate Effects Between Unrelated Things** | Y a-t-il des effets de bord inattendus ? |
| #44 | **Decoupled Code Is Easier to Change** | Le couplage est-il minimal ? |
| OCP | **Open/Closed Principle** | Le code permet-il l'extension sans modification ? |

---

## Code Quality & Abstraction

| ID | Principe | Question clé |
|----|----------|--------------|
| #5 | **Don't Live with Broken Windows** | Slop, code mort, dette technique tolérée ? |
| #15 | **DRY—Don't Repeat Yourself** | Duplication détectée ? |
| #16 | **Make It Easy to Reuse** | Abstraction utile vs sur-ingénierie ? |
| SG | **Shameless Green** | Solution simple qui marche > abstraction prématurée |
| RPA | **Resist Premature Abstraction** | L'abstraction émerge-t-elle du code ou est-elle forcée ? |
| #62 | **Don't Program by Coincidence** | Le code fonctionne-t-il par accident ? |
| SM | **Sandi Metz Questions** | Difficile à écrire ? À comprendre ? À modifier ? |

---

## Naming & Readability

| ID | Principe | Question clé |
|----|----------|--------------|
| #74 | **Name Well; Rename When Needed** | Nommage clair et cohérent ? |
| DOM | **Name by Concept, Not Implementation** | Les noms reflètent-ils le domaine métier ? |
| #45 | **Tell, Don't Ask** | Le code demande-t-il des données pour décider au lieu de déléguer ? |
| #46 | **Don't Chain Method Calls** | Chaînes d'appels excessives (Law of Demeter) ? |

---

## Complexity & Performance

| ID | Principe | Seuils |
|----|----------|--------|
| #63 | **Estimate Algorithm Order** | Complexité algorithmique acceptable ? |
| ABC | **ABC Metric** | Assignments, Branches, Conditions équilibrés ? |
| CC | **Cyclomatic Complexity** | ≤10 OK, 11-20 ⚠️, >20 🔴 |
| LOC | **Lines per Function** | ≤50 OK, 51-100 ⚠️, >100 🔴 |
| PARAMS | **Parameters per Function** | ≤4 OK, 5-6 ⚠️, >6 🔴 |
| NEST | **Nesting Depth** | ≤3 OK, 4 ⚠️, >4 🔴 |

---

## Testing

| ID | Principe | Question clé |
|----|----------|--------------|
| #67 | **A Test Is the First User** | Le nouveau code a-t-il des tests ? |
| #69 | **Design to Test** | Le code est-il testable ? |
| #93 | **Test State Coverage** | Les tests couvrent-ils les états, pas juste les lignes ? |
| #94 | **Find Bugs Once** | Un bug corrigé a-t-il un test de régression ? |

---

## Refactoring

| ID | Principe | Question clé |
|----|----------|--------------|
| #65 | **Refactor Early, Refactor Often** | Le moment est-il venu de refactorer ? |
| FLOCK | **Flocking Rules** | (1) similaires, (2) plus petite différence, (3) plus petit changement |
| SMELL | **Code Smells = Deferred Decisions** | Un smell n'est pas toujours à corriger immédiatement |
| EVOLVE | **Code Evolves (Fowler)** | Ce changement rend-il une décision passée obsolète ? |

---

## Documentation

| ID | Principe | Question clé |
|----|----------|--------------|
| #13 | **Build Documentation In** | Les commentaires capturent-ils le "pourquoi" métier ? |
| CLARITY | **Explicit Clarity (Cunningham/Fowler)** | Le code rend-il la compréhension explicite ? |

---

## Robustness

| ID | Principe | Question clé |
|----|----------|--------------|
| #37 | **Design with Contracts** | Les entrées/sorties sont-elles validées ? |
| #38 | **Crash Early** | Les erreurs sont-elles gérées tôt et explicitement ? |
| #42 | **Take Small Steps—Always** | Le changement est-il trop gros d'un coup ? |
| #47 | **Avoid Global Data** | État global injustifié ? |
| #57 | **Shared State Is Incorrect State** | Risques de concurrence ? |

---

## Security

| ID | Principe | Question clé |
|----|----------|--------------|
| SEC | **Targeted Security (Fowler)** | Module sensible (auth, paiement, PII) touché ? |

---

## Slop Patterns

### Commentaires inutiles (à supprimer)

```
// Get the user          → SLOP
// Set the value         → SLOP  
// Return the result     → SLOP
// This function does X  → SLOP
// Loop through items    → SLOP
```

### Commentaires acceptables (à garder)

```
// RGPD: anonymisation après 3 ans d'inactivité  → Business rule
// reduce() ici car perfs critiques sur 10k items → Non-obvious choice
// Voir ticket ABC-123 pour le contexte          → External reference
// HACK: contournement bug lib v2.3.1            → Known workaround
```

### Sur-ingénierie (red flags)

- Helper/util utilisé une seule fois
- Interface avec une seule implémentation sans justification
- Factory/Builder pour des objets simples
- Abstraction "au cas où"

### Messages de commit slop

❌ "Updated UserService to handle validation by changing the validateUser method to check email format"
✓ "Add email format validation to user registration"

❌ Commit avec diff dans le message
✓ Message décrivant l'intention, pas l'implémentation

---

## References

- [The Pragmatic Programmer Tips](https://pragprog.com/tips/)
- [99 Bottles of OOP - Sandi Metz](https://sandimetz.com/99bottles)
- [Pull Requests - Martin Fowler](https://martinfowler.com/bliki/PullRequest.html)
- [Refinement Code Review - Martin Fowler](https://martinfowler.com/bliki/RefinementCodeReview.html)
