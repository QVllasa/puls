import AppKit
import Foundation
import Observation

/// Sammelt regelmäßig alle Messwerte und hält die Verläufe für die Grafiken.
@MainActor
@Observable
final class SystemMonitor {
    let machine = MachineInfo.current
    let coreGroups: [CoreGroup]

    private(set) var cpu = CPUStats()
    private(set) var cpuHistory = History()
    private(set) var gpu: GPUStats?
    private(set) var gpuHistory = History()
    private(set) var memory = MemoryStats()
    private(set) var memoryHistory = History()
    private(set) var network = NetworkStats()
    private(set) var downloadHistory = History()
    private(set) var uploadHistory = History()
    private(set) var disk = DiskStats()
    private(set) var readHistory = History()
    private(set) var writeHistory = History()
    private(set) var volumes: [VolumeInfo] = []
    private(set) var sensors = SensorStats()
    private(set) var temperatureHistory = History()
    private(set) var powerHistory = History()
    private(set) var battery: BatteryStats?
    private(set) var batteryHistory = History()
    private(set) var bluetooth: [BluetoothDevice] = []
    private(set) var bluetoothLoaded = false
    private(set) var topCPU: [ProcessRow] = []
    private(set) var topMemory: [ProcessRow] = []
    private(set) var publicIP: String?
    private(set) var publicIPLoading = false
    private(set) var uptime: TimeInterval = 0

    /// Für Screenshots: echte IP-Adressen durch Beispieladressen ersetzen.
    @ObservationIgnored var redactsAddresses = false

    var displayComputerName: String { redactsAddresses ? "MacBook Pro" : machine.computerName }
    var displayLocalIP: String? { redactsAddresses ? "192.168.1.23" : network.localIPv4 }
    var displayPublicIP: String? { redactsAddresses && publicIP != nil ? "203.0.113.42" : publicIP }

    /// Wird vom Panel gesetzt; teure Messungen (Prozesse, Bluetooth, öffentliche IP) laufen nur dann.
    var isPanelVisible = false {
        didSet { if isPanelVisible && !oldValue { refreshOnOpen() } }
    }

    @ObservationIgnored var onUpdate: (() -> Void)?

    @ObservationIgnored private let prefs: Preferences
    @ObservationIgnored private let cpuSampler = CPUSampler()
    @ObservationIgnored private let networkSampler = NetworkSampler()
    @ObservationIgnored private let diskSampler = DiskSampler()
    @ObservationIgnored private let sensorSampler = SensorSampler()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var tickCount = 0
    @ObservationIgnored private var lastBluetooth: Date?
    @ObservationIgnored private var lastPublicIP: (date: Date, interface: String?)?
    @ObservationIgnored private var processesRunning = false
    @ObservationIgnored private var bootTime = Sysctl.bootTime

    init(prefs: Preferences = .shared) {
        self.prefs = prefs
        coreGroups = cpuSampler.groups
        _ = cpuSampler.sample()
        _ = networkSampler.sample()
        _ = diskSampler.sampleThroughput()
        volumes = DiskSampler.volumes()
        battery = BatterySampler.sample()
        sensors = sensorSampler.sample()
        memory = MemorySampler.sample() ?? MemoryStats()
        gpu = GPUSampler.sample()
    }

    func start() {
        schedule()
        withObservationTracking { _ = prefs.refreshInterval } onChange: { [weak self] in
            Task { @MainActor in self?.start() }
        }
    }

    private func schedule() {
        timer?.invalidate()
        let t = Timer(timeInterval: max(0.5, prefs.refreshInterval), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    private func tick() {
        tickCount += 1

        if let c = cpuSampler.sample() {
            cpu = c
            cpuHistory.append(c.total)
        }
        if let g = GPUSampler.sample() {
            gpu = g
            gpuHistory.append(g.utilization)
        }
        if let m = MemorySampler.sample() {
            memory = m
            memoryHistory.append(m.usedPercent)
        }
        network = networkSampler.sample()
        downloadHistory.append(network.download)
        uploadHistory.append(network.upload)

        disk = diskSampler.sampleThroughput()
        readHistory.append(disk.read)
        writeHistory.append(disk.write)

        sensors = sensorSampler.sample()
        if let t = sensors.headline { temperatureHistory.append(t) }
        if let p = sensors.systemPower { powerHistory.append(p) }

        if tickCount % 3 == 1 || isPanelVisible {
            battery = BatterySampler.sample()
            if let b = battery { batteryHistory.append(b.percent) }
        }
        if tickCount % 15 == 0 { refreshVolumes() }
        if let bootTime { uptime = Date().timeIntervalSince(bootTime) }

        if isPanelVisible {
            refreshProcesses()
            if lastBluetooth.map({ Date().timeIntervalSince($0) > 60 }) ?? true { refreshBluetooth() }
            refreshPublicIPIfNeeded()
        }
        onUpdate?()
    }

    private func refreshOnOpen() {
        refreshVolumes()
        battery = BatterySampler.sample()
        refreshProcesses()
        if lastBluetooth.map({ Date().timeIntervalSince($0) > 30 }) ?? true { refreshBluetooth() }
        refreshPublicIPIfNeeded()
    }

    private func refreshVolumes() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = DiskSampler.volumes()
            DispatchQueue.main.async { self?.volumes = result }
        }
    }

    private func refreshProcesses() {
        guard Flavor.hasProcesses, !processesRunning else { return }
        processesRunning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = ProcessSampler.sample()
            DispatchQueue.main.async {
                guard let self else { return }
                self.topCPU = result.cpu
                self.topMemory = result.memory
                self.processesRunning = false
            }
        }
    }

    private func refreshBluetooth() {
        lastBluetooth = Date()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let devices = BluetoothSampler.sample()
            DispatchQueue.main.async {
                self?.bluetooth = devices
                self?.bluetoothLoaded = true
            }
        }
    }

    func refreshPublicIPIfNeeded(force: Bool = false) {
        guard prefs.fetchPublicIP else { publicIP = nil; return }
        guard network.isConnected, !publicIPLoading else { return }
        if !force, let last = lastPublicIP, last.interface == network.interfaceName,
           Date().timeIntervalSince(last.date) < 300 { return }
        publicIPLoading = true
        lastPublicIP = (Date(), network.interfaceName)
        Task {
            let ip = await PublicIPFetcher.fetch()
            self.publicIP = ip
            self.publicIPLoading = false
            // Fehlschlag (z. B. WLAN gerade erst verbunden): beim nächsten Tick erneut versuchen.
            if ip == nil { self.lastPublicIP = (Date().addingTimeInterval(-280), self.network.interfaceName) }
        }
    }
}
