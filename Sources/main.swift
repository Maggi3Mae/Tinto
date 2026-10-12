// Tinto — keeps your Mac awake, even with the lid closed.
// Menu bar app. Left click: toggle. Right click (or ⌥/⌃ + click): menu.
// https://github.com/Maggi3Mae/tinto · MIT License

import AppKit
import ApplicationServices
import IOKit.pwr_mgt
import IOKit.ps
import ServiceManagement

// MARK: - Idioma / Language

enum L {
    static let isSpanish = Locale.preferredLanguages.first?.lowercased().hasPrefix("es") ?? false
    static func t(_ spanish: String, _ english: String) -> String { isSpanish ? spanish : english }
}

enum Info {
    static let repoURL = URL(string: "https://github.com/Maggi3Mae/tinto")!
    static let sudoersPath = "/etc/sudoers.d/tinto"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

// MARK: - Ícono (grano de café)

@MainActor
enum BeanArt {
    /// Grano y su surco central, centrados en el origen. A escala 1 el grano mide 10 × 15.
    static func paths(scale s: CGFloat) -> (bean: NSBezierPath, crease: NSBezierPath) {
        let bean = NSBezierPath(ovalIn: NSRect(x: -5 * s, y: -7.5 * s, width: 10 * s, height: 15 * s))
        let crease = NSBezierPath()
        crease.move(to: NSPoint(x: 0.7 * s, y: -6.3 * s))
        crease.curve(to: NSPoint(x: -0.7 * s, y: 6.3 * s),
                     controlPoint1: NSPoint(x: -2.6 * s, y: -2.2 * s),
                     controlPoint2: NSPoint(x: 2.6 * s, y: 2.2 * s))
        crease.lineCapStyle = .round
        return (bean, crease)
    }

    static func tilt(around center: CGFloat) {
        let t = NSAffineTransform()
        t.translateX(by: center, yBy: center)
        t.rotate(byDegrees: -35)
        t.concat()
    }

    static func bitmap(pixels: Int, _ draw: (NSGraphicsContext, CGFloat) -> Void) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        draw(ctx, CGFloat(pixels))
        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// Ícono de plantilla para la barra de menú: relleno = activo, contorno = inactivo.
    static func menuBarImage(active: Bool) -> NSImage {
        let points: CGFloat = 18
        let image = NSImage(size: NSSize(width: points, height: points))
        if let rep = bitmap(pixels: Int(points * 2), { ctx, side in
            let s = side / points
            tilt(around: side / 2)
            let (bean, crease) = paths(scale: s)
            NSColor.black.setFill()
            NSColor.black.setStroke()
            if active {
                bean.fill()
                ctx.compositingOperation = .destinationOut
                crease.lineWidth = 1.7 * s
                crease.stroke()
                ctx.compositingOperation = .sourceOver
            } else {
                bean.lineWidth = 1.3 * s
                bean.stroke()
                crease.lineWidth = 1.2 * s
                crease.stroke()
            }
        }) {
            rep.size = image.size
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        image.accessibilityDescription = active ? L.t("Tinto activo", "Tinto active")
                                                : L.t("Tinto inactivo", "Tinto inactive")
        return image
    }

    /// Ícono de la app (1024 px) para Finder y Ajustes.
    static func renderAppIcon(to path: String) -> Bool {
        guard let rep = bitmap(pixels: 1024, { _, side in
            let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                                  xRadius: 185, yRadius: 185)
            let dark = NSColor(srgbRed: 0.22, green: 0.13, blue: 0.08, alpha: 1)
            let light = NSColor(srgbRed: 0.47, green: 0.29, blue: 0.18, alpha: 1)
            NSGradient(starting: dark, ending: light)?.draw(in: bg, angle: 90)

            tilt(around: side / 2)
            let (bean, crease) = paths(scale: 30)
            NSColor(srgbRed: 0.96, green: 0.89, blue: 0.80, alpha: 1).setFill()
            bean.fill()
            NSColor(srgbRed: 0.30, green: 0.18, blue: 0.11, alpha: 1).setStroke()
            crease.lineWidth = 46
            crease.stroke()
        }), let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}

// MARK: - Permisos de administrador

@MainActor
enum Admin {
    /// Ejecuta un comando como administrador con el diálogo de contraseña nativo de macOS.
    static func run(_ shell: String, prompt: String) -> Bool {
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        }
        let source = "do shell script \"\(escape(shell))\" with prompt \"\(escape(prompt))\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }

