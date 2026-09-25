import Darwin
import Foundation
import SystemConfiguration

struct NetworkStats: Equatable {
    var download: Double = 0          // Bytes pro Sekunde
    var upload: Double = 0
    var totalReceived: UInt64 = 0     // seit Systemstart, primäre Schnittstelle
    var totalSent: UInt64 = 0
    var interfaceName: String?        // z. B. en0
    var interfaceKind: String = "Offline"
    var localIPv4: String?
    var isConnected: Bool { interfaceName != nil }
}

final class NetworkSampler {
    private var previous: (received: UInt64, sent: UInt64, time: TimeInterval, interface: String)?
    private var kindCache: [String: String] = [:]
    private let store = SCDynamicStoreCreate(nil, "Puls" as CFString, nil, nil)

    func sample() -> NetworkStats {
        var stats = NetworkStats()
        guard let primary = primaryInterface() else {
            previous = nil
            return stats
        }
        stats.interfaceName = primary
        stats.interfaceKind = kind(of: primary)
        stats.localIPv4 = Self.ipv4Address(of: primary)

        guard let counters = Self.counters()[primary] else { return stats }
        stats.totalReceived = counters.received
        stats.totalSent = counters.sent

        let now = ProcessInfo.processInfo.systemUptime
        if let previous, previous.interface == primary, now > previous.time,
           counters.received >= previous.received, counters.sent >= previous.sent {
            let dt = now - previous.time
            stats.download = Double(counters.received - previous.received) / dt
            stats.upload = Double(counters.sent - previous.sent) / dt
        }
        previous = (counters.received, counters.sent, now, primary)
        return stats
    }

    private func kind(of bsdName: String) -> String {
        if let cached = kindCache[bsdName] { return cached }
        var result = "Netzwerk"
        if let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] {
            for interface in interfaces where (SCNetworkInterfaceGetBSDName(interface) as String?) == bsdName {
                let type = SCNetworkInterfaceGetInterfaceType(interface) as String?
                if type == (kSCNetworkInterfaceTypeIEEE80211 as String) {
                    result = "WLAN"
                } else if type == (kSCNetworkInterfaceTypeEthernet as String) {
                    result = "Ethernet"
                } else if type == (kSCNetworkInterfaceTypeBluetooth as String) {
                    result = "Bluetooth"
                } else {
                    result = (SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?) ?? "Netzwerk"
                }
            }
        }
        if bsdName.hasPrefix("utun") || bsdName.hasPrefix("ipsec") { result = "VPN" }
        kindCache[bsdName] = result
        return result
    }

    private func primaryInterface() -> String? {
        guard let store else { return nil }
        for key in ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] {
            if let dict = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
               let name = dict["PrimaryInterface"] as? String {
                return name
            }
        }
        return nil
    }

    static func ipv4Address(of interface: String) -> String? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard String(cString: entry.pointee.ifa_name) == interface,
                  let addr = entry.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: host)
            }
        }
        return nil
    }

    /// 64-Bit-Zähler aller Schnittstellen (if_data64 über NET_RT_IFLIST2).
    static func counters() -> [String: (received: UInt64, sent: UInt64)] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return [:] }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return [:] }

        var result: [String: (received: UInt64, sent: UInt64)] = [:]
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let msg = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(msg.ifm_index), &name) != nil {
                        result[String(cString: name)] = (msg.ifm_data.ifi_ibytes, msg.ifm_data.ifi_obytes)
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return result
    }
}

enum PublicIPFetcher {
    static func fetch() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 6)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, text.count <= 45 else { return nil }
        return text
    }
}
