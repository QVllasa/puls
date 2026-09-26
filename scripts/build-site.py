"""Erzeugt die Webseite (docs/) für GitHub Pages aus einer Vorlage, auf Englisch und Deutsch.

Aufruf: python3 scripts/build-site.py
Englisch liegt unter /, Deutsch unter /de/. Texte stehen unten in STRINGS; Screenshots in docs/screenshots/{en,de}/.
"""
import html
import json
import os
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
BASE = "https://qvllasa.github.io/puls"
VERSION = (ROOT / "VERSION").read_text().strip()
REPO = "https://github.com/QVllasa/puls"
DOWNLOAD = f"{REPO}/releases/latest/download/Puls-{VERSION}.zip"
zip_path = ROOT / f"dist/Puls-{VERSION}.zip"
SIZE_MB = f"{zip_path.stat().st_size / 1_000_000:.1f}" if zip_path.exists() else "2.3"


def png_size(rel: str) -> tuple[int, int]:
    data = (DOCS / rel).read_bytes()[16:24]
    return struct.unpack(">II", data)


def img(rel: str, alt: str, prefix: str, scale: int = 2, lazy: bool = True, cls: str = "", priority: bool = False) -> str:
    w, h = png_size(rel)
    attrs = [f'src="{prefix}{rel}"', f'alt="{html.escape(alt)}"', f'width="{w // scale}"', f'height="{h // scale}"',
             'decoding="async"']
    if lazy:
        attrs.append('loading="lazy"')
    if priority:
        attrs.append('fetchpriority="high"')
    if cls:
        attrs.append(f'class="{cls}"')
    return f"<img {' '.join(attrs)}>"


# ---------------------------------------------------------------- Texte

