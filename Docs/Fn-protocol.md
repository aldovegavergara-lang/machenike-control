# K500-B61 Fn configuration protocol

Supported USB identity: 258A:0049, revision 0103, feature report size 1032 bytes. VID/PID alone is not enough to identify a compatible layout; the app also checks report signatures and the tested layout.

Physical indices come from `Cfg.ini` in the official K500-B61 Windows software. The application is not bundled or redistributed. The package lists key assignment, key combination and macro options; these labels alone do not establish support for arbitrary Fn combinations in its Windows UI.

## Reports

Read key matrix: feature report 05, `05 84 d4 00 00 00`. Response: report 06, 1032 bytes, header `06 84 d4 00 84 00 00 00`.

Records start at byte 8 and contain four bytes `[kind, modifier, reserved, value]`. A kind-02 record selects one of 48 normal/Fn pairs. The normal entry is at record `132 + selector`; the Fn entry is at `180 + selector`. Physical C is record 22. The factory Fn key uses kind 20.

To allocate a previously unused pair for Fn+C, keep the ordinary C record in the normal table and put a reserved F13–F20 output in the Fn table. macOS Carbon then registers that output with the requested modifier. The ordinary C and Shift+C outputs remain intact.

Write header: `06 04 d4 00 40 00 00 00`. It corresponds to the configuration write in the public K500 USB capture cited in the README. After writing, all matrix bytes are read back and checked. The original matrix is backed up for restoration.

## Limits

The right-Shift index in the vendor configuration did not match the tested revision and is excluded from USB editing. Newly editable Fn combinations are restricted to letters whose normal output is verified. The app does not write bootloader or firmware commands, macros, or internal RGB functions through the key editor.

Automated tests use generated synthetic fixtures. They never contain a user's captured USB state and never write those fixtures to a keyboard. A keyboard readback confirms stored configuration; testing a physical keypress is a separate validation step.
