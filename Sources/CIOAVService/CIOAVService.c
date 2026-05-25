#include "CIOAVService.h"
#include <dlfcn.h>

typedef CFTypeRef (*create_fn)(CFAllocatorRef, io_service_t);
typedef IOReturn (*rw_fn)(CFTypeRef, uint32_t, uint32_t, void *, uint32_t);
typedef CFDictionaryRef (*display_info_fn)(uint32_t);

static create_fn s_create;
static rw_fn s_read;
static rw_fn s_write;
static display_info_fn s_display_info;
static int s_loaded;

static void load_once(void) {
    if (s_loaded) {
        return;
    }
    s_loaded = 1;

    // CoreDisplay exports the IOAVService symbols on Apple Silicon. dlopen of a
    // shared-cache framework succeeds even without the file on disk.
    void *handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY);
    if (handle == NULL) {
        handle = RTLD_DEFAULT;
    }
    s_create = (create_fn)dlsym(handle, "IOAVServiceCreateWithService");
    s_read = (rw_fn)dlsym(handle, "IOAVServiceReadI2C");
    s_write = (rw_fn)dlsym(handle, "IOAVServiceWriteI2C");
    s_display_info = (display_info_fn)dlsym(handle, "CoreDisplay_DisplayCreateInfoDictionary");
}

int ds_ioav_available(void) {
    load_once();
    return (s_create != NULL && s_read != NULL && s_write != NULL) ? 1 : 0;
}

CFTypeRef ds_ioav_create(io_service_t service) {
    load_once();
    if (s_create == NULL) {
        return NULL;
    }
    return s_create(kCFAllocatorDefault, service);
}

int ds_ioav_write(CFTypeRef service, uint32_t chipAddress, uint32_t dataAddress,
                  void *buffer, uint32_t length) {
    load_once();
    if (s_write == NULL) {
        return kIOReturnUnsupported;
    }
    return s_write(service, chipAddress, dataAddress, buffer, length);
}

int ds_ioav_read(CFTypeRef service, uint32_t chipAddress, uint32_t offset,
                 void *buffer, uint32_t length) {
    load_once();
    if (s_read == NULL) {
        return kIOReturnUnsupported;
    }
    return s_read(service, chipAddress, offset, buffer, length);
}

CFDictionaryRef ds_display_info_dictionary(uint32_t displayID) {
    load_once();
    if (s_display_info == NULL) {
        return NULL;
    }
    return s_display_info(displayID);
}
