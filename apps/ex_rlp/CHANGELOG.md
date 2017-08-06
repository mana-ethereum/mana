# 0.2.1
* Improve typespecs to allow for integers as a valid value to encode in RLP.
# 0.2.0
* Breaking: added option to encode RLP to either hex strings (`"8055FF"`) or binaries (`<<0x80, 0x55, 0xFF>`). The default is now `:binary`.
* Added typespecs and additional test coverage through doctests.
# 0.1.1
* Adds protocols for encoding/decoding maps
