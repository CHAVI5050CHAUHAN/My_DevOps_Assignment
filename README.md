# Docker + Jenkins + Scripts Setup

## What is included
- `docker-compose.yml`: Nginx 1.25, PHP-FPM 7.3, phpMyAdmin, MySQL 8.0
- `Jenkinsfile`: CI/CD pipeline to pull code, build, and deploy with Docker Compose
- `scripts/extract_unique_ips.sh`: Extract unique IPs from Nginx/Apache logs
- `scripts/mysql_backup_to_s3.sh`: Backup MySQL and upload to S3
- `.env.example`: Environment variable template

## Prerequisites
1. Docker and Docker Compose v2 (`docker compose`)
2. Jenkins with a Linux agent that has Docker access
3. AWS CLI configured for S3 upload (`aws configure`)
4. `mysqldump` client installed where backup script runs
5. Bash shell (Linux/macOS/WSL/Git Bash)

## Initial setup
1. Copy env file:
   - `cp .env.example .env`
2. Edit `.env` with your real passwords and S3 path.
3. Start stack:
   - `docker compose up -d`
4. Check services:
   - `docker compose ps`

## Access URLs
- App/Nginx: `http://localhost:${NGINX_PORT}`
- phpMyAdmin: `http://localhost:${PHPMYADMIN_PORT}`

## Jenkins Pipeline notes
- Put this repository in a Jenkins Pipeline job.
- The provided `Jenkinsfile` will:
  1. Pull latest code
  2. Build images (`docker compose build --pull`)
  3. Deploy containers (`docker compose up -d`)
  4. Save recent compose logs as build artifact

## Script usage
### Extract unique IPs
- `bash scripts/extract_unique_ips.sh /var/log/nginx/access.log`
- `bash scripts/extract_unique_ips.sh /var/log/nginx /var/log/apache2/error.log`
- If no argument is passed, common default log paths are checked.

### MySQL backup and upload to S3
Run with env vars (or load from `.env`):

```bash
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_USER=app_user
export DB_PASSWORD=your_password
export DB_NAME=app_db
export S3_URI=s3://your-bucket/mysql-backups
export AWS_REGION=ap-south-1

bash scripts/mysql_backup_to_s3.sh
```

Optional env vars:
- `BACKUP_DIR` (default `./backups`)
- `FILE_PREFIX` (default `mysql_backup`)
- `RETENTION_DAYS` (delete old local backup files)

## Optional executable permission
On Linux/macOS/WSL:
- `chmod +x scripts/extract_unique_ips.sh scripts/mysql_backup_to_s3.sh`
