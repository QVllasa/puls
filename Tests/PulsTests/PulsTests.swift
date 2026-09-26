import Foundation
import Testing
@testable import Puls

// Die Tests laufen ohne App-Paket, also mit den englischen Grundtexten.

@Suite("Formatierung")
struct FormatTests {
    @Test func percentRoundsAndHasNoSpaceInEnglish() {
        #expect(Fmt.percent(12.4) == "12%")
        #expect(Fmt.percent(99.6) == "100%")
    }

    @Test func ratesPickSensibleUnits() {
        #expect(Fmt.rate(0).hasSuffix("KB/s"))
        #expect(Fmt.rate(512_000).hasSuffix("KB/s"))
        #expect(Fmt.rate(2_500_000).hasSuffix("MB/s"))
        #expect(Fmt.rate(3_000_000_000).hasSuffix("GB/s"))
        #expect(Fmt.rate(-5) == Fmt.rate(0))
    }

    @Test func storageUsesDecimalUnits() {
        #expect(Fmt.storage(994_000_000_000).hasSuffix("GB"))
        #expect(Fmt.storage(2_000_000_000_000).hasSuffix("TB"))
        #expect(Fmt.storage(5_000_000).hasSuffix("MB"))
    }

    @Test func memoryUsesBinaryUnits() {
        #expect(Fmt.memory(512 * 1_048_576).hasSuffix("MB"))
        #expect(Fmt.memory(48 * 1_073_741_824).hasSuffix("GB"))
    }

    @Test func durations() {
        #expect(Fmt.minutes(45) == "45 min")
        #expect(Fmt.minutes(60) == "1 h")
        #expect(Fmt.minutes(135) == "2 h 15 min")
        #expect(Fmt.uptime(5 * 60) == "5 min")
        #expect(Fmt.uptime(3 * 3600 + 12 * 60) == "3 h 12 min")
        #expect(Fmt.uptime(2 * 86400 + 4 * 3600) == "2 d 4 h")
    }

    @Test func temperatureUnits() {
        #expect(Fmt.temperature(40, fahrenheit: false).hasSuffix("°C"))
        #expect(Fmt.temperature(100, fahrenheit: true).hasPrefix("212"))
    }
}

@Suite("Updates")
struct UpdateTests {
    @Test func versionComparison() {
        #expect(UpdateChecker.isNewer("1.1.0", than: "1.0.0"))
        #expect(UpdateChecker.isNewer("1.10.0", than: "1.9.9"))
        #expect(UpdateChecker.isNewer("2", than: "1.9"))
        #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("1.0", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("0.9.9", than: "1.0.0"))
    }
}

@Suite("Verlauf und Grafik")
struct ChartTests {
    @Test func historyKeepsCapacity() {
        var h = History(capacity: 3)
        for v in [1.0, 2, 3, 4, 5] { h.append(v) }
        #expect(h.values == [3, 4, 5])
        #expect(h.last == 5)
        #expect(h.max == 5)
    }

    @Test func sparklineIsRightAlignedAndClamped() {
        let size = CGSize(width: 59, height: 20)
        let pts = Sparkline.points(values: [0, 50, 200], maxValue: 100, capacity: 60, size: size)
        #expect(pts.count == 3)
        #expect(abs(pts.last!.x - size.width) < 0.001)       // neuester Wert rechts
        #expect(pts.first!.y == size.height)                  // 0 → unten
        #expect(pts.last!.y >= 0)                              // über Maximum wird begrenzt
    }
}

@Suite("Sensoren")
struct SensorTests {
    @Test func friendlyNames() {
        #expect(SensorSampler.friendlyName("PMU tdie3") == "CPU die 3")
        #expect(SensorSampler.friendlyName("PMU TP2g") == "Graphics 2")
        #expect(SensorSampler.friendlyName("PMU TP1s") == "SoC 1")
        #expect(SensorSampler.friendlyName("NAND CH0 temp") == "SSD")
        #expect(SensorSampler.friendlyName("gas gauge battery") == "Battery cell")
    }

    @Test func smcDecoding() {
        let flt = UInt32(0x666C_7420) // "flt "
        let bits = Float(1350).bitPattern
        let bytes = [UInt8(bits & 0xff), UInt8(bits >> 8 & 0xff), UInt8(bits >> 16 & 0xff), UInt8(bits >> 24)]
        #expect(SensorSampler.decode(type: flt, bytes: bytes, size: 4) == 1350)
        let fpe2 = UInt32(0x6670_6532) // "fpe2"
        #expect(SensorSampler.decode(type: fpe2, bytes: [0x15, 0x18], size: 2) == Double(0x1518) / 4)
    }
}

@Suite("Messwerte dieses Macs")
struct LiveTests {
    @Test func coreGroupsCoverAllCores() {
        let groups = CPUSampler().groups
        #expect(groups.map(\.range.count).reduce(0, +) == ProcessInfo.processInfo.activeProcessorCount)
    }

    @Test func cpuSampleIsInRange() throws {
        let sampler = CPUSampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 0.4)
        let stats = try #require(sampler.sample())
        #expect((0...100).contains(stats.total))
        #expect(stats.cores.allSatisfy { (0...100).contains($0) })
    }

    @Test func memoryIsPlausible() throws {
        let m = try #require(MemorySampler.sample())
        #expect(m.used > 0)
        #expect(m.used <= m.total)
    }

    @Test func networkCountersExist() {
        #expect(!NetworkSampler.counters().isEmpty)
    }

    @Test func rootVolumeIsListed() {
        #expect(DiskSampler.volumes().contains { $0.path == "/" })
    }
}
