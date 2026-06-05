# Diseño: Monorepo Numia

**Fecha:** 2026-06-05
**Estado:** Aprobado

## Objetivo

Unificar los dos repos independientes de Numia en un único monorepo, conservando la
historia de git de ambos:

- `numia` — app Flutter (rama `master`, sin remote)
- `numia-api` — backend Go (rama `master`, sin remote)

## Decisiones

| Tema | Decisión |
|------|----------|
| Historia git | Conservar ambas historias (vía `git subtree`) |
| Ubicación | Reusar el repo `numia` existente como raíz |
| Cambios WIP | Commitear los cambios pendientes en ambos repos antes de fusionar |

## Estructura final

```
numia/                    (repo git existente, conserva su historia)
  app/                    <- Flutter (todo el contenido actual movido aquí)
    android/ ios/ lib/ assets/ pubspec.yaml ... .gitignore
  api/                    <- Go (traído con git subtree, conserva su historia)
    cmd/ internal/ docs/ go.mod ... .gitignore
  docs/superpowers/       <- specs/planes de trabajo (se quedan en la raíz)
  .gitignore              <- nuevo, a nivel raíz (.DS_Store, etc.)
  README.md               <- nuevo, describe el monorepo
```

## Pasos de ejecución

1. **Commit WIP en `numia-api`** — commitear los cambios pendientes (budget/expenses,
   docker-compose, etc.) para que el subtree traiga la versión más reciente.
2. **Commit WIP en `numia`** — commitear el WIP de budget del Flutter.
3. **Mover Flutter a `app/`** — `git mv` de todo el contenido Flutter (android, ios, lib,
   assets, pubspec, analysis_options, `.gitignore`, etc.) dentro de `app/`. Excluir `.git`
   y `docs/superpowers` (se quedan en la raíz). Commit.
4. **Archivos raíz** — crear nuevo `.gitignore` raíz (`.DS_Store`, etc.) y `README.md` del
   monorepo. Commit.
5. **Traer `api/` con subtree** —
   `git remote add numia-api ../numia-api` y
   `git subtree add --prefix=api numia-api master`.
   Esto preserva toda la historia de Go reescrita bajo `api/`.

## Garantías

- La historia de ambos repos se conserva: los commits de Flutter quedan tal cual; los de Go
  quedan reescritos bajo `api/` vía subtree.
- El repo original `numia-api` queda intacto como backup (no se modifica salvo el commit WIP).
- `app/.gitignore` mantiene rutas relativas válidas al moverse junto con el código Flutter.
- `api/.gitignore` viene incluido en el subtree.

## Fuera de alcance

- Configurar remotes / push a un servidor remoto.
- CI/CD, scripts de build unificados, tooling de workspace.
- Eliminar el repo original `numia-api`.