STRINGS = {
    "en": {
        "lang": "en", "locale": "en_US", "dir": "", "other": "de", "other_label": "Deutsch",
        "pages": {"index": "", "support": "support.html", "privacy": "privacy.html", "imprint": "imprint.html"},
        "nav": {"features": "Features", "compare": "Versions", "faq": "Questions", "support": "Support"},
        "title": "Puls: system monitor for the Mac menu bar",
        "description": "Puls shows CPU, graphics, memory, network, disk and battery live in your Mac menu bar, in a calm Liquid Glass panel made for macOS Tahoe. Free and open source.",
        "hero_title": "Your Mac, at a glance.",
        "hero_lead": "Puls sits in your menu bar and shows what your Mac is doing right now: processor, graphics, memory, network, disk, thermals and battery. One click opens the details.",
        "download": "Download for Mac",
        "download_meta": f"Version {VERSION}, {SIZE_MB} MB, free. Requires macOS 26 Tahoe on Apple silicon or Intel.",
        "appstore_note": "Coming soon to the Mac App Store.",
        "stage_alt": "The Puls panel opened from the menu bar, with tiles for CPU, graphics, memory, network, disk, sensors and battery",
        "menubar_alt": "Puls in the menu bar showing CPU, memory, network and battery",
        "explore_title": "Every part of your Mac, one click deeper.",
        "explore_lead": "Each tile opens a detail view with history, the numbers behind it and what they mean.",
        "areas": [
            ("cpu", "Processor", "Total load, every core grouped by type, system load and uptime. The GitHub version adds the busiest processes.", "The CPU detail view with total load, per-core bars and system load"),
            ("memory", "Memory", "App memory, wired and compressed memory, cache, memory pressure and swap, explained in plain words.", "The memory detail view with a usage ring, a segmented bar and memory pressure"),
            ("network", "Network", "Live download and upload with a mirrored history, peaks, connection type, your IP addresses and data used since startup.", "The network detail view with live rates, history chart and connection details"),
            ("sensors", "Sensors", "CPU and chip temperatures, fan speeds and your Mac's power draw. The App Store version shows the thermal state instead.", "The sensors detail view with CPU temperature, both fans and power draw"),
            ("battery", "Battery", "Charge, time remaining, maximum capacity, cycle count, charging power and the batteries of your Magic accessories.", "The battery detail view with charge ring, health and cycle count"),
            ("settings", "Settings", "Pick what shows in the menu bar, choose colored indicators, the update interval and whether Puls opens at login.", "The settings view with menu bar switches and general options"),
        ],
        "menubar_title": "Quiet until something needs you.",
        "menubar_lead": "Choose which values sit in your menu bar. Each one keeps its number, so you never have to guess from color alone. The small bar next to it turns from green to yellow to red as the load rises.",
        "menubar_dark_alt": "Puls menu bar item on a dark menu bar",
        "menubar_light_alt": "Puls menu bar item on a light menu bar",
        "legend": [("ok", "Green", "Normal load"), ("warn", "Yellow", "Busy, above 60 percent"), ("high", "Red", "High, above 85 percent")],
        "values_title": "Made to stay out of the way.",
        "values": [
            ("Light on your Mac", "Puls measures every two seconds and uses well under one percent of a single core while doing it."),
            ("Private by design", "No account, no analytics, no ads. Your readings never leave your Mac."),
            ("At home on Tahoe", "Built with SwiftUI and Liquid Glass, in English and German, with light and dark mode."),
        ],
        "compare_title": "Two ways to get Puls.",
        "compare_lead": "Both are free. The App Store version runs in Apple's sandbox, which blocks access to sensors and other apps, so it shows a little less.",
        "compare_head": ("", "GitHub", "Mac App Store"),
        "compare_rows": [
            ("Processor, graphics, memory, network, disk, battery", True, True),
            ("Thermal state, power draw, battery temperature", True, True),
            ("CPU and chip temperatures, fan speeds", True, False),
            ("Busiest processes", True, False),
            ("AirPods battery levels", True, False),
            ("Updates", "Notice in the panel", "Automatic"),
            ("Signed by", "Developer ID, notarized by Apple", "Mac App Store"),
        ],
        "yes": "Included", "no": "Not available",
        "compare_note": "Please install only one of them. Both are called Puls.",
        "faq_title": "Questions",
        "faq": [
            ("Where is Puls after I open it?", "Puls lives in the menu bar and has no Dock icon. Look for its values in the top right of your screen; click them to open the panel, right-click for a small menu."),
            ("How do I quit Puls?", "Right-click the Puls item and choose Quit Puls, or open the settings in the panel and click Quit."),
            ("Does Puls start with my Mac?", "The GitHub version does so from the first launch, the App Store version asks first. You can change it any time in the settings under Open at login."),
            ("Which languages does Puls speak?", "English and German. Puls follows the language in System Settings, General, Language and Region."),
            ("Is Puls really free?", "Yes. Puls is open source under the MIT license, without ads, subscriptions or in-app purchases."),
        ],
        "faq_more": "More answers on the support page.",
        "closing_title": "See what your Mac is doing.",
        "source": "Source code on GitHub",
        "footer_rights": "Puls is made by Vllasa Ventures UG (haftungsbeschränkt).",
        "legal": {"support": "Support", "privacy": "Privacy", "imprint": "Imprint"},
        "skip": "Skip to content",
        "notfound_title": "Page not found",
        "notfound_text": "This page does not exist. Maybe the link is outdated.",
        "notfound_back": "Go to the Puls homepage",
    },
    "de": {
        "lang": "de", "locale": "de_DE", "dir": "de/", "other": "en", "other_label": "English",
        "pages": {"index": "", "support": "support.html", "privacy": "datenschutz.html", "imprint": "impressum.html"},
        "nav": {"features": "Funktionen", "compare": "Versionen", "faq": "Fragen", "support": "Support"},
        "title": "Puls: Systemmonitor für die Mac-Menüleiste",
        "description": "Puls zeigt CPU, Grafik, Speicher, Netzwerk, Festplatte und Akku live in der Mac-Menüleiste, in einem ruhigen Liquid-Glass-Panel für macOS Tahoe. Kostenlos und Open Source.",
        "hero_title": "Dein Mac auf einen Blick.",
        "hero_lead": "Puls sitzt in der Menüleiste und zeigt, was dein Mac gerade tut: Prozessor, Grafik, Speicher, Netzwerk, Festplatte, Thermik und Akku. Ein Klick öffnet die Details.",
        "download": "Für Mac laden",
        "download_meta": f"Version {VERSION}, {SIZE_MB.replace('.', ',')} MB, kostenlos. Braucht macOS 26 Tahoe auf Apple Silicon oder Intel.",
        "appstore_note": "Bald auch im Mac App Store.",
        "stage_alt": "Das Puls-Panel, aus der Menüleiste geöffnet, mit Kacheln für CPU, Grafik, Speicher, Netzwerk, Festplatte, Sensoren und Batterie",
        "menubar_alt": "Puls in der Menüleiste mit CPU, Speicher, Netzwerk und Akku",
        "explore_title": "Jeder Bereich deines Mac, einen Klick tiefer.",
        "explore_lead": "Jede Kachel öffnet eine Detailansicht mit Verlauf, den Zahlen dahinter und was sie bedeuten.",
        "areas": [
            ("cpu", "Prozessor", "Gesamtauslastung, jeder Kern nach Typ, Systemlast und Laufzeit. Die GitHub-Version zeigt zusätzlich die aktivsten Prozesse.", "Die CPU-Detailansicht mit Gesamtauslastung, Balken je Kern und Systemlast"),
            ("memory", "Speicher", "App-Speicher, fester und komprimierter Speicher, Cache, Speicherdruck und Auslagerung, verständlich erklärt.", "Die Speicher-Detailansicht mit Belegungsring, Segmentbalken und Speicherdruck"),
            ("network", "Netzwerk", "Download und Upload live mit gespiegeltem Verlauf, Spitzenwerte, Verbindungsart, deine IP-Adressen und die Datenmenge seit dem Start.", "Die Netzwerk-Detailansicht mit Live-Raten, Verlauf und Verbindungsdetails"),
            ("sensors", "Sensoren", "CPU- und Chip-Temperaturen, Lüfterdrehzahlen und die Leistungsaufnahme. Die App-Store-Version zeigt stattdessen den thermischen Zustand.", "Die Sensoren-Detailansicht mit CPU-Temperatur, beiden Lüftern und Leistungsaufnahme"),
            ("battery", "Batterie", "Ladestand, Restlaufzeit, maximale Kapazität, Ladezyklen, Ladeleistung und die Akkus deines Magic-Zubehörs.", "Die Batterie-Detailansicht mit Ladering, Zustand und Ladezyklen"),
            ("settings", "Einstellungen", "Wähle die Werte für die Menüleiste, farbige Indikatoren, das Aktualisierungsintervall und ob Puls beim Anmelden startet.", "Die Einstellungen mit Schaltern für die Menüleiste und allgemeinen Optionen"),
        ],
        "menubar_title": "Still, bis etwas dich braucht.",
        "menubar_lead": "Wähle, welche Werte in deiner Menüleiste stehen. Jeder behält seine Zahl, du musst also nie nur anhand der Farbe raten. Der kleine Balken daneben wechselt mit steigender Last von Grün über Gelb zu Rot.",
        "menubar_dark_alt": "Puls-Anzeige in einer dunklen Menüleiste",
        "menubar_light_alt": "Puls-Anzeige in einer hellen Menüleiste",
        "legend": [("ok", "Grün", "Normale Last"), ("warn", "Gelb", "Beschäftigt, über 60 Prozent"), ("high", "Rot", "Hoch, über 85 Prozent")],
        "values_title": "Gemacht, um nicht zu stören.",
        "values": [
            ("Leicht für deinen Mac", "Puls misst alle zwei Sekunden und braucht dabei deutlich unter einem Prozent eines einzigen Kerns."),
            ("Privat von Grund auf", "Kein Konto, keine Analyse, keine Werbung. Deine Messwerte verlassen deinen Mac nicht."),
            ("Zu Hause auf Tahoe", "Gebaut mit SwiftUI und Liquid Glass, auf Deutsch und Englisch, in Hell und Dunkel."),
        ],
        "compare_title": "Zwei Wege zu Puls.",
        "compare_lead": "Beide sind kostenlos. Die App-Store-Version läuft in Apples Sandbox, die Sensoren und andere Apps abschirmt, deshalb zeigt sie etwas weniger.",
        "compare_head": ("", "GitHub", "Mac App Store"),
        "compare_rows": [
            ("Prozessor, Grafik, Speicher, Netzwerk, Festplatte, Batterie", True, True),
            ("Thermischer Zustand, Leistungsaufnahme, Akku-Temperatur", True, True),
            ("CPU- und Chip-Temperaturen, Lüfter", True, False),
            ("Aktivste Prozesse", True, False),
            ("Akkustände von AirPods", True, False),
            ("Updates", "Hinweis im Panel", "Automatisch"),
            ("Signiert durch", "Developer ID, von Apple notarisiert", "Mac App Store"),
        ],
        "yes": "Enthalten", "no": "Nicht verfügbar",
        "compare_note": "Bitte nur eine der beiden installieren. Beide heißen Puls.",
        "faq_title": "Fragen",
        "faq": [
            ("Wo ist Puls, nachdem ich es geöffnet habe?", "Puls lebt in der Menüleiste und hat kein Dock-Symbol. Die Werte stehen oben rechts auf dem Bildschirm; ein Klick öffnet das Panel, ein Rechtsklick ein kleines Menü."),
            ("Wie beende ich Puls?", "Rechtsklick auf die Puls-Anzeige und Puls beenden wählen, oder im Panel die Einstellungen öffnen und auf Beenden klicken."),
            ("Startet Puls mit meinem Mac?", "Die GitHub-Version ab dem ersten Start, die App-Store-Version fragt vorher. Ändern kannst du das jederzeit in den Einstellungen unter Beim Anmelden starten."),
            ("Welche Sprachen spricht Puls?", "Deutsch und Englisch. Puls folgt der Sprache in den Systemeinstellungen unter Allgemein, Sprache und Region."),
            ("Ist Puls wirklich kostenlos?", "Ja. Puls ist Open Source unter der MIT-Lizenz, ohne Werbung, Abo oder In-App-Käufe."),
        ],
        "faq_more": "Mehr Antworten auf der Support-Seite.",
        "closing_title": "Sieh, was dein Mac gerade tut.",
        "source": "Quellcode auf GitHub",
        "footer_rights": "Puls ist ein Produkt der Vllasa Ventures UG (haftungsbeschränkt).",
        "legal": {"support": "Support", "privacy": "Datenschutz", "imprint": "Impressum"},
        "skip": "Zum Inhalt springen",
        "notfound_title": "Seite nicht gefunden",
        "notfound_text": "Diese Seite gibt es nicht. Vielleicht ist der Link veraltet.",
        "notfound_back": "Zur Puls-Startseite",
    },
}

