# Security & Troubleshooting Notes (Part 4)

> **Scope Note:** Per project scope, this document covers **Part 4 (Tunneling & Troubleshooting)** written answers and the **Part 1 gateway firewall rules** implemented on `vpn-gw`. (Part 5 server hardening items were intentionally omitted from this build.)

---

## 1. When to Use an SSH Tunnel vs. a VPN

Both an **SSH tunnel** and a **VPN** encrypt traffic over an untrusted network, but they solve different operational problems:

| Aspect | SSH Tunnel (`ssh -L` / `ProxyJump`) | VPN (WireGuard `wg0`) |
| :--- | :--- | :--- |
| **Network Scope** | **Single TCP port** forwarded on demand (e.g., `localhost:9090 -> 127.0.0.1:9090`). | **Full Layer-3 subnet routing** across multiple hosts and ports (`443`, `22`). |
| **Setup & Client** | Uses existing OpenSSH client; no extra VPN software or admin privileges needed. | Requires WireGuard/OpenVPN client profiles and key distribution per user. |
| **Access to `localhost`** | **Can** reach services bound strictly to `127.0.0.1` on the target host. | **Cannot** reach `127.0.0.1`-only services without opening firewall/bind addresses. |
| **Best Use Case** | Temporary admin debugging of internal dashboards (Prometheus, DB admin UIs) without exposing ports. | Day-to-day developer access to GitLab Web (`443`) and Git SSH (`22`) with centralized peer revocation. |

**Rule of thumb:**
- Use a **VPN** for **everyday team access** to private services (`gitlab` over `443` and `22`) where you need per-user identity, split-tunneling, and fast single-user revocation.
- Use an **SSH tunnel (`ProxyJump`)** for **ad-hoc admin maintenance**—especially when reaching a sensitive service bound strictly to `127.0.0.1` (like bundled Prometheus on `127.0.0.1:9090`) so that port never needs to be exposed on the network or opened in the firewall.

---

## 2. Troubleshooting: "GitLab Web Page Opens Over VPN, but `git clone` Over SSH Hangs"

Because the **GitLab web page (`443`) already opens over VPN**, we immediately know three things are working:
1. The WireGuard tunnel (`dev1`/`dev2` ↔ `vpn-gw`) is up and routing packets.
2. `gitlab.company.local` resolves to `172.28.10.10`.
3. `vpn-gw` is forwarding packets to `gitlab` on the private `Host Only` switch.

Therefore, a **hanging** (not "connection refused" or "permission denied") `git clone` over SSH means **port `22` TCP packets are being silently dropped or misrouted**. Run these checks in order:

1. **Test raw TCP connectivity to port `22` from `client`:**
   ```bash
   nc -zv -w 3 gitlab.company.local 22
   # or
   ssh -vvv -T git@gitlab.company.local
   ```
   Confirms whether the hang happens before the TCP handshake (firewall drop) or during the SSH handshake.

2. **Check `vpn-gw`'s `ufw` forwarding rule for port `22`:**
   ```bash
   sudo ufw status numbered
   ```
   Verify a `route allow` rule exists for `in on wg0 out on enp0s2` to `172.28.10.10 port 22 proto tcp` (just like port `443`). A missing rule causes `default deny routed` to silently drop port `22` packets—which looks like a hang.

3. **Check `gitlab`'s host firewall (if enabled) and `sshd` listening address:**
   ```bash
   sudo ss -tlnp | grep :22
   sudo systemctl status ssh
   ```
   Confirm `sshd` is running and listening on `0.0.0.0:22` or `172.28.10.10:22` (not `127.0.0.1:22`).

4. **Verify routing & return path on `gitlab`:**
   ```bash
   ip route show
   ```
   Confirm `gitlab`'s default gateway points back to `vpn-gw` (`default via 172.28.10.1`), otherwise SYN-ACK replies from port `22` cannot return through the VPN.

5. **Check WireGuard MTU / packet fragmentation (if `ssh -vvv` connects but hangs after `expecting SSH2_MSG_KEX_ECDH_REPLY`):**
   Large SSH key-exchange packets can stall if MTU is too high across nested tunnels; test lowering `MTU = 1280` or `1380` in the WireGuard interface config.

6. **Verify `gitlab-shell` and SSH key permissions (if SSH connects but stalls at auth):**
   Check `/var/log/auth.log` and `/var/log/gitlab/gitlab-shell/gitlab-shell.log` on `gitlab` to ensure the `git` user and `~/.ssh/authorized_keys` are functioning cleanly.
