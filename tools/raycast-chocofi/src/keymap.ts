// Mirror of firmware/qmk/handwired/chocofi_hw/keymaps/default/keymap.c.
// Positions 0-29: three rows of ten, left to right across both halves.
// Positions 30-35: thumbs, left to right: dotted, ridged, curved | curved, ridged, dotted.
// Update this file whenever the keymap changes.

export type Key = { label: string; id: string; sub?: string } | null; // null = transparent / unused

const k = (label: string, id = label.toLowerCase(), sub?: string): Key => ({ label, id, sub });
const none: Key = { label: "", id: "" };
const chars = (s: string) => [...s].map((c) => k(c.toUpperCase(), c));

export const LAYERS: Record<string, Key[]> = {
  BASE: [
    ...chars("qwertyuiop"),
    ...chars("asdfghjkl;"),
    k("Z", "z", "hold ⇧"), ...chars("xcvbnm,."), k("/", "/", "hold ⇧"),
    k("⌘", "cmd"), k("SYM", "sym"), k("Space", "space"), k("Enter", "enter"), k("NAV", "nav"), k("⌫", "bksp", "hold: mouse"),
  ],
  SYM: [
    ...chars("1234567890"),
    ...chars("!@#$%^&*()"),
    ...chars("`~\\|-=+[]'"),
    null, null, null, null, null, k("Del", "del"),
  ],
  NAV: [
    k("Esc", "esc"), k("Tab", "tab"), k("Caps", "caps"), none, none,
    k("PgUp", "pgup"), k("Home", "home"), k("↑", "up"), k("End", "end"), k("Del", "del"),
    k("⌘", "os-cmd", "1-shot"), k("⌥", "os-alt", "1-shot"), k("⌃", "os-ctrl", "1-shot"), k("⇧", "os-shift", "1-shot"), none,
    k("PgDn", "pgdn"), k("←", "left"), k("↓", "down"), k("→", "right"), k("⌫", "bksp"),
    ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => k("F" + n, "f" + n)),
    null, null, null, null, null, null,
  ],
  ADJUST: [
    k("Boot", "boot", "flash"), none, none, none, none, none, none, k("iPad", "ipad signals", "toggle ipad"), none, k("Boot", "boot", "flash"),
    k("F11", "f11"), k("F12", "f12"), none, none, none,
    k("Prev", "prev"), k("Vol−", "vol-"), k("Vol+", "vol+"), k("Next", "next"), k("Play", "play"),
    none, none, none, none, none, none, k("Mute", "mute"), none, none, none,
    null, null, null, null, null, null,
  ],
  MOUSE: [
    none, none, none, none, none, k("Scr↑", "wh-up"), k("Scr←", "wh-left"), k("↑", "ms-up"), k("Scr→", "wh-right"), none,
    k("Slow", "ms-slow", "hold"), k("Mid", "btn3", "click"), k("Right", "btn2", "click"), k("Left", "btn1", "click"), none,
    k("Scr↓", "wh-down"), k("←", "ms-left"), k("↓", "ms-down"), k("→", "ms-right"), none,
    k("⇧", "ms-shift"), k("⌥", "ms-alt"), k("⌃", "ms-ctrl"), none, none, none, none, none, none, none,
    null, k("Right", "btn2", "click"), k("Left", "btn1", "click"), none, none, null,
  ],
};
export const LAYER_ORDER = ["BASE", "SYM", "NAV", "ADJUST", "MOUSE"];
export const keyAt = (layer: string, i: number): Key => LAYERS[layer][i] ?? LAYERS.BASE[i];

// Fixed keys used to build sequences
export const POS = { cmdThumb: 30, sym: 31, nav: 34, mouse: 35, msShift: 20, msAlt: 21, msCtrl: 22, shiftZ: 20, shiftSlash: 29, osCmd: 10, osAlt: 11, osCtrl: 12, osShift: 13 };

// Layout geometry (keyboard.json, x/y in key units) and thumb rotation
export const GEO: [number, number][] = [
  [0, .6], [1, .3], [2, 0], [3, .4], [4, .5], [8, .5], [9, .4], [10, 0], [11, .3], [12, .6],
  [0, 1.6], [1, 1.3], [2, 1], [3, 1.4], [4, 1.5], [8, 1.5], [9, 1.4], [10, 1], [11, 1.3], [12, 1.6],
  [0, 2.6], [1, 2.3], [2, 2], [3, 2.4], [4, 2.5], [8, 2.5], [9, 2.4], [10, 2], [11, 2.3], [12, 2.6],
  [2.5, 3.6], [3.5, 3.8], [4.6, 4.1], [7.4, 4.1], [8.5, 3.8], [9.5, 3.6],
];
export const ROT: Record<number, number> = { 30: 0, 31: 5, 32: 13, 33: -13, 34: -5, 35: 0 };
export const isRight = (i: number) => (i < 30 ? i % 10 >= 5 : i >= 33);

const FINGERS = ["pinky", "ring", "middle", "index", "index"];
const THUMBS = ["dotted", "ridged", "curved", "curved", "ridged", "dotted"];
export function where(i: number): string {
  if (i >= 30) return `${i < 33 ? "left" : "right"} thumb, ${THUMBS[i - 30]} key`;
  const r = Math.floor(i / 10), c = i % 10, right = c >= 5;
  return `${right ? "right" : "left"} ${right ? FINGERS[9 - c] : FINGERS[c]}, ${["top", "home", "bottom"][r]} row`;
}
