# ── Stage 1: Build ────────────────────────────────────────────────────────────
# Produces /app/dist — a fully-static Astro site.
FROM node:20-alpine AS builder

WORKDIR /app

# Layer-cache deps separately from source so they only reinstall when
# package-lock.json changes, not on every source edit.
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .
RUN npm run build


# ── Stage 2: Serve ────────────────────────────────────────────────────────────
# nginx:alpine ships at ~23 MB; final image stays well under 30 MB.
FROM nginx:1.27-alpine AS production

LABEL maintainer="Abdou Valerio Foma Kenfack" \
      org.opencontainers.image.title="avfk-portfolio" \
      org.opencontainers.image.description="Static Astro portfolio served by nginx" \
      org.opencontainers.image.source="https://github.com/FKAV64"

# Remove the default virtual-host that ships inside the image.
RUN rm /etc/nginx/conf.d/default.conf

# Bring in our custom config and the compiled site.
COPY nginx.conf              /etc/nginx/nginx.conf
COPY --from=builder /app/dist /usr/share/nginx/html

# SIGTERM triggers a fast shutdown; SIGQUIT tells nginx to drain
# in-flight requests first — the correct signal for rolling deploys.
STOPSIGNAL SIGQUIT

# Built-in healthcheck for plain `docker run` usage (no Compose required).
# docker-compose.yml has its own richer healthcheck block.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD wget -qO /dev/null http://localhost/health || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