# Unterseiten-Inhalte (Artikel), bestehende Texte aus den bisherigen Seiten
ARTICLES = {
    ("en", "support"): ("Support", "Help and contact for Puls, the system monitor for the Mac menu bar.", """
<h1>Support</h1>
<p class="lead">Questions, problems or ideas? Email <a href="mailto:info@vllasa.com">info@vllasa.com</a> or open an <a href="https://github.com/QVllasa/puls/issues">issue on GitHub</a>. We usually reply within two business days.</p>
<h2>Where is Puls after launching it?</h2>
<p>Puls is a menu bar app and does not appear in the Dock. Its item with your live values sits in the top right of the menu bar. Click it to open the panel; right-click for a small menu.</p>
<h2>How do I quit Puls?</h2>
<p>Right-click the Puls item and choose Quit Puls, or open the settings with the gear button in the panel and click Quit.</p>
<h2>How do I start Puls automatically?</h2>
<p>The GitHub version does so from the first launch; the App Store version asks first. You can change it any time in the settings under Open at login.</p>
<h2>Which values can I show in the menu bar?</h2>
<p>CPU, graphics, memory, network, disk, temperature (GitHub version) and battery. Each can be switched on or off, with colored status indicators or in plain monochrome.</p>
<h2>Why doesn’t the App Store version show CPU temperatures and fans?</h2>
<p>Apps from the Mac App Store run in a protected environment, the App Sandbox, which does not allow access to the Mac’s temperature sensors and fans. The App Store version shows your Mac’s thermal state, the power draw and the battery temperature instead. The <a href="https://github.com/QVllasa/puls/releases/latest">free version on GitHub</a> runs without the sandbox and additionally shows CPU temperatures, fan speeds and the busiest processes.</p>
<h2>Can I have both versions installed?</h2>
<p>Please use only one. Both are called Puls; if you switch, quit the old one and delete it from the Applications folder first.</p>
<h2>How do I update Puls?</h2>
<p>The App Store version updates automatically. The GitHub version shows a notice in the panel when a new release is available; download it and replace the app in your Applications folder.</p>
<h2>Which languages are supported?</h2>
<p>English and German. Puls follows the language set in System Settings, General, Language and Region.</p>
<h2>System requirements</h2>
<p>macOS 26 Tahoe or later, on Macs with Apple silicon or Intel.</p>
"""),
    ("de", "support"): ("Support", "Hilfe und Kontakt zu Puls, dem Systemmonitor für die Mac-Menüleiste.", """
<h1>Support</h1>
<p class="lead">Fragen, Probleme oder Ideen? Schreib an <a href="mailto:info@vllasa.com">info@vllasa.com</a> oder eröffne ein <a href="https://github.com/QVllasa/puls/issues">Issue auf GitHub</a>. Wir antworten in der Regel innerhalb von zwei Werktagen.</p>
<h2>Wo finde ich Puls nach dem Start?</h2>
<p>Puls ist eine Menüleisten-App und erscheint nicht im Dock. Die Anzeige mit deinen Werten sitzt oben rechts in der Menüleiste. Ein Klick öffnet das Panel, ein Rechtsklick ein kleines Menü.</p>
<h2>Wie beende ich Puls?</h2>
<p>Rechtsklick auf die Puls-Anzeige und Puls beenden wählen, oder im Panel über das Zahnrad die Einstellungen öffnen und auf Beenden klicken.</p>
<h2>Wie starte ich Puls automatisch mit dem Mac?</h2>
<p>Die GitHub-Version tut das ab dem ersten Start, die App-Store-Version fragt vorher. Ändern lässt sich das jederzeit in den Einstellungen unter Beim Anmelden starten.</p>
<h2>Welche Werte kann ich in der Menüleiste anzeigen?</h2>
<p>CPU, Grafik, Speicher, Netzwerk, Festplatte, Temperatur (GitHub-Version) und Batterie, einzeln an- und abschaltbar, mit farbigen Ampel-Indikatoren oder einfarbig.</p>
<h2>Warum zeigt die App-Store-Version keine CPU-Temperaturen und Lüfter?</h2>
<p>Apps aus dem Mac App Store laufen in einer geschützten Umgebung, der Sandbox, die den Zugriff auf die Temperaturfühler und Lüfter des Mac nicht erlaubt. Die App-Store-Version zeigt stattdessen den thermischen Zustand, die Leistungsaufnahme und die Akku-Temperatur. Die <a href="https://github.com/QVllasa/puls/releases/latest">kostenlose Version auf GitHub</a> läuft ohne Sandbox und zeigt zusätzlich CPU-Temperaturen, Lüfterdrehzahlen und die aktivsten Prozesse.</p>
<h2>Kann ich beide Versionen installieren?</h2>
<p>Bitte nur eine nutzen. Beide heißen Puls; beim Wechsel die alte zuerst beenden und aus dem Programme-Ordner löschen.</p>
<h2>Wie aktualisiere ich Puls?</h2>
<p>Die App-Store-Version aktualisiert sich automatisch. Die GitHub-Version zeigt im Panel einen Hinweis, sobald eine neue Version erscheint; lade sie und ersetze die App im Programme-Ordner.</p>
<h2>Welche Sprachen werden unterstützt?</h2>
<p>Deutsch und Englisch. Puls folgt der Sprache in den Systemeinstellungen unter Allgemein, Sprache und Region.</p>
<h2>Systemvoraussetzungen</h2>
<p>macOS 26 Tahoe oder neuer, auf Macs mit Apple Silicon oder Intel.</p>
"""),
}


