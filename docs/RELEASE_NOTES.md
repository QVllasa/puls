Erste Version von **Puls** – ein schlanker Systemmonitor für die macOS-Menüleiste im Liquid-Glass-Design.

- Glas-Panel mit Kacheln für CPU, Grafik, Speicher, Netzwerk, Festplatte, Sensoren und Batterie
- Detailansichten mit Verläufen, Kernen, Top-Prozessen, Lüftern, Leistungsaufnahme, Akkuzustand und Bluetooth-Akkus
- Menüleiste frei konfigurierbar, mit farbigen Ampel-Indikatoren
- Startet automatisch mit dem Mac (abschaltbar)
- Universal-App für Apple Silicon und Intel, benötigt macOS 26 (Tahoe)

**Installation:** ZIP laden, `Puls.app` in „Programme“ ziehen. Da die App nicht notariell beglaubigt ist, einmal unter *Systemeinstellungen → Datenschutz & Sicherheit → Trotzdem öffnen* erlauben oder `xattr -dr com.apple.quarantine /Applications/Puls.app` ausführen.
