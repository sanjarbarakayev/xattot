import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hotKey = HotKey()
    private let recorder = ShortcutRecorder()
    private let defaults = UserDefaults.standard
    private var shortcut = Shortcut.load()
    private var shortcutRegistered = false
    private var selectWhenEnabled = false
    private var presentingAlert = false
    private var passwordTimer: Timer?
    private var passwordLeftFor: String?

    private static let previousKey = "previousSourceID"
    private static let onboardedKey = "onboarded"
    private static let keyboardSettings = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppLocation.needsMove, AppLocation.offerMove() {
            return
        }
        switch LayoutInstaller.installIfNeeded() {
        case .failed(let error):
            alert("Layoutni örnatib bölmadi", error.localizedDescription)
        case .updated:
            alert("Özbek (Lotin) yangilandi",
                  "Oçiq turgan dasturlar eski layout bilan yozişda davom etişi mumkin. "
                      + "Yangisi uçun ularni qayta oçing yoki bir marta Log Out qilib kiring.")
        case .upToDate, .installed:
            break
        }

        hotKey.onPress = { [weak self] in self?.toggle() }
        shortcutRegistered = hotKey.register(shortcut)

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(refreshIcon), name: InputSources.changedNotification,
            object: nil, suspensionBehavior: .deliverImmediately)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(enabledSourcesChanged), name: InputSources.enabledChangedNotification,
            object: nil, suspensionBehavior: .deliverImmediately)
        refreshIcon()
        watchPasswordFields()

        // First launch: offer to enable right away instead of leaving people to find the menu.
        if !defaults.bool(forKey: AppDelegate.onboardedKey) {
            defaults.set(true, forKey: AppDelegate.onboardedKey)
            if !InputSources.isEnabled(InputSources.uzbekID) {
                DispatchQueue.main.async { [weak self] in self?.setOn(true) }
            }
        }
        DispatchQueue.main.async { [weak self] in self?.offerLaunchAtLogin() }
    }

    /// xattot://toggle, xattot://on, xattot://off — for Shortcuts, Raycast and scripts.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host {
            case "toggle": toggle()
            case "on": setOn(true)
            case "off": setOn(false)
            default: break
            }
        }
    }

    // MARK: Switching

    private var isOn: Bool {
        ToggleLogic.isOn(current: InputSources.currentID(), uzbek: InputSources.uzbekID)
    }

    @objc private func toggle() {
        setOn(!isOn)
    }

    private func setOn(_ on: Bool) {
        // A modal alert keeps the run loop going, so presses while it is open must not stack more.
        guard !presentingAlert, on != isOn else { return }
        if on {
            if let previous = ToggleLogic.previousToRemember(current: InputSources.currentID(), uzbek: InputSources.uzbekID) {
                defaults.set(previous, forKey: AppDelegate.previousKey)
            }
            if !InputSources.isInstalled(InputSources.uzbekID) {
                alert("Özbek (Lotin) layout topilmadi",
                      "Layout örnatildi, lekin macOS uni hali körmayapti. Bir marta Log Out qilib qayta kiring.")
            } else if !InputSources.isEnabled(InputSources.uzbekID) {
                askToEnable()
            } else {
                InputSources.select(InputSources.uzbekID)
            }
        } else if let target = ToggleLogic.offTarget(
            uzbek: InputSources.uzbekID,
            previous: defaults.string(forKey: AppDelegate.previousKey),
            enabled: InputSources.enabledKeyboardSources()
        ) {
            InputSources.select(target)
        }
        refreshIcon()
    }

    // macOS has no notification for secure input, so it is polled; the check is a single flag read.
    private func watchPasswordFields() {
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.guardPasswordField() }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        passwordTimer = timer
    }

    private func guardPasswordField() {
        let secure = InputSources.secureInputActive()
        guard secure || passwordLeftFor != nil else { return }
        let step = PasswordGuard.step(
            secure: secure,
            current: InputSources.currentID(),
            uzbek: InputSources.uzbekID,
            previous: defaults.string(forKey: AppDelegate.previousKey),
            enabled: InputSources.enabledKeyboardSources(),
            leftFor: passwordLeftFor
        )
        passwordLeftFor = step.leftFor
        if let target = step.select {
            InputSources.select(target)
            refreshIcon()
        }
    }

    /// First run: explain macOS's generic consent prompt before it appears.
    private func askToEnable() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Özbek (Lotin) ni yoqamizmi?"
        alert.informativeText = """
            Birinçi marta macOS ruxsat söraydi. Undagi ogohlantiriş matni barça \
            klaviaturalar uçun bir xil, uni Apple yozgan.

            Özbek (Lotin) — dastur emas, faqat harflar jadvali: qaysi tugma qaysi \
            harfni yozişi. U hech narsani öqimaydi, saqlamaydi va hech qayerga yubormaydi.

            Davom etsangiz, keyingi oynada "Allow" ni bosing. Bu bir marta söraladi.
            """
        alert.addButton(withTitle: "Davom etiş")
        alert.addButton(withTitle: "Sozlamalarda özim qöşaman")
        alert.addButton(withTitle: "Bekor qiliş")
        presentingAlert = true
        defer { presentingAlert = false }
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            selectWhenEnabled = true
            InputSources.requestEnable(InputSources.uzbekID)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(AppDelegate.keyboardSettings)
        default:
            break
        }
    }

    @objc private func enabledSourcesChanged() {
        guard selectWhenEnabled, InputSources.isEnabled(InputSources.uzbekID) else { return }
        selectWhenEnabled = false
        InputSources.select(InputSources.uzbekID)
        refreshIcon()
        offerLaunchAtLogin()
    }

    private func offerLaunchAtLogin() {
        guard !presentingAlert, LoginOffer.shouldAsk(
            asked: defaults.bool(forKey: LoginOffer.askedKey),
            launchesAtLogin: SMAppService.mainApp.status == .enabled,
            layoutEnabled: InputSources.isEnabled(InputSources.uzbekID)
        ) else { return }
        defaults.set(true, forKey: LoginOffer.askedKey)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Kompyuter yonganda Xattot ham işga tuşsinmi?"
        alert.informativeText = """
            Şunda \(shortcut.display) va parol maydonlarida ABC ga ötiş kompyuter \
            qayta yonganidan keyin ham işlaydi. Keyin menyudan özgartiriş mumkin.
            """
        alert.addButton(withTitle: "Ha")
        alert.addButton(withTitle: "Yöq")
        presentingAlert = true
        let answer = alert.runModal()
        presentingAlert = false
        if answer == .alertFirstButtonReturn {
            setLaunchAtLogin(true)
        }
    }

    @objc private func refreshIcon() {
        statusItem.button?.image = StatusIcon.image(on: isOn)
        statusItem.button?.toolTip = "Xattot — \(shortcut.display)"
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        let on = isOn
        menu.removeAllItems()

        let state = NSMenuItem(title: on ? "Özbek (Lotin): yoqilgan" : "Özbek (Lotin): öçirilgan", action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        menu.addItem(item(on ? "Öçiriş" : "Yoqiş", #selector(toggle)))
        menu.addItem(.separator())

        let shortcutTitle = shortcutRegistered
            ? "Shortcut: \(shortcut.display)"
            : "Shortcut: \(shortcut.display) — boşqa dastur band qilgan"
        let info = NSMenuItem(title: shortcutTitle, action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(item("Shortcutni özgartiriş…", #selector(changeShortcut)))

        let login = item("Login'da avtomatik işga tuşsin", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("Çiqiş", #selector(NSApplication.terminate(_:)), target: NSApp))
    }

    private func item(_ title: String, _ action: Selector, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target ?? self
        return item
    }

    @objc private func changeShortcut() {
        // Free the current combination so it can be chosen again.
        hotKey.unregister()
        recorder.record { [weak self] recorded in
            guard let self else { return }
            if let recorded {
                self.shortcut = recorded
                recorded.save(to: self.defaults)
            }
            self.shortcutRegistered = self.hotKey.register(self.shortcut)
            self.refreshIcon()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        setLaunchAtLogin(SMAppService.mainApp.status != .enabled)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            alert("Login sozlamasi özgarmadi", error.localizedDescription)
            return
        }
        // macOS may hold a new login item until the person allows it in System Settings.
        if on, service.status == .requiresApproval {
            alert("Ruxsat kerak", "System Settings > General > Login Items böliminda Xattot ni yoqing.")
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        presentingAlert = true
        defer { presentingAlert = false }
        alert.runModal()
    }
}