def legacy_article(path: pathlib.Path) -> str:
    """Übernimmt den <article>-Inhalt der bisherigen Rechtstexte unverändert."""
    text = path.read_text()
    start = text.index("<article>") + len("<article>")
    return text[start:text.index("</article>")]


# ---------------------------------------------------------------- Bausteine

def head(t: dict, page: str, title: str, description: str, prefix: str) -> str:
    url = f"{BASE}/{t['dir']}{t['pages'][page]}"
    other = STRINGS[t["other"]]
    other_url = f"{BASE}/{other['dir']}{other['pages'][page]}"
    en_url = url if t["lang"] == "en" else other_url
    de_url = url if t["lang"] == "de" else other_url
    ld = ""
    if page == "index":
        data = {
            "@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Puls",
            "operatingSystem": "macOS 26", "applicationCategory": "UtilitiesApplication",
            "softwareVersion": VERSION, "downloadUrl": DOWNLOAD, "url": url, "inLanguage": ["en", "de"],
            "image": f"{BASE}/assets/icon.png", "screenshot": f"{BASE}/screenshots/{t['lang']}/overview-dark.png",
            "description": t["description"], "license": "https://opensource.org/licenses/MIT",
            "offers": {"@type": "Offer", "price": "0", "priceCurrency": "EUR"},
            "author": {"@type": "Organization", "name": "Vllasa Ventures UG (haftungsbeschränkt)", "url": BASE + "/"},
        }
        ld = f'<script type="application/ld+json">{json.dumps(data, ensure_ascii=False)}</script>\n'
    return f"""<!doctype html>
<html lang="{t['lang']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description)}">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#f5f5fa" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#14151c" media="(prefers-color-scheme: dark)">
<link rel="canonical" href="{url}">
<link rel="alternate" hreflang="en" href="{en_url}">
<link rel="alternate" hreflang="de" href="{de_url}">
<link rel="alternate" hreflang="x-default" href="{en_url}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Puls">
<meta property="og:title" content="{html.escape(title)}">
<meta property="og:description" content="{html.escape(description)}">
<meta property="og:url" content="{url}">
<meta property="og:locale" content="{t['locale']}">
<meta property="og:image" content="{BASE}/assets/og-{t['lang']}.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" type="image/png" href="{prefix}assets/favicon.png">
<link rel="apple-touch-icon" href="{prefix}assets/apple-touch-icon.png">
<link rel="stylesheet" href="{prefix}site.css">
{ld}</head>
<body>
<a class="skip" href="#main">{t['skip']}</a>
"""


