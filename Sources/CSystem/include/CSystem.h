#ifndef CSYSTEM_H
#define CSYSTEM_H

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <stdint.h>

// MARK: - SMC (System Management Controller)

/// Öffnet eine Verbindung zum AppleSMC-Treiber. Gibt 0 bei Erfolg zurück.
int smc_open(io_connect_t *conn);
void smc_close(io_connect_t conn);

/// Liest einen 4-Zeichen-Schlüssel. `type` bekommt den Datentyp als FourCC,
/// `bytes` (mind. 32 Byte) die Rohdaten, `size` die Länge. Gibt 0 bei Erfolg zurück.
int smc_read_key(io_connect_t conn, const char *key, uint32_t *type, uint8_t *bytes, uint32_t *size);

// MARK: - HID-Temperatursensoren (Apple Silicon)

/// Liefert ein Dictionary Sensorname -> Temperatur in °C (CFNumber, double).
/// Nutzt die IOHIDEventSystem-Schnittstelle, die auch Activity Monitor & Co. verwenden.
CFDictionaryRef _Nullable hid_copy_temperatures(void) CF_RETURNS_RETAINED;

#endif
