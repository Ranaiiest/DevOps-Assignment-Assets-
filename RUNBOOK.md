# Handover Runbook — Private GitLab & WireGuard VPN

This runbook provides step-by-step operational procedures for managing, troubleshooting, and upgrading the private GitLab environment (`vpn-gw` + `gitlab` + `client`).

---

## 1. Onboarding a New Developer

### A. Create WireGuard VPN Profile (`vpn-gw` & Developer Machine)
1. On the developer's machine (or `client`), generate a dedicated keypair (never share keys):
   ```bash
   wg genkey | sudo tee /etc/wireguard/dev3_private.key | wg pubkey | sudo tee /etc/wireguard/dev3_public.key
   sudo chmod 600 /etc/wireguard/dev3_private.key
   ```
2. On `vpn-gw`, assign the next unused VPN IP (e.g., `172.28.20.4/32`) in `/etc/wireguard/wg0.conf`:
   ```ini
   [Peer]
   # dev3
   PublicKey = <DEV3_PUBLIC_KEY>
   AllowedIPs = 172.28.20.4/32
   ```
3. Apply live without interrupting existing users:
   ```bash
   sudo wg set wg0 peer <DEV3_PUBLIC_KEY> allowed-ips 172.28.20.4/32
   ```
4. Provide `/etc/wireguard/dev3.conf` (`AllowedIPs = 172.28.20.0/24, 172.28.10.0/24`, `Endpoint = <VPN_GW_IP>:51820`) and map `172.28.10.10 gitlab.company.local` in `/etc/hosts`.
   *(Note: Because `ufw` already allows `172.28.20.0/24` to `172.28.10.10` ports `443` and `22`, no new firewall rule is needed for a developer.)*

### B. Provision GitLab Account & Group Access
1. Sign in to GitLab as an Admin (`root` or `alice`).
2. **Admin Area → Overview → Users → New user** → create the account with their company email (`@company.local`).
3. Navigate to **Groups → `company`** (or the specific team subgroup `team-web` / `team-mobile`) → **Manage → Members → Invite members** and assign **Developer** (or **Reporter**) role.
4. Instruct the developer to sign in over VPN, enroll **2FA** immediately, add their SSH public key (**Preferences → SSH Keys**), and create a Personal Access Token if using HTTPS Git.

---

## 2. Offboarding a Developer Who Has Left

Remove access across **every** layer immediately:
1. **VPN Access (`vpn-gw`):**
   - Remove the live peer immediately:
     ```bash
     sudo wg set wg0 peer <USER_PUBLIC_KEY> remove
     ```
   - Delete their `[Peer]` block from `/etc/wireguard/wg0.conf` so it stays revoked across reboots.
2. **GitLab Account (`gitlab` Web UI):**
   - **Admin Area → Overview → Users → `<user>` → Block** (or **Delete user** after transferring any needed MRs/issues).
   - Revoke all active **Personal Access Tokens**, **SSH Keys**, and active sessions on the user's profile.
   - Remove from `company` / `team-web` / `team-mobile` group memberships.
3. **Server SSH (if the user had admin access):**
   - Remove their public key from `~/.ssh/authorized_keys` on both `vpn-gw` and `gitlab`, and remove their `172.28.20.10` `ufw` SSH rule on `vpn-gw` if applicable.

---

## 3. VPN Is Down and Nobody Can Reach GitLab

1. **Check `vpn-gw` power & reachability:**
   - Ping `vpn-gw`'s outer IP (`192.168.64.2`) or open its UTM console.
2. **Check WireGuard service & interface on `vpn-gw`:**
   ```bash
   sudo systemctl status wg-quick@wg0
   sudo wg show
   ```
   If down, restart it:
   ```bash
   sudo systemctl restart wg-quick@wg0
   ```
3. **Verify IP forwarding & firewall:**
   ```bash
   sysctl net.ipv4.ip_forward          # Must be 1
   sudo ufw status numbered            # Confirm 51820/udp IN and 443,22 FWD rules exist
   ```
