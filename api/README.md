# Numia API — Deploy

Backend en Go. Se despliega con Docker Compose (Postgres + migraciones + API + Caddy).

## Requisitos en el VPS

- Docker y Docker Compose
- Puertos `80` y `443` libres (Caddy)

## Variables de entorno

Crear un archivo `.env` en esta carpeta (`api/`) a partir de `.env.example`:

```bash
cp .env.example .env
```

| Variable | Descripción |
|----------|-------------|
| `DB_USER` | Usuario de Postgres |
| `DB_PASSWORD` | Contraseña de Postgres (cambiar en producción) |
| `DB_NAME` | Nombre de la base de datos |
| `JWT_SECRET` | Secreto para firmar JWT (mínimo 64 caracteres para HS256) |
| `GROQ_API_KEY` | API key de Groq (coach AI) |

El `.env` está gitignoreado: créalo manualmente en el server, no se versiona.

## Desplegar

Desde la carpeta `api/`:

```bash
cd api
docker compose up -d --build
```

Esto levanta cuatro servicios:

- **db** — Postgres 16 (volumen `pgdata`, expuesto solo en `127.0.0.1:5433`)
- **migrate** — aplica las migraciones de `internal/database/migrations` y termina
- **api** — el binario Go en `127.0.0.1:8080` (arranca tras migrar)
- **caddy** — reverse proxy en los puertos `80`/`443` hacia `api:8080`

## Operación

```bash
# Ver estado
docker compose ps

# Ver logs (todos o un servicio)
docker compose logs -f
docker compose logs -f api

# Reiniciar
docker compose restart api

# Detener
docker compose down

# Detener y borrar datos (CUIDADO: elimina la base de datos)
docker compose down -v
```

## Actualizar a la última versión

```bash
git pull
cd api
docker compose up -d --build
```

Las migraciones se aplican automáticamente al levantar (servicio `migrate`).

## Dominio y HTTPS

Caddy está configurado para HTTP (`:80`) en `Caddyfile`. Para HTTPS automático,
reemplaza `:80` por tu dominio:

```caddyfile
api.tudominio.com {
    reverse_proxy api:8080
}
```

Caddy obtiene y renueva el certificado TLS automáticamente (requiere que el dominio
apunte al VPS y los puertos `80`/`443` accesibles).

## Desarrollo local

```bash
cd api
go run ./cmd/api
```