def header(t: dict, page: str, prefix: str) -> str:
    home = f"{prefix}{t['dir']}"
    other = STRINGS[t["other"]]
    other_href = f"{prefix}{other['dir']}{other['pages'][page]}" or "./"
    anchors = ""
    if page == "index":
        n = t["nav"]
        anchors = f'<a href="#features">{n["features"]}</a><a href="#compare">{n["compare"]}</a><a href="#faq">{n["faq"]}</a>'
    return f"""<header class="site-header">
  <a class="brand" href="{home or './'}"><img src="{prefix}assets/favicon.png" alt="" width="28" height="28"><span>Puls</span></a>
  <nav aria-label="{'Hauptnavigation' if t['lang'] == 'de' else 'Main'}">
    {anchors}<a href="{prefix}{t['dir']}{t['pages']['support']}">{t['nav']['support']}</a>
    <a href="{other_href}" lang="{other['lang']}" hreflang="{other['lang']}">{t['other_label']}</a>
  </nav>
</header>
"""


def footer(t: dict, prefix: str) -> str:
    p = t["pages"]
    base = f"{prefix}{t['dir']}"
    return f"""<footer class="site-footer">
  <p>{t['footer_rights']}</p>
  <nav aria-label="{'Rechtliches' if t['lang'] == 'de' else 'Legal'}">
    <a href="{base}{p['support']}">{t['legal']['support']}</a>
    <a href="{base}{p['privacy']}">{t['legal']['privacy']}</a>
    <a href="{base}{p['imprint']}">{t['legal']['imprint']}</a>
    <a href="{REPO}">GitHub</a>
  </nav>
</footer>
</body>
</html>
"""


