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

## Сверх задания

- `tests/smoke.sh` — автоматическая проверка требований: редирект, health, лимит тела 413, rate limiting 429/503.
- CI для GitHub Actions и GitLab CI: shellcheck, проверка compose, gitleaks, подъём стека и smoke-тесты.
- Deploy — ручной запуск с approval через environment, по SSH и rsync. Реального сервера нет, джоба показывает схему промоута.
- `ops/sysctl/99-web-stack.conf` — тюнинг ядра Linux-хоста; применяется вручную, значения подбираются нагрузочным тестом.

## Что бы я сделал для production

- Сертификаты от ACME (Let's Encrypt) вместо self-signed.
- Docker secrets или Vault вместо `.env`.
- Закрепление образов по digest, сканирование образов Trivy в CI.
- Метрики: nginx exporter, postgres exporter, redis exporter, Prometheus и алерты.
- Бэкапы PostgreSQL с регулярной проверкой восстановления.

