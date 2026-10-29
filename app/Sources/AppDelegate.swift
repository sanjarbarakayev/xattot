import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hotKey = HotKey()
    private let recorder = ShortcutRecorder()
    private let defaults = UserDefaults.standard
    private var shortcut = Shortcut.load()
    private var shortcutRegistered = false
    private var pendingTarget: LayoutMode?
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
        reportInstall([LayoutInstaller.installIfNeeded(), InputMethodInstaller.installIfNeeded()])

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
            if !InputSources.isEnabled(mode.sourceID) {
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
        LayoutMode.isOzbek(InputSources.currentID())
    }

    private var mode: LayoutMode {
        mode(enabled: InputSources.enabledKeyboardSources())
    }

    private func mode(enabled: [SourceInfo]) -> LayoutMode {
        LayoutMode.active(
            stored: defaults.string(forKey: LayoutMode.defaultsKey).flatMap(LayoutMode.init(rawValue:)),
            enabledIDs: Set(enabled.map(\.id)))
    }

    private func enabledIDs() -> Set<String> {
        Set(InputSources.enabledKeyboardSources().map(\.id))
    }

    /// The Özbek source the toggle and password guard work with: the current one, else the active mode's.
    private func ozbekID(current: String?, enabled: [SourceInfo]) -> String {
        if let current, LayoutMode.isOzbek(current) { return current }
        return mode(enabled: enabled).sourceID
    }

    private func title(_ layout: LayoutMode) -> String {
        switch layout {
        case .inputMethod: "Özbekça (Xattot)"
        case .digraph: "Özbekça Klassik (Xattot)"
        case .tugmali: "Özbekça Tugmali (Xattot)"
        }
    }

    @objc private func toggle() {
        // Turning off while Özbek waits for a password field to close only cancels the wait.
        if passwordLeftFor != nil, !isOn {
            passwordLeftFor = nil
            return
        }
        setOn(!isOn)
    }

    private func setOn(_ on: Bool) {
        // A modal alert keeps the run loop going, so presses while it is open must not stack more.
        guard !presentingAlert, on != isOn else { return }
        let current = InputSources.currentID()
        if on {
            let target = mode
            if let previous = ToggleLogic.previousToRemember(current: current) {
                defaults.set(previous, forKey: AppDelegate.previousKey)
            }
            guard ensureInstalled(target) else { return }
            if !InputSources.isEnabled(target.sourceID) {
                askToEnable(target)
            } else if let wait = PasswordGuard.waitBefore(
                selecting: target, secure: InputSources.secureInputActive(), current: current) {
                passwordLeftFor = wait
            } else {
                InputSources.select(target.sourceID)
            }
        } else {
            let enabled = InputSources.enabledKeyboardSources()
            if let target = ToggleLogic.offTarget(
                uzbek: ozbekID(current: current, enabled: enabled),
                previous: defaults.string(forKey: AppDelegate.previousKey),
                enabled: enabled
            ) {
                InputSources.select(target)
            }
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
        let current = InputSources.currentID()
        let enabled = InputSources.enabledKeyboardSources()
        let step = PasswordGuard.step(
            secure: secure,
            current: current,
            uzbek: ozbekID(current: current, enabled: enabled),
            previous: defaults.string(forKey: AppDelegate.previousKey),
            enabled: enabled,
            leftFor: passwordLeftFor
        )
        passwordLeftFor = step.leftFor
        if let target = step.select {
            InputSources.select(target)
            refreshIcon()
        }
    }

    /// Explains macOS's generic consent prompt before it appears, on first run and on a menu switch.
    private func askToEnable(_ target: LayoutMode) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "\(title(target)) ni yoqamizmi?"
        alert.informativeText = enableText(for: target)
        alert.addButton(withTitle: "Davom etiş")
        alert.addButton(withTitle: "Sozlamalarda özim qöşaman")
        alert.addButton(withTitle: "Bekor qiliş")
        presentingAlert = true
        defer { presentingAlert = false }
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            requestSwitch(to: target)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(AppDelegate.keyboardSettings)
        default:
            break
        }
    }

    private func enableText(for target: LayoutMode) -> String {
        if target == .inputMethod {
            return """
                Özbekça (Xattot) — kiritiş usuli. Harflarni tögri almaştiriş uçun u kursor oldidagi sözni öqiydi.
                Matn Mac'dan çiqmaydi: unda tarmoq kodi yöq, buni scripts/check_no_network.sh bilan özingiz tekşira olasiz.
                Parol maydonlarida u hech bir harfni almaştirmaydi.

                Davom etsangiz, keyingi oynada "Allow" ni bosing. Bu bir marta söraladi.
                """
        }
        return """
            Birinçi marta macOS ruxsat söraydi. Undagi ogohlantiriş matni barça \
            klaviaturalar uçun bir xil, uni Apple yozgan.

            \(title(target)) — dastur emas, faqat harflar jadvali: qaysi tugma qaysi \
            harfni yozişi. U hech narsani öqimaydi, saqlamaydi va hech qayerga yubormaydi.

            Davom etsangiz, keyingi oynada "Allow" ni bosing. Bu bir marta söraladi.
            """
    }

    /// Enables the target first; the rest of the switch runs when macOS reports it enabled.
    private func requestSwitch(to target: LayoutMode) {
        guard ensureInstalled(target) else { return }
        let steps = LayoutMode.switchSteps(to: target, enabledIDs: enabledIDs())
        guard let enable = steps.enable else { return complete(target, steps) }
        // A denied prompt sends no answer, so the latest request stays pending and a retry prompts again.
        pendingTarget = target
        InputSources.requestEnable(enable)
    }

    private func complete(_ target: LayoutMode, _ steps: LayoutMode.Switch) {
        pendingTarget = nil
        defaults.set(target.rawValue, forKey: LayoutMode.defaultsKey)
        let current = InputSources.currentID()
        if let previous = ToggleLogic.previousToRemember(current: current) {
            defaults.set(previous, forKey: AppDelegate.previousKey)
        }
        if let wait = PasswordGuard.waitBefore(
            selecting: target, secure: InputSources.secureInputActive(), current: current) {
            passwordLeftFor = wait
        } else {
            InputSources.select(steps.select)
        }
        // Select before disabling, so macOS never falls back to some other source in between.
        for id in steps.disable {
            InputSources.requestDisable(id)
        }
        refreshIcon()
        offerLaunchAtLogin()
    }

    @objc private func enabledSourcesChanged() {
        guard let target = pendingTarget,
              let steps = LayoutMode.completion(of: target, enabledIDs: enabledIDs()) else { return }
        complete(target, steps)
    }

    /// One alert per launch: the first failure, else a single "updated" notice however many bundles changed.
    private func reportInstall(_ outcomes: [LayoutInstaller.Outcome]) {
        for case .failed(let error) in outcomes {
            return alert("Layoutni örnatib bölmadi", error.localizedDescription)
        }
        let updated = outcomes.contains { if case .updated = $0 { return true } else { return false } }
        if updated {
            alert("Özbekça yangilandi",
                  "Oçiq turgan dasturlar eski versiya bilan yozişda davom etişi mumkin. "
                      + "Yangisi uçun ularni qayta oçing yoki bir marta Log Out qilib kiring.")
        }
    }

    /// Right after an install macOS can miss the bundle until it is registered; alerts only if it still does.
    private func ensureInstalled(_ layout: LayoutMode) -> Bool {
        if InputSources.isInstalled(layout.sourceID) { return true }
        LayoutInstaller.refreshInputSources()
        if InputSources.isInstalled(layout.sourceID) { return true }
        alert("\(title(layout)) topilmadi",
              "Özbekça örnatildi, lekin macOS uni hali körmayapti. Bir marta Log Out qilib qayta kiring.")
        return false
    }

    private func offerLaunchAtLogin() {
        guard !presentingAlert, LoginOffer.shouldAsk(
            asked: defaults.bool(forKey: LoginOffer.askedKey),
            launchesAtLogin: SMAppService.mainApp.status == .enabled,
            layoutEnabled: InputSources.isEnabled(mode.sourceID)
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
        menu.removeAllItems()
        // Secure input explains nothing when it holds no mode back.
        let secure = InputSources.secureInputActive() && PasswordGuard.waits(for: mode)
        let lines = SecureInputNotice.lines(
            on: isOn, secure: secure, waiting: passwordLeftFor != nil,
            holder: secure ? SecureInputHolder.holder(of: SecureInputHolder.app()) : nil)

        menu.addItem(label(lines.state))
        menu.addItem(item(lines.toggle, #selector(toggle)))
        if let reason = lines.reason {
            menu.addItem(label(reason))
        }
        if let restart = lines.restart {
            menu.addItem(item(restart, #selector(restartSecureInputHolder)))
        }
        menu.addItem(.separator())

        let active = mode
        for layout in LayoutMode.allCases {
            let choice = item(title(layout), #selector(chooseLayout(_:)))
            choice.representedObject = layout.rawValue
            choice.state = layout == active ? .on : .off
            menu.addItem(choice)
        }
        menu.addItem(.separator())

        let shortcutTitle = shortcutRegistered
            ? "Shortcut: \(shortcut.display)"
            : "Shortcut: \(shortcut.display) — boşqa dastur band qilgan"
        menu.addItem(label(shortcutTitle))
        menu.addItem(item("Shortcutni özgartiriş…", #selector(changeShortcut)))

        let login = item("Login'da avtomatik işga tuşsin", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("Çiqiş", #selector(NSApplication.terminate(_:)), target: NSApp))
    }

    private func label(_ title: String) -> NSMenuItem {
        let label = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        label.isEnabled = false
        return label
    }

    private func item(_ title: String, _ action: Selector, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target ?? self
        return item
    }

    @objc private func chooseLayout(_ sender: NSMenuItem) {
        guard !presentingAlert, let raw = sender.representedObject as? String,
              let target = LayoutMode(rawValue: raw) else { return }
        // Choosing the enabled active layout cancels a switch still waiting on macOS. With nothing enabled
        // the mode only falls back to it, so choosing it asks to enable it again.
        guard target != mode || !InputSources.isEnabled(target.sourceID) else {
            pendingTarget = nil
            return
        }
        guard ensureInstalled(target) else { return }
        if InputSources.isEnabled(target.sourceID) {
            requestSwitch(to: target)
        } else {
            askToEnable(target)
        }
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

    @objc private func restartSecureInputHolder() {
        guard let app = SecureInputHolder.app(), let holder = SecureInputHolder.holder(of: app), holder.canRestart else {
            alert("Parol rejimi yopildi", "Özbekçani endi yoqiş mumkin.")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let confirm = NSAlert()
        confirm.messageText = "\(holder.name)'ni qayta işga tuşiraymi?"
        confirm.informativeText = """
            Qaysidir dastur parol rejimini yoqib turibdi, şu sababli Özbekça yoqilmayapti. \
            Rejim yoqilganda oldinda \(holder.name) turgan edi, odatda u sabab böladi. \
            macOS buni aniq aytmaydi, şuning uçun bu taxmin.

            Agar \(holder.name)'da parol maydoni oçiq bölmasa, u rejimni yopişni unutgan: \
            faqat uni yopib qayta oçiş tuzatadi. Qayta oçilgandan keyin ham menyu \
            parol rejimini körsatsa, sabab boşqa dasturda.

            \(holder.name) Cmd+Q bosilgandagiday yopiladi: saqlanmagan iş bölsa, özi söraydi.
            """
        confirm.addButton(withTitle: "Qayta işga tuşiriş")
        confirm.addButton(withTitle: "Bekor qiliş")
        presentingAlert = true
        let answer = confirm.runModal()
        presentingAlert = false
        guard answer == .alertFirstButtonReturn else { return }
        if !SecureInputHolder.restart(app) {
            alert("\(holder.name) yopilmadi", "Uni özingiz yoping (Cmd+Q) va qayta oçing.")
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
            alert("Ruxsat kerak", "System Settings > General > Login Items böliminda Xattotni yoqing.")
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
