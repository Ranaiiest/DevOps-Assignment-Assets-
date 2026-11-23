# Evidence & Verification Log

This document organizes all captured screenshots from `./screenshots/` by assignment part, summarizing what each screenshot verifies.

### Quick Evidence Checklist (from Task PDF)
- [x] **Part 1:** Outside-VPN (`filtered`) vs. Inside-VPN (`22`, `443` open) `nmap` scan
- [ ] **Part 1:** Revoked `dev1` failing VPN handshake while `dev2` stays connected *(capture terminal screenshot if needed)*
- [x] **Part 2:** GitLab admin settings (public sign-up disabled, 2FA enforced, private default visibility)
- [x] **Part 2:** Groups (`company` → `team-web`, `team-mobile`), 4 role users, HTTPS/SSH clone, MR merge
- [x] **Part 2:** Rejected direct push to protected `main` by Developer (`carol-dev`)
- [x] **Part 3:** Group Runner online + passing 4-stage pipeline (`lint`, `test`, `build`, `gitleaks_scan`)
- [ ] **Part 3:** `build_job` log showing `[MASKED]` variable *(click `build_job` in Pipeline #2 to capture)*
- [x] **Part 4:** SSH `ProxyJump` tunnel reaching `localhost`-only Prometheus (`localhost:9090`)
- [x] **Part 6:** Daily backup + config/secrets archive copied off-machine to `vpn-gw`
- [ ] **Part 6:** Restored fresh GitLab instance *(postponed)*

---

## Part 1 — Private Network & VPN Isolation

### 1. Outside-VPN vs. Inside-VPN `nmap` Port Scan
<img src="screenshots/Screenshot 2026-11-23 at 1.18.50 AM.png" width="820"/>

- **What it shows:** Running `nmap -Pn -p 22,80,443,8080,9090 172.28.10.10` from `client` with WireGuard **down** returns all 5 ports as `filtered` (0 reachable). After bringing up `dev2` (`172.28.20.3`), the exact same scan shows **only `22/tcp` (SSH) and `443/tcp` (HTTPS)** as `open`, while `80`, `8080`, and `9090` remain `filtered`.

---

## Part 2 — GitLab Installation, Access Control & Protected Branches

### 2. Public Sign-Up Disabled
<img src="screenshots/Screenshot 2026-11-23 at 12.32.50 AM.png" width="820"/>

- **What it shows:** GitLab **Admin Area → Settings → General → New user account restrictions** with **Allow new user accounts** unchecked, blocking public self-registration.

### 3. Two-Factor Authentication (2FA) Enforced
<img src="screenshots/Screenshot 2026-11-23 at 12.33.14 AM.png" width="820"/>

- **What it shows:** GitLab **Sign-in restrictions** with **Enforce two-factor authentication** checked for all users.

### 4. Default Project, Snippet & Group Visibility Set to Private
<img src="screenshots/Screenshot 2026-11-23 at 12.35.59 AM.png" width="820"/>

- **What it shows:** **Visibility and access controls** configured so **Default project visibility**, **Default snippet visibility**, and **Default group visibility** are all locked to **Private**.

### 5. Top-Level `company` Group & Team Subgroups
<img src="screenshots/Screenshot 2026-11-23 at 12.49.21 AM.png" width="820"/>

- **What it shows:** The private top-level group **`company`** containing the two private subgroups **`team-web`** and **`team-mobile`**.

### 6. Four Role-Based Users Created
<img src="screenshots/Screenshot 2026-11-23 at 1.16.42 AM.png" width="820"/>

- **What it shows:** All four users created in **Admin Area → Users**: `alice-owner`, `bob-maintainer`, `carol-dev`, and `dave-reporter` (`@company.local`).

### 7. Group Memberships & RBAC Roles Assigned
<img src="screenshots/Screenshot 2026-11-23 at 2.29.42 AM.png" width="820"/>

- **What it shows:** **Manage → Members** on `company` confirming `alice-owner` (**Owner**), `bob-maintainer` (**Maintainer**), `carol-dev` (**Developer**), and `dave-reporter` (**Reporter**).

### 8. Developer SSH Keygen + HTTPS & SSH `git clone` Over VPN
<img src="screenshots/Screenshot 2026-11-23 at 3.10.12 AM.png" width="820"/>

- **What it shows:** On `client` with `dev1` WireGuard active (`latest handshake: 55 seconds ago`), `carol` generates an `ed25519` SSH keypair and successfully clones `company/team-web/web-app.git` over both **HTTPS** (`web-app-https`) and **SSH** (`web-app-ssh`).

### 9. Rejected Direct Push to Protected `main` by Developer (`carol-dev`)
<img src="screenshots/Screenshot 2026-11-23 at 3.14.29 AM.png" width="820"/>

- **What it shows:** `carol` commits `app.sh` on `main` and runs `git push -u origin main`, which GitLab rejects (`! [remote rejected] main -> main (pre-receive hook declined)` — protected branch policy enforced).

### 10. Initial Empty-Repo Protection Behavior (Before `README.md`)
<img src="screenshots/Screenshot 2026-11-23 at 3.25.02 AM.png" width="820"/>

- **What it shows:** Attempting `git push -u origin feat/sample-app` while `web-app` had 0 commits also gets rejected until a Maintainer/Owner initializes `main` with `README.md`.

### 11. Rebase & Feature Branch Push (`feat/sample-app`) Succeeds
<img src="screenshots/Screenshot 2026-11-23 at 3.36.28 AM.png" width="820"/>

- **What it shows:** After initializing `main` with `README.md`, `carol` pulls `main`, rebases `feat/sample-app`, and successfully pushes `feat/sample-app` to GitLab (`* [new branch] feat/sample-app -> feat/sample-app`).

### 12. Feature Branch Files Visible in GitLab UI
<img src="screenshots/Screenshot 2026-11-23 at 3.35.57 AM.png" width="820"/>

- **What it shows:** `web-app` UI on `feat/sample-app` displaying `README.md` and `app.sh` authored by `carol-dev`, with the **Create merge request** banner.

### 13. Merge Request `!1` Opened by Developer (`carol-dev`)
<img src="screenshots/Screenshot 2026-11-23 at 3.38.57 AM.png" width="820"/>
<img src="screenshots/Screenshot 2026-11-23 at 3.39.38 AM.png" width="820"/>

- **What it shows:** `carol-dev` opens Merge Request `!1` (`feat: add sample app script into app.sh` from `feat/sample-app` into `main`).

### 14. Merge Request `!1` Ready to Merge by Maintainer (`bob-maintainer`)
<img src="screenshots/Screenshot 2026-11-23 at 3.47.07 AM.png" width="820"/>
<img src="screenshots/Screenshot 2026-11-23 at 3.47.27 AM.png" width="820"/>

- **What it shows:** Signed in as `bob-maintainer` (**Maintainer**), the **Merge** button is enabled and ready to merge `feat/sample-app` into protected `main`.

---

## Part 3 — CI/CD Runner, Pipeline & Secret Scanning

### 15. Private Group Docker Runner Online
<img src="screenshots/Screenshot 2026-11-23 at 4.43.05 AM.png" width="820"/>

- **What it shows:** **Groups → `company` → Build → Runners** showing runner `#1 (MldtDAek)` **Online (Idle)** on `172.28.10.10`.

### 16. Merge Request `!2` Adding `.gitlab-ci.yml`
<img src="screenshots/Screenshot 2026-11-23 at 5.25.23 AM.png" width="820"/>
<img src="screenshots/Screenshot 2026-11-23 at 5.29.36 AM.png" width="820"/>

- **What it shows:** `carol-dev` opens MR `!2` (`ci: added 3-stage pipeline with masked variable and gitleaks`), triggering Pipeline `#1` on `feat/ci-pipeline` before merging into `main`.

### 17. Pipeline `#2` Pending Before Removing Duplicate `config.toml` Key
<img src="screenshots/Screenshot 2026-11-23 at 5.37.13 AM.png" width="820"/>

- **What it shows:** Pipeline `#2` on `main` initially stayed in `Pending` due to a duplicate `tls_verify = false` line in `/etc/gitlab-runner/config.toml`.

### 18. Runner Service Fixed & Actively Polling Jobs
<img src="screenshots/Screenshot 2026-11-23 at 5.45.11 AM.png" width="820"/>

- **What it shows:** After removing the duplicate line and restarting `gitlab-runner`, `sudo systemctl status gitlab-runner` confirms **`Active: active (running)`** and logs show `Checking for jobs... received` and `Submitting job to coordinator... ok`.

### 19. Pipeline `#2` Passed All 4 Stages (`lint`, `test`, `build`, `secret_scan`)
<img src="screenshots/Screenshot 2026-11-23 at 5.44.39 AM.png" width="820"/>

- **What it shows:** Pipeline `#2` on `main` **Passed** in 17 seconds across all 4 stages: `lint_job`, `test_job`, `build_job`, and `gitleaks_scan` (running 100% offline using pre-cached `alpine:latest` and `zricethezav/gitleaks:latest`).

---

## Part 4 — SSH `ProxyJump` Tunneling

### 20. `localhost`-Only Prometheus Accessed via `ProxyJump` Tunnel
<img src="screenshots/Screenshot 2026-11-23 at 6.06.59 AM.png" width="820"/>

- **What it shows:** GitLab's bundled **Prometheus** (bound strictly to `127.0.0.1:9090` on `gitlab`) loaded in the Mac browser at `http://localhost:9090/query` through `ssh -N -J devops@192.168.64.2 -L 9090:127.0.0.1:9090 devops@172.28.10.10`.

---

## Part 6 — Backup & Off-Machine Storage

### 21. Daily Application & Config/Secrets Backups Copied to `vpn-gw`
<img src="screenshots/Screenshot 2026-11-23 at 6.33.56 AM.png" width="820"/>

- **What it shows:** `ls -lh /var/backups/gitlab/` on `vpn-gw` confirming both the GitLab application backup (`1795395550_2026_11_23_19.6.1_gitlab_backup.tar`, `950K`) and the separate config/secrets archive (`gitlab-config-2026-11-23_0058.tar.gz`, `56K`) were copied off-machine.
