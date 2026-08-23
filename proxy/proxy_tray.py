#!/usr/bin/env python3
"""
Proxy Manager Tray — KDE Plasma 6

A system-tray application that manages two independent proxy modes:

  • Proxy   — KDE system proxy (kwriteconfig6 / kioslaverc)
  • Redsocks — transparent iptables-based proxy (/usr/local/sbin/proxyredsocks)

Tray icon colour key:
  🔵 Blue   → System proxy only
  🟢 Green  → Redsocks only
  🟣 Purple → Both active
  ⚫ Gray   → Everything off

Depends on:
  pystray, Pillow, kdialog, notify-send, kreadconfig6/kwriteconfig6
"""

import json
import os
import signal
import socket
import subprocess
import sys
import threading
import time

from PIL import Image, ImageDraw, ImageFont
import pystray
from pystray import MenuItem as item

# ── Paths & constants ──────────────────────────────────────────
PROXY_CMD = "/usr/local/sbin/proxyredsocks"
PROXIES_JSON = os.path.expanduser("~/.dotfiles/proxy/proxies.json")
PROXY_TXT = os.path.expanduser("~/.dotfiles/proxy/proxy.txt")
POLL_INTERVAL = 5  # seconds between background status checks
PROXY_PORT = "3128"

# Font search order (first hit wins)
FONT_CANDIDATES = [
    "/usr/share/fonts/google-noto/NotoSans-Bold.ttf",
    "/usr/share/fonts/google-noto/NotoSansMono-Bold.ttf",
    "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]

# ── Colour palette ─────────────────────────────────────────────
CLR_PROXY    = (41, 121, 255)      # Blue
CLR_REDSOCKS = (0, 200, 83)        # Green
CLR_BOTH     = (156, 39, 176)      # Purple
CLR_OFF      = (120, 120, 120)     # Gray
CLR_WHITE    = (255, 255, 255)


class ProxyManager:
    """Core tray application."""

    def __init__(self):
        self._running = True
        initial = self._initial_proxy()
        self.proxy_selection = dict(initial)       # for KDE system proxy
        self.redsocks_selection = dict(initial)     # for redsocks (independent)

    # ── Data helpers ───────────────────────────────────────────

    def _load_proxies(self):
        """Read proxy list from proxies.json, fallback to proxy.txt."""
        proxies = []
        try:
            with open(PROXIES_JSON, "r") as fh:
                data = json.load(fh)
                if isinstance(data, list) and data:
                    proxies = data
        except Exception:
            pass

        # Fallback: build entries from proxy.txt if proxies.json was empty
        if not proxies:
            try:
                with open(PROXY_TXT, "r") as fh:
                    for i, line in enumerate(fh, 1):
                        ip = line.strip()
                        if ip:
                            proxies.append({
                                "name": f"Proxy {i}",
                                "ip": ip,
                                "user": "edcguest",
                                "password": "edcguest",
                            })
            except Exception:
                pass

        return proxies

    def _initial_proxy(self):
        """Pick the first proxy from the list, or a sensible default."""
        proxies = self._load_proxies()
        if proxies:
            return proxies[0]
        return {
            "name": "Default",
            "ip": "172.16.x.x",
            "user": "edcguest",
            "password": "edcguest",
        }

    # ── Status queries ─────────────────────────────────────────

    def is_redsocks_on(self):
        """Return True when the redsocks systemd unit is active."""
        try:
            subprocess.check_call(
                ["systemctl", "is-active", "--quiet", "redsocks"],
                timeout=3,
            )
            return True
        except Exception:
            return False

    def redsocks_nat_rules_present(self):
        """
        Best-effort check for NAT redirection rules.

        Returns:
            True  -> REDSOCKS rules are present
            False -> redsocks is active, but the NAT rules are missing
            None  -> unable to inspect rules without prompting for credentials
        """
        try:
            r = subprocess.run(
                ["sudo", "-n", "iptables", "-t", "nat", "-S"],
                capture_output=True, text=True, timeout=5,
            )
            if r.returncode != 0:
                return None

            rules = r.stdout
            return (
                "-N REDSOCKS" in rules
                or "-A OUTPUT -p tcp -j REDSOCKS" in rules
                or "-A PREROUTING -p tcp -j REDSOCKS" in rules
            )
        except Exception:
            return None

    def redsocks_health(self):
        """
        Summarize redsocks state for UI display.

        Returns:
            "off", "on", "warn", or "unknown"
        """
        if not self.is_redsocks_on():
            return "off"

        rules_present = self.redsocks_nat_rules_present()
        if rules_present is True:
            return "on"
        if rules_present is False:
            return "warn"
        return "unknown"

    def is_proxy_on(self):
        """Return True when KDE system proxy is set to Manual (ProxyType=1)."""
        try:
            r = subprocess.run(
                [
                    "kreadconfig6", "--file", "kioslaverc",
                    "--group", "Proxy Settings", "--key", "ProxyType",
                ],
                capture_output=True, text=True, timeout=3,
            )
            return r.stdout.strip() == "1"
        except Exception:
            return False

    # ── Notifications ──────────────────────────────────────────

    @staticmethod
    def _notify(title, body, urgency="normal"):
        """Fire-and-forget desktop notification via notify-send."""
        try:
            subprocess.Popen(
                [
                    "notify-send",
                    "--app-name=Proxy Manager",
                    "--urgency", urgency,
                    "--icon", "network-vpn",
                    title,
                    body,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass

    # ── Icon rendering ─────────────────────────────────────────

    @staticmethod
    def _load_font(size):
        for path in FONT_CANDIDATES:
            if os.path.isfile(path):
                try:
                    return ImageFont.truetype(path, size)
                except Exception:
                    continue
        return ImageFont.load_default()

    def _render_icon(self):
        """Return a 64×64 RGBA image reflecting current state."""
        proxy = self.is_proxy_on()
        redsocks_health = self.redsocks_health()

        if proxy and redsocks_health == "on":
            bg, label = CLR_BOTH, "PR"
        elif redsocks_health == "warn":
            bg, label = (230, 126, 34), "!"
        elif redsocks_health == "unknown":
            bg, label = (127, 140, 141), "?"
        elif redsocks_health == "on":
            bg, label = CLR_REDSOCKS, "R"
        elif proxy:
            bg, label = CLR_PROXY, "P"
        else:
            bg, label = CLR_OFF, "–"

        w = h = 64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dc = ImageDraw.Draw(img)

        # Circle
        pad = 3
        dc.ellipse(
            (pad, pad, w - pad, h - pad),
            fill=bg,
            outline=(*CLR_WHITE, 200),
            width=2,
        )

        # Label text
        fsize = 20 if len(label) > 1 else 30
        font = self._load_font(fsize)
        bbox = dc.textbbox((0, 0), label, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        tx = (w - tw) // 2
        ty = (h - th) // 2 - bbox[1]
        dc.text((tx, ty), label, fill=(*CLR_WHITE, 255), font=font)

        return img

    def _tooltip(self):
        proxy = "ON" if self.is_proxy_on() else "OFF"
        redsocks_health = self.redsocks_health()
        if redsocks_health == "on":
            redsocks = "ON"
        elif redsocks_health == "warn":
            redsocks = "ON (NO NAT RULES)"
        elif redsocks_health == "unknown":
            redsocks = "ON (RULES UNKNOWN)"
        else:
            redsocks = "OFF"
        return (
            f"Proxy: {proxy} ({self.proxy_selection['ip']})  |  "
            f"Redsocks: {redsocks} ({self.redsocks_selection['ip']})"
        )

    # ── Actions: System Proxy ──────────────────────────────────

    def _enable_proxy(self, icon, _item):
        ip = self.proxy_selection["ip"]
        user = self.proxy_selection.get("user", "")
        passwd = self.proxy_selection.get("password", "")

        proxy_url = (
            f"http://{user}:{passwd}@{ip}:{PROXY_PORT}"
            if user
            else f"http://{ip}:{PROXY_PORT}"
        )

        settings = {
            "ProxyType": "1",
            "httpProxy": proxy_url,
            "httpsProxy": proxy_url,
            "ftpProxy": proxy_url,
            "NoProxyFor": "localhost,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16",
        }

        try:
            for key, val in settings.items():
                subprocess.run(
                    [
                        "kwriteconfig6", "--file", "kioslaverc",
                        "--group", "Proxy Settings", "--key", key, val,
                    ],
                    check=True, timeout=5,
                )
            self._notify(
                "Proxy ON",
                f"System proxy → {self.proxy_selection['name']} ({ip}:{PROXY_PORT})",
            )
        except Exception as exc:
            self._notify("Proxy Error", str(exc), "critical")

        self._refresh(icon)

    def _disable_proxy(self, icon, _item):
        try:
            subprocess.run(
                [
                    "kwriteconfig6", "--file", "kioslaverc",
                    "--group", "Proxy Settings", "--key", "ProxyType", "0",
                ],
                check=True, timeout=5,
            )
            # Ensure system-level files (DNF, NM) are also cleaned up
            subprocess.run(
                ["pkexec", PROXY_CMD, "cleanup"],
                capture_output=True, timeout=10,
            )
            self._notify("Proxy OFF", "System proxy disabled")
        except Exception as exc:
            self._notify("Proxy Error", str(exc), "critical")

        self._refresh(icon)

    def _toggle_proxy(self, icon, _item):
        if self.is_proxy_on():
            self._disable_proxy(icon, _item)
        else:
            self._enable_proxy(icon, _item)

    # ── Actions: Redsocks ──────────────────────────────────────

    def _enable_redsocks(self, icon, _item):
        ip = self.redsocks_selection["ip"]
        try:
            subprocess.run(
                ["pkexec", PROXY_CMD, "enable", ip],
                check=True, timeout=30,
            )
            self._notify(
                "Redsocks ON",
                f"Transparent proxy via {self.redsocks_selection['name']} ({ip})",
            )
        except Exception as exc:
            self._notify("Redsocks Error", str(exc), "critical")

        self._refresh(icon)

    def _disable_redsocks(self, icon, _item):
        try:
            subprocess.run(
                ["pkexec", PROXY_CMD, "disable"],
                check=True, timeout=30,
            )
            # Wait and verify the service actually stayed down
            time.sleep(3)
            if self.is_redsocks_on():
                # Service auto-restarted — force-stop it
                subprocess.run(
                    ["pkexec", PROXY_CMD, "disable"],
                    check=True, timeout=30,
                )
                self._notify("Redsocks OFF", "Service auto-restarted — force-stopped")
            else:
                self._notify("Redsocks OFF", "Transparent proxy disabled")
        except Exception as exc:
            self._notify("Redsocks Error", str(exc), "critical")

        self._refresh(icon)

    def _toggle_redsocks(self, icon, _item):
        if self.is_redsocks_on():
            self._disable_redsocks(icon, _item)
        else:
            self._enable_redsocks(icon, _item)

    # ── Actions: Change Proxy ──────────────────────────────────

    def _pick_proxy(self, title, current_selection):
        """
        Open a kdialog radiolist to pick a proxy or enter a custom IP.
        Returns the chosen proxy dict, or None if cancelled.
        """
        proxies = self._load_proxies()
        if not proxies:
            self._notify("No Proxies", "proxies.json is empty or missing", "critical")
            return None

        args = [
            "kdialog", "--title", title,
            "--radiolist", "Select a proxy server:",
        ]
        for p in proxies:
            tag = p["ip"]
            label = f"{p['name']}  ({p['ip']})"
            on = "on" if p["ip"] == current_selection["ip"] else "off"
            args.extend([tag, label, on])

        args.extend(["__custom__", "Enter custom IP…", "off"])

        try:
            r = subprocess.run(args, capture_output=True, text=True, timeout=120)
            if r.returncode != 0:
                return None  # cancelled

            choice = r.stdout.strip()

            if choice == "__custom__":
                r2 = subprocess.run(
                    [
                        "kdialog", "--title", "Custom Proxy IP",
                        "--inputbox", "Enter proxy IP address:",
                        current_selection["ip"],
                    ],
                    capture_output=True, text=True, timeout=120,
                )
                if r2.returncode != 0 or not r2.stdout.strip():
                    return None
                return {
                    "name": "Custom",
                    "ip": r2.stdout.strip(),
                    "user": "edcguest",
                    "password": "edcguest",
                }
            else:
                for p in proxies:
                    if p["ip"] == choice:
                        return p
        except Exception as exc:
            self._notify("Error", str(exc), "critical")

        return None

    def _change_proxy(self, icon, _item):
        """Change the system proxy selection."""
        result = self._pick_proxy("Change System Proxy", self.proxy_selection)
        if result:
            self.proxy_selection = result
            self._notify(
                "Proxy Changed",
                f"System proxy → {result['name']} ({result['ip']})",
            )
        self._refresh(icon)

    def _change_redsocks_proxy(self, icon, _item):
        """Change the redsocks proxy selection."""
        result = self._pick_proxy("Change Redsocks Proxy", self.redsocks_selection)
        if result:
            self.redsocks_selection = result
            self._notify(
                "Redsocks Proxy Changed",
                f"Redsocks proxy → {result['name']} ({result['ip']})",
            )
        self._refresh(icon)

    # ── Quit ───────────────────────────────────────────────────

    def _quit(self, icon, _item):
        self._running = False
        icon.stop()

    # ── Dynamic menu ───────────────────────────────────────────

    def _build_menu(self):
        """
        Menu items with callable text are re-evaluated each time
        the menu is opened, so status labels stay current.
        """
        def proxy_label(_mi):
            s = "ON" if self.is_proxy_on() else "OFF"
            return f"🔌  Proxy: {s}  ({self.proxy_selection['ip']})"

        def redsocks_label(_mi):
            health = self.redsocks_health()
            if health == "on":
                s = "ON"
            elif health == "warn":
                s = "ON !"
            elif health == "unknown":
                s = "ON ?"
            else:
                s = "OFF"
            return f"🔀  Redsocks: {s}  ({self.redsocks_selection['ip']})"

        def proxy_toggle_label(_mi):
            return "Disable Proxy" if self.is_proxy_on() else "Enable Proxy"

        def redsocks_toggle_label(_mi):
            return "Disable Redsocks" if self.is_redsocks_on() else "Enable Redsocks"

        return pystray.Menu(
            # ── Status (read-only) ──
            item(proxy_label, None, enabled=False),
            item(redsocks_label, None, enabled=False),
            pystray.Menu.SEPARATOR,

            # ── Proxy controls ──
            item(proxy_toggle_label, self._toggle_proxy),
            item("Change Proxy…", self._change_proxy),
            pystray.Menu.SEPARATOR,

            # ── Redsocks controls ──
            item(redsocks_toggle_label, self._toggle_redsocks),
            item("Change Redsocks Proxy…", self._change_redsocks_proxy),
            pystray.Menu.SEPARATOR,

            item("Quit", self._quit),
        )

    # ── Refresh / monitor ──────────────────────────────────────

    def _refresh(self, icon):
        icon.icon = self._render_icon()
        icon.title = self._tooltip()
        try:
            icon.menu = self._build_menu()
            update_menu = getattr(icon, "update_menu", None)
            if callable(update_menu):
                update_menu()
        except Exception:
            pass

    def _monitor(self, icon):
        """Background thread — poll status every POLL_INTERVAL seconds."""
        while self._running:
            time.sleep(POLL_INTERVAL)
            try:
                self._refresh(icon)
            except Exception:
                pass

    # ── Entry point ────────────────────────────────────────────

    def run(self):
        icon = pystray.Icon(
            "proxy_manager",
            self._render_icon(),
            self._tooltip(),
            self._build_menu(),
        )

        monitor = threading.Thread(target=self._monitor, args=(icon,), daemon=True)
        monitor.start()

        def on_setup(icon):
            icon.visible = True
            proxy_s = "ON" if self.is_proxy_on() else "OFF"
            redsocks_health = self.redsocks_health()
            if redsocks_health == "on":
                redsocks_s = "ON"
            elif redsocks_health == "warn":
                redsocks_s = "ON (NO NAT RULES)"
            elif redsocks_health == "unknown":
                redsocks_s = "ON (RULES UNKNOWN)"
            else:
                redsocks_s = "OFF"
            self._notify(
                "Proxy Manager",
                f"Proxy: {proxy_s} ({self.proxy_selection['ip']})\n"
                f"Redsocks: {redsocks_s} ({self.redsocks_selection['ip']})",
            )

        icon.run(on_setup)


def main():
    # Enforce single instance using abstract namespace socket
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        # The null byte at the start specifies abstract namespace (Linux only)
        # If bind fails, another instance is already holding the lock
        s.bind('\0proxy_manager_tray_lock')
    except socket.error:
        print("Proxy Manager is already running.")
        sys.exit(0)

    # Allow Ctrl-C to kill the process cleanly
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    ProxyManager().run()


if __name__ == "__main__":
    main()
