"""Erzeugt Resources/{en,de}.lproj/Localizable.strings aus Resources/l10n/de.json (Englisch = Schlüssel)."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
de = json.loads((root / "Resources/l10n/de.json").read_text())

def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

for lang, table in [("de", de), ("en", {k: k for k in de})]:
    d = root / f"Resources/{lang}.lproj"
    d.mkdir(parents=True, exist_ok=True)
    lines = [f'/* Puls – {lang} (erzeugt von scripts/gen-strings.py, nicht von Hand bearbeiten) */', ""]
    lines += [f'"{esc(k)}" = "{esc(v)}";' for k, v in sorted(table.items(), key=lambda kv: kv[0].lower())]
    (d / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(lang, len(table))
