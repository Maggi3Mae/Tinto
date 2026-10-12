<p align="center">
  <img src="docs/icon.svg" width="128" alt="Tinto icon">
</p>

<h1 align="center">Tinto</h1>

<p align="center">
  Keep your Mac awake — even with the lid closed.<br>
  A tiny, free and open-source menu bar app for macOS.
</p>

<p align="center">
  <a href="https://github.com/Maggi3Mae/tinto/releases/latest"><b>Download</b></a> ·
  <a href="https://maggi3mae.github.io/tinto/">Website</a> ·
  <a href="README.es.md">Español</a>
</p>

---

*Tinto* is what Colombians call a small black coffee — the one that keeps you going.

## Features

- **One click** on the coffee bean in the menu bar to turn it on or off.
- **Timers**: 15 min, 30 min, 1 h, 2 h, 4 h, 8 h, a custom duration, or until a specific time.
- **Closed-lid mode**: close your MacBook and keep working on an external display — **no charger, keyboard or mouse required**.
- **Steady sessions**: if your display cable disconnects for a moment, Tinto keeps going. Nothing to reopen or rearrange.
- **Battery safeguard** (optional): ends the session when the battery drops below a level you choose.
- **Simulate activity** (optional): keeps chat apps like Teams or Slack showing you as *Available* while you're away.
- Time remaining next to the icon, open at login, English and Spanish.
- No account, no App Store, no tracking.

## Install

Requires **macOS 14 Sonoma or later** · Apple Silicon and Intel.

1. Download the latest **Tinto-x.y.z.dmg** from [Releases](https://github.com/Maggi3Mae/tinto/releases/latest).
2. Open it and drag **Tinto** to **Applications**.
3. Open Tinto. The first time, macOS will block it because it isn't signed with a paid Apple Developer certificate:
   click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.

   <details>
   <summary>Prefer the Terminal?</summary>

   ```bash
   xattr -dr com.apple.quarantine /Applications/Tinto.app
   ```
   </details>

## Usage

| Action | What it does |
| --- | --- |
| **Click** the bean | Turn on (indefinitely) / turn off |
| **Right-click** (or ⌥ + click) | Timers, settings, uninstall |

The bean is **filled** while Tinto is active and **outlined** when it's off.

### About closed-lid mode

macOS only lets a Mac stay awake with the lid closed while it's charging. Tinto lifts that limit with the system's own `pmset disablesleep` setting.
The first time you use it, Tinto asks for your password **once** to create a rule that lets it run exactly two commands — `pmset -a disablesleep 1` and `pmset -a disablesleep 0` — and nothing else. Normal sleep comes back as soon as the session ends or you quit Tinto.

> **Heads up:** while closed-lid mode is on, your Mac won't sleep even inside a bag. Turn Tinto off before packing it to avoid overheating.

### About simulate activity

Some apps (Teams, Slack…) mark you as *Away* after a few minutes without keyboard or mouse input, even if your Mac is awake. With **Simulate activity** on, Tinto checks every few seconds and, only when you've been idle for about a minute, tells macOS someone is using the Mac and moves the cursor by 1 pixel and back. It never moves the cursor while you're working.

Moving the cursor requires **Accessibility** permission (System Settings → Privacy & Security → Accessibility). Tinto opens that screen for you.

> **Note:** because Tinto isn't signed with a paid Apple Developer certificate, macOS forgets this permission after every update. Tinto will remind you; just turn it on again.

## Uninstall

Right-click the bean → **Uninstall Tinto…**. It restores normal sleep, removes the permission and moves the app to the Trash.

## Build from source

Requires Apple's Command Line Tools (`xcode-select --install`, free, no account needed).

```bash
git clone https://github.com/Maggi3Mae/tinto.git
cd tinto
bash scripts/install.sh      # build and install in /Applications
bash scripts/make-dmg.sh     # or build a .dmg in dist/
```

New releases are built automatically by GitHub Actions when a version tag is pushed:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Support

If Tinto is useful to you, you can [buy me a coffee ☕](https://ko-fi.com/margaritaa).

## License

[MIT](LICENSE) © Maggi3Mae
