#!/bin/bash
# /usr/local/bin/gitlab-backup.sh (on gitlab)
# Scheduled daily at 02:00 AM via root crontab:
# 0 2 * * * /usr/local/bin/gitlab-backup.sh >> /var/log/gitlab-backup.log 2>&1

set -euo pipefail
BACKUP_DIR="/var/opt/gitlab/backups"
CONF_ARCHIVE="/tmp/gitlab-config-$(date +%F_%H%M).tar.gz"

# 1. Application backup (PostgreSQL DB, Git repos, uploads, CI/CD variables)
gitlab-backup create STRATEGY=copy

# 2. Config & secrets backup (needed to decrypt 2FA & CI/CD variables on restore)
tar -czf "$CONF_ARCHIVE" /etc/gitlab/gitlab.rb /etc/gitlab/gitlab-secrets.json /etc/gitlab/ssl/

# 3. Copy both off-machine to vpn-gw:/var/backups/gitlab/
LATEST_APP=$(ls -t ${BACKUP_DIR}/*_gitlab_backup.tar | head -n 1)
scp -i /root/.ssh/backup_ed25519 -o StrictHostKeyChecking=no "$LATEST_APP" "$CONF_ARCHIVE" <BACKUP_USER>@172.28.10.1:/var/backups/gitlab/
rm -f "$CONF_ARCHIVE"