    /// Crea una regla de sudo limitada a `pmset -a disablesleep 0/1` para el usuario actual.
    static func installSleepPermission() -> Bool {
        let user = NSUserName()
        guard user.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { return false }
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        let shell = "t=$(/usr/bin/mktemp) && printf '%s\\n' '\(rule)' > \"$t\" && "
            + "/usr/sbin/visudo -cf \"$t\" >/dev/null && "
            + "/usr/bin/install -m 0440 -o root -g wheel \"$t\" \(Info.sudoersPath); "
            + "r=$?; /bin/rm -f \"$t\"; exit $r"
        return run(shell, prompt: L.t(
            "Tinto necesita tu permiso una sola vez para que el Mac no se duerma al cerrar la tapa.",
            "Tinto needs your permission once so your Mac can stay awake with the lid closed."))
    }

    static func removeSleepPermission() -> Bool {
        run("/usr/bin/pmset -a disablesleep 0; /bin/rm -f \(Info.sudoersPath)",
            prompt: L.t("Tinto quitará su permiso para desinstalarse.",
                        "Tinto will remove its permission to uninstall."))
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var ticker: Timer?
    private var tickCount = 0

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var lidApplied = false
    private var isActive = false
    private var endDate: Date?
    private var setupDeclined = false
    private var activityID: IOPMAssertionID = 0
    private var warnedAccessibility = false

    /// Segundos sin teclado ni mouse antes de simular actividad.
    private let idleBeforeNudge: Double = 50

    private lazy var activeIcon = BeanArt.menuBarImage(active: true)
    private lazy var idleIcon = BeanArt.menuBarImage(active: false)

    private let defaults = UserDefaults.standard
    private var closedLid: Bool {
        get { defaults.bool(forKey: "closedLid") }
        set { defaults.set(newValue, forKey: "closedLid") }
    }
    private var keepDisplayOn: Bool {
        get { defaults.bool(forKey: "keepDisplayOn") }
        set { defaults.set(newValue, forKey: "keepDisplayOn") }
    }
    private var showTime: Bool {
        get { defaults.bool(forKey: "showTime") }
        set { defaults.set(newValue, forKey: "showTime") }
    }
    private var batteryThreshold: Int {
        get { defaults.integer(forKey: "batteryThreshold") }
        set { defaults.set(newValue, forKey: "batteryThreshold") }
    }
    private var simulateActivity: Bool {
        get { defaults.bool(forKey: "simulateActivity") }
        set { defaults.set(newValue, forKey: "simulateActivity") }
    }

    // MARK: Ciclo de vida

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: [
            "closedLid": true,
            "keepDisplayOn": true,
            "showTime": true,
            "batteryThreshold": 10,
            "simulateActivity": false,
        ])

        // Por si una sesión anterior terminó de forma inesperada.
        setDisableSleep(false)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeft
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }

        let timer = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer

        refreshUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        deactivate()
    }

    // MARK: Sesión

    private func activate(until date: Date?) {
        isActive = true
        endDate = date
        applyAssertion()
        if closedLid && !lidApplied { lidApplied = enableLidMode() }
        refreshUI()
        // Tras una actualización macOS olvida el permiso de Accesibilidad: avisar una vez.
        if simulateActivity && !AXIsProcessTrusted() && !warnedAccessibility {
            warnedAccessibility = true
            askForAccessibility()
        }
    }

    private func deactivate() {
        releaseAssertion()
        if lidApplied {
            setDisableSleep(false)
            lidApplied = false
        }
        isActive = false
        endDate = nil
        refreshUI()
    }

    @objc private func tick() {
        guard isActive else { return }
        if let end = endDate, Date() >= end {
            deactivate()
            return
        }
        tickCount += 1
        if tickCount % 30 == 0, batteryThreshold > 0,
           let battery = batteryStatus(), battery.onBattery, battery.percent <= batteryThreshold {
            deactivate()
            return
        }
        if simulateActivity, tickCount % 10 == 0 { nudgeIfIdle() }
        refreshUI()
    }