def download_block(t: dict, cls: str = "") -> str:
    return f"""<div class="download {cls}">
      <a class="button" href="{DOWNLOAD}">{t['download']}</a>
      <p class="meta">{t['download_meta']}<br>{t['appstore_note']}</p>
    </div>"""


# ---------------------------------------------------------------- Startseite

def index_page(t: dict) -> str:
    lang = t["lang"]
    prefix = "" if lang == "en" else "../"
    shots = f"screenshots/{lang}/"
    out = head(t, "index", t["title"], t["description"], prefix) + header(t, "index", prefix)

    tabs, panels = [], []
    for i, (key, label, text, alt) in enumerate(t["areas"]):
        sel = "true" if i == 0 else "false"
        tabs.append(f'<button role="tab" id="tab-{key}" aria-controls="panel-{key}" aria-selected="{sel}" tabindex="{0 if i == 0 else -1}">'
                    f'<span class="tab-title">{label}</span><span class="tab-text">{text}</span></button>')
        panels.append(f'<div role="tabpanel" id="panel-{key}" aria-labelledby="tab-{key}"{"" if i == 0 else " hidden"}>'
                      f'{img(shots + key + ".png", alt, prefix)}</div>')

    rows = []
    for label, gh, store in t["compare_rows"]:
        def cell(v):
            if v is True:
                return f'<td><span class="mark yes" aria-hidden="true"></span><span class="sr">{t["yes"]}</span></td>'
            if v is False:
                return f'<td><span class="mark no" aria-hidden="true"></span><span class="sr">{t["no"]}</span></td>'
            return f"<td>{v}</td>"
        rows.append(f'<tr><th scope="row">{label}</th>{cell(gh)}{cell(store)}</tr>')

    faq = "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in t["faq"])
    values = "".join(f"<div><h3>{h}</h3><p>{p}</p></div>" for h, p in t["values"])
    legend = "".join(f'<li><span class="swatch {k}" aria-hidden="true"></span><strong>{name}</strong> {desc}</li>' for k, name, desc in t["legend"])
    clock = "Fr. 09:41" if lang == "de" else "Fri 9:41 AM"

    out += f"""<main id="main">
<section class="hero">
  <div class="hero-copy">
    <img class="app-icon" src="{prefix}assets/icon.png" alt="" width="112" height="112">
    <h1>{t['hero_title']}</h1>
    <p class="lead">{t['hero_lead']}</p>
    {download_block(t)}
  </div>
  <figure class="stage">
    <div class="menubar" aria-hidden="true">
      <span class="puls-item"><picture>
        <source srcset="{prefix}{shots}menubar-dark-clear.png" media="(prefers-color-scheme: dark)">
        {img(shots + 'menubar-light-clear.png', '', prefix, scale=3, lazy=False)}
      </picture></span>
      <span class="clock">{clock}</span>
    </div>
    <div class="panel-drop">
      <picture>
        <source srcset="{prefix}{shots}overview-dark.png" media="(prefers-color-scheme: dark)">
        {img(shots + 'overview-light.png', t['stage_alt'], prefix, lazy=False, priority=True, cls='panel')}
      </picture>
    </div>
  </figure>
</section>

<section class="explore" id="features" aria-labelledby="explore-title">
  <div class="section-head">
    <h2 id="explore-title">{t['explore_title']}</h2>
    <p>{t['explore_lead']}</p>
  </div>
  <div class="explorer">
    <div role="tablist" aria-label="{t['nav']['features']}" aria-orientation="vertical">
      {''.join(tabs)}
    </div>
    <div class="explorer-view">
      {''.join(panels)}
    </div>
  </div>
</section>

<section class="menubar-section" aria-labelledby="menubar-title">
  <div class="section-head">
    <h2 id="menubar-title">{t['menubar_title']}</h2>
    <p>{t['menubar_lead']}</p>
  </div>
  <div class="bars">
    <div class="bar dark">{img(shots + 'menubar-dark-clear.png', t['menubar_dark_alt'], prefix, scale=3)}</div>
    <div class="bar light">{img(shots + 'menubar-light-clear.png', t['menubar_light_alt'], prefix, scale=3)}</div>
  </div>
  <ul class="legend">{legend}</ul>
</section>

<section class="values" aria-labelledby="values-title">
  <h2 id="values-title">{t['values_title']}</h2>
  <div class="values-grid">{values}</div>
</section>

<section class="compare" id="compare" aria-labelledby="compare-title">
  <div class="section-head">
    <h2 id="compare-title">{t['compare_title']}</h2>
    <p>{t['compare_lead']}</p>
  </div>
  <div class="table-wrap">
    <table>
      <thead><tr><td></td><th scope="col">{t['compare_head'][1]}</th><th scope="col">{t['compare_head'][2]}</th></tr></thead>
      <tbody>{''.join(rows)}</tbody>
    </table>
  </div>
  <p class="note">{t['compare_note']}</p>
</section>

<section class="faq" id="faq" aria-labelledby="faq-title">
  <h2 id="faq-title">{t['faq_title']}</h2>
  <div class="faq-list">{faq}</div>
  <p class="note"><a href="{t['pages']['support']}">{t['faq_more']}</a></p>
</section>

<section class="closing" aria-labelledby="closing-title">
  <img class="app-icon" src="{prefix}assets/icon.png" alt="" width="96" height="96" loading="lazy">
  <h2 id="closing-title">{t['closing_title']}</h2>
  {download_block(t, 'center')}
  <p class="source"><a href="{REPO}">{t['source']}</a></p>
</section>
</main>
<script>
(() => {{
  const tabs = [...document.querySelectorAll('[role=tab]')];
  const select = (tab, focus) => {{
    tabs.forEach(t => {{
      const on = t === tab;
      t.setAttribute('aria-selected', on);
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
    }});
    if (focus) tab.focus();
  }};
  tabs.forEach((tab, i) => {{
    tab.addEventListener('click', () => select(tab));
    tab.addEventListener('keydown', e => {{
      const d = {{ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1}}[e.key];
      if (d) {{ e.preventDefault(); select(tabs[(i + d + tabs.length) % tabs.length], true); }}
      if (e.key === 'Home') {{ e.preventDefault(); select(tabs[0], true); }}
      if (e.key === 'End') {{ e.preventDefault(); select(tabs[tabs.length - 1], true); }}
    }});
  }});
}})();
</script>
"""
    return out + footer(t, prefix)


