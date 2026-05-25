#ifndef CIOAVSERVICE_H
#define CIOAVSERVICE_H

#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

/// Thin C wrapper over Apple's private IOAVService API.
///
/// The IOAVService symbols are not in the public SDK, so they are resolved at
/// runtime with dlopen/dlsym. This keeps the Swift side free of undefined
/// symbols and lets `ds_ioav_available()` report cleanly when the API is
/// missing (e.g. on a future OS that removes it).

/// Returns 1 if the IOAVService API resolved successfully, 0 otherwise.
int ds_ioav_available(void);

/// Creates an IOAVService for an IORegistry service node.
/// Returns NULL on failure. Ownership transfers to the caller (Swift ARC
/// releases it automatically thanks to CF_RETURNS_RETAINED).
CFTypeRef ds_ioav_create(io_service_t service) CF_RETURNS_RETAINED;

/// Writes `length` bytes over I2C. Returns an IOReturn code (0 == success).
int ds_ioav_write(CFTypeRef service, uint32_t chipAddress, uint32_t dataAddress,
                  void *buffer, uint32_t length);

/// Reads `length` bytes over I2C. Returns an IOReturn code (0 == success).
int ds_ioav_read(CFTypeRef service, uint32_t chipAddress, uint32_t offset,
                 void *buffer, uint32_t length);

/// CoreDisplay's info dictionary for a display — keys include
/// "IODisplayLocation" (the display's IORegistry path). NULL if unavailable.
/// Ownership transfers to the caller.
CFDictionaryRef ds_display_info_dictionary(uint32_t displayID) CF_RETURNS_RETAINED;

#endif /* CIOAVSERVICE_H */
