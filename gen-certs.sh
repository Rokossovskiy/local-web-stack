#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="$(cd "$(dirname "$0")" && pwd)/nginx/certs"
DOMAIN="${1:-localhost}"
DAYS="${DAYS:-365}"

mkdir -p "$CERT_DIR"

# Не перезаписываем существующий сертификат без FORCE=1
if [[ -f "$CERT_DIR/server.crt" && "${FORCE:-0}" != "1" ]]; then
  echo "Сертификат уже есть: $CERT_DIR (FORCE=1 для перевыпуска)"
  exit 0
fi

# SAN обязателен: современные браузеры и curl не смотрят на CN
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days "$DAYS" \
  -keyout "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.crt" \
  -subj "/CN=$DOMAIN" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,IP:127.0.0.1"

chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"

openssl x509 -in "$CERT_DIR/server.crt" -noout -subject -enddate -ext subjectAltName