4. **Verify private-subnet link (`enp0s2`):**
   ```bash
   ip -br a                            # Confirm enp0s2 is UP on 172.28.10.1/24
   ping -c 3 172.28.10.10              # Confirm gitlab is reachable from vpn-gw
   ```

---

## 4. GitLab Shows a `502` Error After a Reboot

A `502 Bad Gateway` means Nginx is running, but **Puma** (the GitLab Rails app server) hasn't finished starting or crashed due to memory/socket issues.
1. **Wait 60–90 seconds** after boot—Puma and Sidekiq take ~1 minute to warm up on 4 GB RAM.
2. **Check service statuses on `gitlab`:**
   ```bash
   sudo gitlab-ctl status
   ```
3. **Check memory/swap and Puma logs:**
   ```bash
   free -h                             # Confirm 2 GB swap is active
   sudo gitlab-ctl tail puma           # Look for OOM or socket errors
   ```
4. **Restart GitLab services cleanly if needed:**
   ```bash
   sudo gitlab-ctl restart
   ```

---

## 5. Disk on the GitLab Server Is Full

1. **Identify what filled the disk on `gitlab`:**
   ```bash
   df -h
   sudo du -xhd 1 /var/opt/gitlab | sort -h
   sudo du -xhd 1 /var/log/gitlab | sort -h
   ```
2. **Safe immediate cleanup:**
   - Remove old local backup archives (already copied to `vpn-gw`):
     ```bash
     sudo ls -lh /var/opt/gitlab/backups/
     sudo rm -f /var/opt/gitlab/backups/<older_backup>.tar
     ```
   - Prune unused Docker containers/build cache (keep `alpine:latest` and `zricethezav/gitleaks:latest`):
     ```bash
     sudo docker container prune -f
     ```
   - Truncate oversized logs or clean `apt` cache:
     ```bash
     sudo apt clean
     sudo journalctl --vacuum-time=7d
     ```
3. **Long-term fix:** Expand the virtual disk in UTM (**Resize...**) and run `growpart`, `pvresize`, `lvextend`, and `resize2fs`, or set `gitlab_rails['backup_keep_time'] = 604800` (7 days) in `/etc/gitlab/gitlab.rb`.

---

## 6. TLS Certificate Is About to Expire

1. **Check current expiry date:**
   ```bash
   openssl x509 -in /etc/gitlab/ssl/gitlab.company.local.crt -noout -dates
   ```
2. **Generate a fresh self-signed certificate (valid 365 days) on `gitlab`:**
   ```bash
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/gitlab/ssl/gitlab.company.local.key \
     -out /etc/gitlab/ssl/gitlab.company.local.crt \
     -subj "/CN=gitlab.company.local" \
     -addext "subjectAltName=DNS:gitlab.company.local,IP:172.28.10.10"
   sudo chmod 600 /etc/gitlab/ssl/gitlab.company.local.key
   ```
3. **Reload Nginx without downtime:**
   ```bash
   sudo gitlab-ctl hup nginx
   ```
4. **Update Runner CA trust:** Restart `gitlab-runner` (`sudo gitlab-runner restart`) if `/etc/gitlab/ssl/gitlab.company.local.crt` changed.

---

## 7. Upgrading GitLab to a Newer Version Safely

1. **Check the official GitLab upgrade path** (never skip required intermediate versions—major/minor stops matter for DB migrations).
2. **Take a fresh full backup + config/secrets backup first:**
   ```bash
   sudo /usr/local/bin/gitlab-backup.sh
   ```
3. **Verify background migrations are complete** in **Admin Area → Monitoring → Background Migrations** (must be 0 pending).
4. **Temporarily attach internet** (or download the target `.deb` package and copy via `vpn-gw`) and upgrade:
   ```bash
   sudo apt update
   sudo apt install -y gitlab-ce=<TARGET_VERSION>
   ```
5. **Verify health after upgrade:**
   ```bash
   sudo gitlab-ctl reconfigure
   sudo gitlab-ctl status
   sudo gitlab-rake gitlab:check SANITIZE=true
   ```
   Re-isolate `gitlab` on `Host Only` if internet was temporarily attached.
