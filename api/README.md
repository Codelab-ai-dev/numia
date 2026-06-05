# Numia API — Deploy

Backend en Go. Dos métodos de deploy:

- **Opción A — Docker Compose manual:** levanta todo con el `docker-compose.yml`
  (Postgres + migraciones + API + Caddy para proxy/TLS).
- **Opción B — Coolify:** usa `docker-compose.coolify.yml` (sin Caddy); el proxy y
  TLS los maneja Coolify/Traefik.

En ambos casos necesitas las mismas variables de entorno.

## Requisitos en el VPS

- Docker y Docker Compose
- Para la Opción A: puertos `80` y `443` libres (Caddy)

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

## Opción A — Docker Compose manual

Desde la carpeta `api/`:

```bash
cd api
docker compose up -d --build
```

Esto levanta tres servicios:

- **db** — Postgres 16 (volumen `pgdata`, expuesto solo en `127.0.0.1:5433`)
- **api** — el binario Go en `127.0.0.1:8080`. Aplica las migraciones automáticamente
  al arrancar (entrypoint) y luego inicia el servidor.
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

Las migraciones se aplican automáticamente al arrancar la API (entrypoint del contenedor).

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

## Opción B — Coolify

Usa `docker-compose.coolify.yml`, que NO incluye Caddy ni publica puertos al host:
el reverse proxy y el TLS los maneja Coolify (Traefik).

En la UI de Coolify:

1. Crea un recurso tipo **Docker Compose** apuntando a este repositorio.
2. **Base Directory** = `api` (es un monorepo).
3. **Compose file** = `docker-compose.coolify.yml`.
4. En **Environment Variables** define: `DB_USER`, `DB_PASSWORD`, `DB_NAME`,
   `JWT_SECRET`, `GROQ_API_KEY` (las mismas de la tabla de arriba).
5. Asigna tu **dominio al servicio `api`** (puerto `8080`). Coolify genera los labels
   de Traefik y el certificado TLS automáticamente.

El `build: .` se resuelve relativo al compose, es decir `api/`, así que el `Dockerfile`
se construye correctamente. Las migraciones corren solas al arrancar la API (entrypoint).

Para actualizar, Coolify redepliega al hacer push (o manualmente con el botón **Deploy**).

## Desarrollo local

```bash
cd api
go run ./cmd/api
```
