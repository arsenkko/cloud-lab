# cloud-lab

REST API (Flask + PostgreSQL), розгорнутий в Azure Container Apps через Terraform,
з автомасштабуванням, моніторингом, email-алертами та кешем.

## Структура
- `app.py`, `Dockerfile`, `compose.yaml`, `requirements.txt`: застосунок і локальний запуск
- `infra/`: Terraform (реєстр образів, PostgreSQL, Container App з автомасштабуванням, дашборд, алерти)
- `loadtest/script.js`: навантажувальний тест k6
- `docs/`: документація до лабораторної
  - [AUTOSCALING.md](docs/AUTOSCALING.md): політика масштабування, дашборд, затримки
  - [LOADTEST.md](docs/LOADTEST.md): сценарій і результати тесту
  - [ALERTS.md](docs/ALERTS.md): email-алерти
  - [CACHE.md](docs/CACHE.md): кеш і порівняння

## API
`GET /health`, `POST /users`, `GET /users/{id}`, `POST /posts`, `GET /posts`, `GET /posts/{id}`

## Локальний запуск
1. Створи файл `.env` з рядком `POSTGRES_PASSWORD=<будь-який пароль>` (він не потрапляє в репозиторій).
2. `docker compose up --build`
3. API на `http://localhost:8000`.

## Розгортання в Azure
Потрібні: Azure CLI (`az login`), Terraform, Docker.

1. У `infra/terraform.tfvars` (файл не в репозиторії) задай:
   ```
   subscription_id = "<id підписки>"
   alert_email     = "<пошта для алертів>"
   ```
2. Створи реєстр образів:
   ```
   cd infra
   terraform init
   terraform apply -target=azurerm_container_registry.acr
   ```
3. Збери і відправ образ (з кореня проєкту):
   ```
   az acr login --name <ім'я реєстру>
   docker build -t <ім'я реєстру>.azurecr.io/cloud-lab-api:v3 .
   docker push <ім'я реєстру>.azurecr.io/cloud-lab-api:v3
   ```
4. Створи решту інфраструктури: `terraform apply` (адреса сервісу буде у виводі `app_url`).
5. Кеш: `terraform apply -var "cache_ttl=30"` (0 = вимкнено).

## Навантажувальний тест
```
k6 run -e BASE_URL=<app_url> -e VUS=40 loadtest/script.js
```
Параметри та результати: [docs/LOADTEST.md](docs/LOADTEST.md).

## Безпека
Секрети (пароль бази, ID підписки, пошта) у репозиторій не потрапляють: пароль
бази генерується Terraform і передається застосунку як секрет Container Apps,
файли `*.tfvars`, `*.tfstate` і `.env` ігноруються через `.gitignore`.
Застосунок отримує образ із реєстру через керовану ідентичність (без паролів).

## Прибирання
Щоб не витрачати кошти: `cd infra && terraform destroy`.