#include "CSystem.h"

#ifndef APPSTORE
#include <string.h>

#define KERNEL_INDEX_SMC      2
#define SMC_CMD_READ_BYTES    5
#define SMC_CMD_READ_KEYINFO  9

typedef struct {
    unsigned char major, minor, build, reserved[1];
    unsigned short release;
} SMCKeyData_vers_t;

typedef struct {
    unsigned short version, length;
    unsigned int cpuPLimit, gpuPLimit, memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    unsigned int dataSize, dataType;
    unsigned char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    unsigned int key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    unsigned char result, status, data8;
    unsigned int data32;
    unsigned char bytes[32];
} SMCKeyData_t;

static uint32_t fourcc(const char *s) {
    return ((uint32_t)s[0] << 24) | ((uint32_t)s[1] << 16) | ((uint32_t)s[2] << 8) | (uint32_t)s[3];
}

static kern_return_t smc_call(io_connect_t conn, SMCKeyData_t *in, SMCKeyData_t *out) {
    size_t outSize = sizeof(SMCKeyData_t);
    return IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, in, sizeof(SMCKeyData_t), out, &outSize);
}

int smc_open(io_connect_t *conn) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return -1;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, conn);
    IOObjectRelease(service);
    return kr == KERN_SUCCESS ? 0 : -1;
}

void smc_close(io_connect_t conn) {
    if (conn) IOServiceClose(conn);
}

int smc_read_key(io_connect_t conn, const char *key, uint32_t *type, uint8_t *bytes, uint32_t *size) {
    if (!conn || !key || strlen(key) != 4) return -1;
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));

    in.key = fourcc(key);
    in.data8 = SMC_CMD_READ_KEYINFO;
    if (smc_call(conn, &in, &out) != KERN_SUCCESS || out.result != 0) return -1;

    uint32_t dataSize = out.keyInfo.dataSize;
    uint32_t dataType = out.keyInfo.dataType;
    if (dataSize == 0 || dataSize > 32) return -1;

    memset(&out, 0, sizeof(out));
    in.keyInfo.dataSize = dataSize;
    in.data8 = SMC_CMD_READ_BYTES;
    if (smc_call(conn, &in, &out) != KERN_SUCCESS || out.result != 0) return -1;

    *type = dataType;
    *size = dataSize;
    memcpy(bytes, out.bytes, dataSize);
    return 0;
}

#else

// Store-Version: kein Zugriff auf den SMC (in der Sandbox gesperrt).
int smc_open(io_connect_t *conn) { (void)conn; return -1; }
void smc_close(io_connect_t conn) { (void)conn; }
int smc_read_key(io_connect_t conn, const char *key, uint32_t *type, uint8_t *bytes, uint32_t *size) {
    (void)conn; (void)key; (void)type; (void)bytes; (void)size; return -1;
}

#endif
