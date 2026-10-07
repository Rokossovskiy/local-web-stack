# Local web stack: Nginx + backend + PostgreSQL 15 + Redis

Nginx (:443, TLS termination, rate limit) → backend (:8080) → PostgreSQL / Redis.
Postgres и Redis находятся во внутренней сети и не публикуются на хост.

## Запуск

```bash
cp .env.example .env        # задать свои пароли
./gen-certs.sh              # self-signed сертификат в nginx/certs
docker compose up -d        # старт в порядке healthcheck-зависимостей
docker compose ps           # все сервисы должны быть healthy
curl -k https://localhost/  # ответ backend с X-Forwarded-* заголовками
```

## Проверки

```bash
# Readiness: доступность Postgres и Redis
curl -k https://localhost/readyz

# Rate limit: часть ответов должна быть 429
seq 60 | xargs -P 60 -I{} curl -sk -o /dev/null -w "%{http_code}\n" https://localhost/ | sort | uniq -c

# Лимит тела: 11 МБ → 413
head -c 11000000 /dev/zero | curl -sk -o /dev/null -w "%{http_code}\n" --data-binary @- https://localhost/

# Редирект HTTP → HTTPS
curl -sI http://localhost/ | head -n 1
```

## Остановка

```bash
docker compose down        # данные в volumes сохраняются
docker compose down -v     # полная очистка
```

## Ограничения и что изменить для production

- Сертификат self-signed. В проде нужен Let's Encrypt через certbot или cert-manager, а также HSTS.
- Секреты лежат в `.env`. В проде их лучше хранить в Vault или Docker/K8s secrets.
- На Docker Desktop все запросы приходят с IP шлюза, поэтому лимит общий. За балансировщиком нужен `real_ip_header` с `set_real_ip_from`.
- Ещё стоит добавить лимиты CPU и памяти, централизованные логи и бэкапы Postgres.