def article_page(t: dict, page: str, title: str, description: str, body: str) -> str:
    prefix = "" if t["lang"] == "en" else "../"
    return (head(t, page, f"{title} · Puls", description, prefix) + header(t, page, prefix)
            + f'<main id="main" class="article"><article>{body}</article></main>\n' + footer(t, prefix))


def not_found() -> str:
    en, de = STRINGS["en"], STRINGS["de"]
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{en['notfound_title']} · Puls</title>
<meta name="robots" content="noindex">
<meta name="color-scheme" content="light dark">
<link rel="icon" type="image/png" href="/puls/assets/favicon.png">
<link rel="stylesheet" href="/puls/site.css">
</head>
<body>
<main id="main" class="notfound">
  <img class="app-icon" src="/puls/assets/icon.png" alt="" width="96" height="96">
  <h1>{en['notfound_title']}</h1>
  <p>{en['notfound_text']}</p>
  <p><a class="button" href="/puls/">{en['notfound_back']}</a></p>
  <div lang="de">
    <h2>{de['notfound_title']}</h2>
    <p>{de['notfound_text']} <a href="/puls/de/">{de['notfound_back']}</a></p>
  </div>
</main>
</body>
</html>
"""


# ---------------------------------------------------------------- Ausgabe

def main() -> None:
    legacy = {
        ("en", "privacy"): DOCS / "privacy.html", ("en", "imprint"): DOCS / "imprint.html",
        ("de", "privacy"): DOCS / "de/datenschutz.html", ("de", "imprint"): DOCS / "de/impressum.html",
    }
    legal_bodies = {k: legacy_article(v) for k, v in legacy.items()}
    meta = {
        ("en", "privacy"): ("Privacy Policy", "Privacy policy for the Puls app and this website."),
        ("en", "imprint"): ("Imprint", "Legal notice of Vllasa Ventures UG (haftungsbeschränkt)."),
        ("de", "privacy"): ("Datenschutzerklärung", "Datenschutzerklärung für die App Puls und diese Website."),
        ("de", "imprint"): ("Impressum", "Impressum der Vllasa Ventures UG (haftungsbeschränkt)."),
    }
    urls = []
    for lang, t in STRINGS.items():
        outdir = DOCS / t["dir"]
        outdir.mkdir(parents=True, exist_ok=True)
        (outdir / "index.html").write_text(index_page(t))
        title, desc, body = ARTICLES[(lang, "support")]
        (outdir / t["pages"]["support"]).write_text(article_page(t, "support", title, desc, body))
        for page in ("privacy", "imprint"):
            title, desc = meta[(lang, page)]
            (outdir / t["pages"][page]).write_text(article_page(t, page, title, desc, legal_bodies[(lang, page)]))
        urls += [f"{BASE}/{t['dir']}{p}" for p in t["pages"].values()]
    (DOCS / "404.html").write_text(not_found())
    (DOCS / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {BASE}/sitemap.xml\n")
    items = "".join(f"  <url><loc>{u}</loc></url>\n" for u in urls)
    (DOCS / "sitemap.xml").write_text(f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{items}</urlset>\n')
    print("✓ Webseite erzeugt:", len(urls), "Seiten + 404, Sitemap, robots.txt")


if __name__ == "__main__":
    main()
