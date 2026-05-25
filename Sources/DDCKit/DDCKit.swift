// DDCKit — the DisplaySwitcher DDC/CI engine.
//
// This file is the module anchor. The engine is organised as:
//   - VCPCode / InputSource ... typed monitor controls
//   - DDCMessage            ... DDC/CI frame build & parse (pure logic)
//   - EDID                  ... display identity parsing (pure logic)
//   - Transport/            ... I2C transport protocol + implementations
//   - Display / DisplayManager ... the public, hardware-facing API
