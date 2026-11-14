"""
bin2hex.py - Binary to Xilinx COE and VHDL HEX converter
Usage: python scripts/bin2hex.py input.bin output.hex [--coe output.coe]
"""
import sys
import struct

def bin_to_hex(bin_filename, hex_filename, coe_filename=None):
    with open(bin_filename, "rb") as f:
        data = f.read()

    # Pad to 4-byte boundary (32-bit words)
    pad = (4 - (len(data) % 4)) % 4
    data += b"\x00" * pad

    words = []
    for i in range(0, len(data), 4):
        # Unpack little-endian 32-bit unsigned integer
        val = struct.unpack("<I", data[i:i+4])[0]
        words.append(val)

    # Format suitable for VHDL testbench (one 32-bit hex word per line)
    with open(hex_filename, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")

    # Format suitable for Xilinx Block RAM initialization (.coe)
    if coe_filename:
        with open(coe_filename, "w") as f:
            f.write("memory_initialization_radix=16;\n")
            f.write("memory_initialization_vector=\n")
            for i, w in enumerate(words):
                sep = ";" if i == len(words) - 1 else ","
                f.write(f"{w:08x}{sep}\n")

    print(f"[OK] {len(words)} words (32-bit) written: {hex_filename}")
    if coe_filename:
        print(f"[OK] COE file generated: {coe_filename}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python bin2hex.py <input.bin> <output.hex> [output.coe]")
        sys.exit(1)
    coe = sys.argv[3] if len(sys.argv) > 3 else None
    bin_to_hex(sys.argv[1], sys.argv[2], coe)