    // MARK: Simular actividad

    private func nudgeIfIdle() {
        let anyInput = CGEventType(rawValue: UInt32.max)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        guard idle >= idleBeforeNudge else { return }

        // 1. Forma oficial: avisar a macOS que hay alguien usando el equipo.
        IOPMAssertionDeclareUserActivity("Tinto" as CFString, kIOPMUserActiveLocal, &activityID)

        // 2. Mover el cursor 1 px y devolverlo (requiere permiso de Accesibilidad).
        guard AXIsProcessTrusted(),
              let source = CGEventSource(stateID: .hidSystemState),
              let position = CGEvent(source: nil)?.location else { return }
        let nudged = CGPoint(x: position.x + 1, y: position.y)
        for point in [nudged, position] {
            CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                    mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
    }

    private func askForAccessibility() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L.t("Tinto necesita permiso de Accesibilidad",
                                "Tinto needs Accessibility permission")
        alert.informativeText = L.t(
            "Para simular actividad, Tinto mueve el cursor 1 píxel cuando no estás usando el Mac. "
            + "Activa Tinto en Ajustes → Privacidad y seguridad → Accesibilidad.\n\n"
            + "Después de cada actualización de Tinto tendrás que activarlo otra vez.",
            "To simulate activity, Tinto moves the cursor by 1 pixel while you're away. "
            + "Turn on Tinto in System Settings → Privacy & Security → Accessibility.\n\n"
            + "You'll need to turn it on again after each Tinto update.")
        alert.addButton(withTitle: L.t("Abrir Ajustes", "Open Settings"))
        alert.addButton(withTitle: L.t("Ahora no", "Not now"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // Agrega Tinto a la lista de Accesibilidad y abre esa sección de Ajustes.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Energía

    private func applyAssertion() {
        releaseAssertion()
        let type = keepDisplayOn ? kIOPMAssertionTypePreventUserIdleDisplaySleep
                                 : kIOPMAssertionTypePreventUserIdleSystemSleep
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(type as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "Tinto" as CFString,
                                                 &id)
        if result == kIOReturnSuccess {
            assertionID = id
            hasAssertion = true
        }
    }

    private func releaseAssertion() {
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
        }
    }

    /// Activa el modo tapa cerrada. La primera vez configura el permiso (pide la contraseña).
    private func enableLidMode() -> Bool {
        if setDisableSleep(true) { return true }
        guard !setupDeclined else { return false }
        if Admin.installSleepPermission(), setDisableSleep(true) { return true }
        setupDeclined = true
        return false
    }

    /// Activa o desactiva el reposo al cerrar la tapa, usando la regla de sudo de Tinto.
    @discardableResult
    private func setDisableSleep(_ on: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func batteryStatus() -> (percent: Int, onBattery: Bool)? {
        guard let infoRef = IOPSCopyPowerSourcesInfo() else { return nil }
        let info = infoRef.takeRetainedValue()
        guard let listRef = IOPSCopyPowerSourcesList(info) else { return nil }
        let list = listRef.takeRetainedValue() as NSArray
        for source in list {
            guard let descRef = IOPSGetPowerSourceDescription(info, source as CFTypeRef) else { continue }
            let desc = descRef.takeUnretainedValue() as NSDictionary
            guard let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = desc[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            let state = desc[kIOPSPowerSourceStateKey] as? String
            return (current * 100 / maximum, state == kIOPSBatteryPowerValue)
        }
        return nil
    }

    // MARK: Interfaz

    private func refreshUI() {
        guard let button = statusItem?.button else { return }
        button.image = isActive ? activeIcon : idleIcon
        if isActive, showTime, let end = endDate {
            button.title = " " + format(end.timeIntervalSinceNow)
        } else {
            button.title = ""
        }
        button.toolTip = statusText()
    }

    private func statusText() -> String {
        guard isActive else { return L.t("Tinto está inactivo", "Tinto is off") }
        let lid = lidApplied ? L.t(" · tapa cerrada", " · lid closed") : ""
        if let end = endDate {
            return L.t("Activo · quedan ", "Active · ") + format(end.timeIntervalSinceNow)
                + L.t("", " left") + lid
        }
        return L.t("Activo · indefinidamente", "Active · indefinitely") + lid
    }

    private func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        let minutes = (seconds + 59) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
        }
        if seconds >= 60 { return "\(minutes)m" }
        return "\(seconds)s"
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let flags = event?.modifierFlags ?? []
        let wantsMenu = event?.type == .rightMouseUp || flags.contains(.control) || flags.contains(.option)
        if wantsMenu {
            statusItem.menu = buildMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if isActive {
            deactivate()
        } else {
            activate(until: nil)
        }
    }

    private func item(_ title: String, _ action: Selector, checked: Bool = false) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.state = checked ? .on : .off
        return menuItem
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(isActive ? item(L.t("Desactivar", "Turn off"), #selector(deactivateAction))
                              : item(L.t("Activar indefinidamente", "Activate indefinitely"),
                                     #selector(activateIndefinite)))

        let durations: [(String, Int)] = [
            (L.t("15 minutos", "15 minutes"), 15), (L.t("30 minutos", "30 minutes"), 30),
            (L.t("1 hora", "1 hour"), 60), (L.t("2 horas", "2 hours"), 120),
            (L.t("4 horas", "4 hours"), 240), (L.t("8 horas", "8 hours"), 480),
        ]
        let durationMenu = NSMenu()
        durationMenu.autoenablesItems = false
        for (title, minutes) in durations {
            let menuItem = item(title, #selector(activateFor(_:)))
            menuItem.representedObject = minutes
            durationMenu.addItem(menuItem)
        }
        durationMenu.addItem(.separator())
        durationMenu.addItem(item(L.t("Personalizado…", "Custom…"), #selector(activateCustom)))
        let durationItem = NSMenuItem(title: L.t("Activar por", "Activate for"), action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        menu.addItem(item(L.t("Activar hasta…", "Activate until…"), #selector(activateUntil)))
        menu.addItem(.separator())

        menu.addItem(item(L.t("Modo tapa cerrada", "Closed-lid mode"),
                          #selector(toggleClosedLid), checked: closedLid))
        menu.addItem(item(L.t("Mantener la pantalla encendida", "Keep display on"),
                          #selector(toggleKeepDisplay), checked: keepDisplayOn))
        menu.addItem(item(L.t("Mostrar tiempo restante", "Show time remaining"),
                          #selector(toggleShowTime), checked: showTime))
        let missingPermission = simulateActivity && !AXIsProcessTrusted()
        menu.addItem(item(L.t("Simular actividad", "Simulate activity")
                          + (missingPermission ? L.t(" (falta permiso)", " (permission needed)") : ""),
                          #selector(toggleSimulateActivity), checked: simulateActivity))

        let batteryMenu = NSMenu()
        batteryMenu.autoenablesItems = false
        for value in [0, 10, 15, 20, 30] {
            let title = value == 0 ? L.t("Desactivado", "Off")
                                   : L.t("Terminar al \(value)%", "Stop at \(value)%")
            let menuItem = item(title, #selector(setBattery(_:)), checked: batteryThreshold == value)
            menuItem.representedObject = value
            batteryMenu.addItem(menuItem)
        }
        let batteryItem = NSMenuItem(title: L.t("Seguro de batería", "Battery safeguard"),
                                     action: nil, keyEquivalent: "")
        batteryItem.submenu = batteryMenu
        menu.addItem(batteryItem)

        menu.addItem(item(L.t("Abrir al iniciar sesión", "Open at login"), #selector(toggleLogin),
                          checked: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())

        menu.addItem(item("Tinto \(Info.version) · GitHub", #selector(openRepo)))
        menu.addItem(item(L.t("Desinstalar Tinto…", "Uninstall Tinto…"), #selector(uninstall)))

        let quit = NSMenuItem(title: L.t("Salir de Tinto", "Quit Tinto"),
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    // MARK: Acciones

    @objc private func deactivateAction() { deactivate() }
    @objc private func activateIndefinite() { activate(until: nil) }

    @objc private func activateFor(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        activate(until: Date().addingTimeInterval(TimeInterval(minutes * 60)))
    }

    @objc private func activateCustom() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L.t("Activar por un tiempo personalizado", "Activate for a custom time")
        alert.informativeText = L.t("¿Cuánto tiempo quieres que Tinto mantenga tu Mac despierto?",
                                    "How long should Tinto keep your Mac awake?")

        let hours = NSTextField(string: "1")
        let minutes = NSTextField(string: "0")
        for field in [hours, minutes] {
            field.alignment = .right
            field.widthAnchor.constraint(equalToConstant: 50).isActive = true
        }
        let stack = NSStackView(views: [hours, NSTextField(labelWithString: L.t("horas", "hours")),
                                        minutes, NSTextField(labelWithString: L.t("minutos", "minutes"))])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.setFrameSize(stack.fittingSize)
        alert.accessoryView = stack
        alert.addButton(withTitle: L.t("Activar", "Activate"))
        alert.addButton(withTitle: L.t("Cancelar", "Cancel"))
        alert.window.initialFirstResponder = hours

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let total = max(0, hours.integerValue) * 60 + max(0, minutes.integerValue)
        if total > 0 {
            activate(until: Date().addingTimeInterval(TimeInterval(total * 60)))
        }
    }

    @objc private func activateUntil() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L.t("Activar hasta una hora", "Activate until a time")
        alert.informativeText = L.t("Si la hora ya pasó hoy, se toma la de mañana.",
                                    "If that time has already passed today, tomorrow's is used.")

        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.dateValue = Date().addingTimeInterval(3600)
        picker.sizeToFit()
        alert.accessoryView = picker
        alert.addButton(withTitle: L.t("Activar", "Activate"))
        alert.addButton(withTitle: L.t("Cancelar", "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: picker.dateValue)
        if let target = calendar.nextDate(after: Date(), matching: parts, matchingPolicy: .nextTime) {
            activate(until: target)
        }
    }

    @objc private func toggleClosedLid() {
        closedLid.toggle()
        if closedLid { setupDeclined = false }
        if isActive {
            if closedLid && !lidApplied {
                lidApplied = enableLidMode()
            } else if !closedLid && lidApplied {
                setDisableSleep(false)
                lidApplied = false
            }
        }
        refreshUI()
    }

    @objc private func toggleKeepDisplay() {
        keepDisplayOn.toggle()
        if isActive { applyAssertion() }
    }

    @objc private func toggleShowTime() {
        showTime.toggle()
        refreshUI()
    }

    @objc private func toggleSimulateActivity() {
        if simulateActivity {
            simulateActivity = false
        } else {
            simulateActivity = true
            if !AXIsProcessTrusted() { askForAccessibility() }
        }
    }

    @objc private func setBattery(_ sender: NSMenuItem) {
        batteryThreshold = sender.representedObject as? Int ?? 0
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            showAlert(L.t("No se pudo cambiar el inicio automático", "Couldn't change the login setting"),
                      error.localizedDescription)
        }
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(Info.repoURL)
    }

    @objc private func uninstall() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L.t("¿Desinstalar Tinto?", "Uninstall Tinto?")
        alert.informativeText = L.t(
            "Se restaurará el reposo normal, se quitará el permiso de Tinto y la app irá a la Papelera.",
            "Normal sleep will be restored, Tinto's permission removed and the app moved to the Trash.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.t("Desinstalar", "Uninstall"))
        alert.addButton(withTitle: L.t("Cancelar", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        deactivate()
        if FileManager.default.fileExists(atPath: Info.sudoersPath) {
            guard Admin.removeSleepPermission() else { return }
        }
        try? SMAppService.mainApp.unregister()
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
            // Quitar Tinto de la lista de Accesibilidad.
            let reset = Process()
            reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            reset.arguments = ["reset", "Accessibility", bundleID]
            try? reset.run()
            reset.waitUntilExit()
        }
        try? FileManager.default.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
        NSApp.terminate(nil)
    }

    private func showAlert(_ title: String, _ text: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

// MARK: - Arranque

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if args.count >= 3, args[1] == "--icon" {
        exit(BeanArt.renderAppIcon(to: args[2]) ? 0 : 1)
    }
    if args.count >= 2, args[1] == "--unregister-login" {
        try? SMAppService.mainApp.unregister()
        exit(0)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
