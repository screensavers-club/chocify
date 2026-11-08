# Chocofi handwired (QMK)

Firmware for the handwired Chocofi in this repo. Pins match the wiring diagram
(Figma "Chocofi handwiring"), not the Chocofi PCB:

| Function | Pro Micro pin | AVR |
|---|---|---|
| Row 0, 1, 2, 3 (thumbs) | A3, A2, A1, A0 | F4, F5, F6, F7 |
| Col 0 (pinky) to Col 4 (inner index) | 4, 5, 6, 7, 8 | D4, C6, D7, E6, B4 |
| Split serial (cable data wire) | 3 | D0 |

Diodes are COL2ROW. Both halves use the same pins and the same firmware file.
The left half is the master: plug USB into the left half.

## Build

    brew install qmk/qmk/qmk
    qmk setup
    cp -r firmware/qmk/handwired/chocofi_hw ~/qmk_firmware/keyboards/handwired/
    qmk compile -kb handwired/chocofi_hw -km default

The .hex lands in ~/qmk_firmware (handwired_chocofi_hw_default.hex).

## Flash

Flash each half on its own, USB only. Either run
`qmk flash -kb handwired/chocofi_hw -km default`, or load the .hex in QMK Toolbox
with Auto-Flash ticked. Then reset the Pro Micro by touching RST to GND once or
twice quickly.

Later reflashes: hold the top outer key (Q on the left, P on the right) while
plugging in, or hold both layer thumbs and press that same key (QK_BOOT).
