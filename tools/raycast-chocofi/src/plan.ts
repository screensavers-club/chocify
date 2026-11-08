import { LAYERS, LAYER_ORDER, POS, isRight, keyAt, where } from "./keymap";

export type Step = { act: "hold" | "tap" | "release"; layer: string; idx: number; label: string; why?: string };
export type Plan = { title: string; layer: string; steps: Step[]; notes: string[]; holds: number[]; taps: number[] };
type Mod = "cmd" | "alt" | "ctrl" | "shift";

const MOD_ALIASES: Record<string, Mod> = {
  cmd: "cmd", command: "cmd", "⌘": "cmd", gui: "cmd", win: "cmd", super: "cmd", meta: "cmd",
  alt: "alt", opt: "alt", option: "alt", "⌥": "alt",
  ctrl: "ctrl", control: "ctrl", ctl: "ctrl", "⌃": "ctrl",
  shift: "shift", shft: "shift", "⇧": "shift",
};
const KEY_ALIASES: Record<string, string> = {
  spc: "space", " ": "space", return: "enter", ret: "enter", "↵": "enter", "⏎": "enter",
  backspace: "bksp", bs: "bksp", "⌫": "bksp", delete: "del", escape: "esc",
  capslock: "caps", "↑": "up", "↓": "down", "←": "left", "→": "right",
  pageup: "pgup", pagedown: "pgdn", flash: "boot", reset: "boot", bootloader: "boot",
  volup: "vol+", voldown: "vol-", pause: "play", previous: "prev",
  underscore: "_", dash: "-", minus: "-", hyphen: "-", equals: "=", equal: "=", plus: "+",
  lbracket: "[", rbracket: "]", lbrace: "{", rbrace: "}", lparen: "(", rparen: ")",
  quote: "'", dquote: '"', backtick: "`", grave: "`", tilde: "~", pipe: "|", backslash: "\\", slash: "/",
  colon: ":", semicolon: ";", comma: ",", period: ".", dot: ".", question: "?", lt: "<", gt: ">",
  click: "btn1", "left click": "btn1", lclick: "btn1", "right click": "btn2", rclick: "btn2",
  "middle click": "btn3", mclick: "btn3", "scroll up": "wh-up", "scroll down": "wh-down",
  "scroll left": "wh-left", "scroll right": "wh-right", "mouse up": "ms-up", "mouse down": "ms-down",
  "mouse left": "ms-left", "mouse right": "ms-right", slow: "ms-slow", "slow mouse": "ms-slow", precise: "ms-slow",
  bang: "!", at: "@", hash: "#", dollar: "$", percent: "%", caret: "^", amp: "&", star: "*", asterisk: "*",
};
const SHIFTED: Record<string, string> = { "?": "/", ":": ";", "<": ",", ">": ".", _: "-", "{": "[", "}": "]", '"': "'" };
const MOD_SYMBOL: Record<Mod, string> = { cmd: "⌘", alt: "⌥", ctrl: "⌃", shift: "⇧" };
const MOD_NAME: Record<Mod, string> = { cmd: "Cmd", alt: "Option", ctrl: "Ctrl", shift: "Shift" };
const OS_POS: Record<Mod, number> = { cmd: POS.osCmd, alt: POS.osAlt, ctrl: POS.osCtrl, shift: POS.osShift };

function find(id: string): { layer: string; idx: number } | null {
  for (const L of LAYER_ORDER) {
    const i = LAYERS[L].findIndex((x) => x && x.id === id);
    if (i >= 0 && !(L === "BASE" && (i === POS.sym || i === POS.nav))) return { layer: L, idx: i };
  }
  return null;
}
const lab = (layer: string, idx: number) => {
  const k = keyAt(layer, idx);
  return layer === "BASE" ? k!.label : `${k!.label} (${keyAt("BASE", idx)!.label} key)`;
};

// Resolve one key token (already lower-cased name or single char) into {id, mods implied}
function resolveKey(tok: string): { id: string; shift: boolean } | null {
  const raw = tok;
  let t = KEY_ALIASES[raw.toLowerCase()] ?? (raw.length === 1 ? raw : raw.toLowerCase());
  if (t.length === 1 && /[A-Z]/.test(t)) return { id: t.toLowerCase(), shift: true };
  if (SHIFTED[t]) return { id: SHIFTED[t], shift: true };
  if (find(t)) return { id: t, shift: false };
  return null;
}

export function planCombo(mods: Set<Mod>, keyTok: string | null): Plan | string {
  const steps: Step[] = [];
  const notes: string[] = [];
  const keyShown = keyTok == null ? "" : keyTok.length === 1 ? keyTok.toUpperCase() : keyTok[0].toUpperCase() + keyTok.slice(1).toLowerCase();
  const title = [...(["ctrl", "alt", "shift", "cmd"] as Mod[]).filter((m) => mods.has(m)).map((m) => MOD_SYMBOL[m]), keyShown].join("");

  // Only modifiers: show where they live
  if (!keyTok) {
    const holds: number[] = [];
    for (const m of mods) {
      if (m === "cmd") { steps.push({ act: "hold", layer: "BASE", idx: POS.cmdThumb, label: "⌘ Cmd", why: where(POS.cmdThumb) }); holds.push(POS.cmdThumb); }
      if (m === "shift") { steps.push({ act: "hold", layer: "BASE", idx: POS.shiftSlash, label: "/ or Z", why: "hold either pinky key for Shift" }); holds.push(POS.shiftSlash, POS.shiftZ); }
      if (m === "alt" || m === "ctrl") { steps.push({ act: "hold", layer: "BASE", idx: POS.nav, label: "NAV", why: where(POS.nav) }); steps.push({ act: "tap", layer: "NAV", idx: OS_POS[m], label: lab("NAV", OS_POS[m]), why: "one-shot: applies to the next key" }); holds.push(POS.nav); }
    }
    return { title, layer: mods.has("alt") || mods.has("ctrl") ? "NAV" : "BASE", steps, notes, holds, taps: [] };
  }

  const r = resolveKey(keyTok);
  if (!r) return `I don't know the key "${keyTok}". Try a letter, a symbol like _ or {, or a name like enter, left, f5, del.`;
  if (r.shift) mods.add("shift");
  const loc = find(r.id)!;
  const L = loc.layer;
  const holds: number[] = [];
  const hold = (layer: string, idx: number, label: string, why: string) => { steps.push({ act: "hold", layer, idx, label, why }); holds.push(idx); };
  const tap = (layer: string, idx: number, label: string, why: string) => steps.push({ act: "tap", layer, idx, label, why });
  const shiftHold = () => {
    let s = isRight(loc.idx) ? POS.shiftZ : POS.shiftSlash;   // opposite hand
    if (L === "BASE" && loc.idx === s) s = s === POS.shiftZ ? POS.shiftSlash : POS.shiftZ;
    hold("BASE", s, s === POS.shiftZ ? "Z" : "/", `Shift · ${where(s)}`);
  };

  if (L === "MOUSE") {
    // Hold the Backspace thumb past a moment to switch to the mouse layer; its own Shift/Option/Ctrl
    // sit on Z X C, and the Cmd thumb still works for Cmd-click.
    hold("BASE", POS.mouse, "⌫ (hold)", `mouse layer · ${where(POS.mouse)}`);
    if (mods.has("cmd")) hold("BASE", POS.cmdThumb, "⌘ Cmd", where(POS.cmdThumb));
    const MS: Record<string, number> = { shift: POS.msShift, alt: POS.msAlt, ctrl: POS.msCtrl };
    for (const m of ["shift", "alt", "ctrl"] as Mod[]) if (mods.has(m)) hold("MOUSE", MS[m], lab("MOUSE", MS[m]), `${MOD_NAME[m]} · ${where(MS[m])}`);
    notes.push("Hold the ⌫ thumb for a moment before pressing the mouse keys; a quick tap is still Backspace.");
  } else if (L === "NAV") {
    // Arrows, Home/End, Esc, Tab, F-keys: hold NAV and hold modifiers on its home row
    hold("BASE", POS.nav, "NAV", where(POS.nav));
    if (mods.has("cmd")) hold("BASE", POS.cmdThumb, "⌘ Cmd", where(POS.cmdThumb));
    for (const m of ["alt", "ctrl", "shift"] as Mod[]) if (mods.has(m)) hold("NAV", OS_POS[m], lab("NAV", OS_POS[m]), `${MOD_NAME[m]} · ${where(OS_POS[m])}`);
  } else if (L === "ADJUST") {
    hold("BASE", POS.sym, "SYM", where(POS.sym));
    hold("BASE", POS.nav, "NAV", where(POS.nav));
    if (mods.size) notes.push("Modifiers don't combine with ADJUST keys.");
  } else {
    // BASE or SYM key. Ctrl and Option exist only as one-shots on NAV, and on SYM the Cmd thumb
    // shares a thumb with SYM, so those go through the one-shot route first.
    const oneShot = (["cmd", "alt", "ctrl"] as Mod[]).filter((m) => mods.has(m) && (m !== "cmd" || L === "SYM"));
    const needOS = oneShot.length > 0;
    if (needOS) {
      if (mods.has("shift")) oneShot.push("shift");
      hold("BASE", POS.nav, "NAV", where(POS.nav));
      for (const m of oneShot) tap("NAV", OS_POS[m], lab("NAV", OS_POS[m]), `one-shot ${MOD_NAME[m]} · ${where(OS_POS[m])}`);
      steps.push({ act: "release", layer: "BASE", idx: POS.nav, label: "NAV", why: "the one-shots stay armed for the next key" });
      holds.splice(holds.indexOf(POS.nav), 1);
    }
    if (mods.has("cmd") && L === "BASE") hold("BASE", POS.cmdThumb, "⌘ Cmd", where(POS.cmdThumb));
    if (L === "SYM") hold("BASE", POS.sym, "SYM", where(POS.sym));
    if (mods.has("shift") && !(needOS)) shiftHold();
  }
  tap(L, loc.idx, lab(L, loc.idx), where(loc.idx));
  if (r.id === "z" || r.id === "/") notes.push(`Tap ${r.id.toUpperCase()} quickly: held, it becomes Shift.`);
  return { title, layer: L, steps, notes, holds, taps: [loc.idx] };
}

export function parse(query: string): Plan | string | null {
  const q = query.trim();
  if (!q) return null;
  // split on spaces, and on "+" inside a token ("cmd+shift+a"), but keep "+" and "vol+" as keys
  const toks = q.split(/\s+/).filter(Boolean).flatMap((t) =>
    t.length > 1 && t.includes("+") && !KEY_ALIASES[t.toLowerCase()] && !find(t.toLowerCase())
      ? t.split("+").map((x, i, a) => (x === "" && i === a.length - 1 ? "+" : x)).filter(Boolean)
      : [t]);
  const mods = new Set<Mod>();
  const keys: string[] = [];
  for (const t of toks) {
    const m = MOD_ALIASES[t.toLowerCase()];
    if (m) mods.add(m); else keys.push(t);
  }
  if (keys.length > 1 && KEY_ALIASES[keys.join(" ").toLowerCase()]) keys.splice(0, keys.length, keys.join(" "));
  if (keys.length === 1 && keys[0].toLowerCase() === "mouse") {
    return { title: "Mouse layer", layer: "MOUSE", steps: [{ act: "hold", layer: "BASE", idx: POS.mouse, label: "⌫ (hold)", why: `mouse layer · ${where(POS.mouse)}` }],
      notes: ["Right hand: I J K L move, Y H scroll up/down, U O scroll sideways. Left hand: F left click, D right click, S middle click, hold A to move slowly."], holds: [POS.mouse], taps: [] };
  }
  if (keys.length > 1) return `One key at a time: got ${keys.join(", ")}. For a combo, list modifiers then one key, e.g. "cmd shift a".`;
  return planCombo(mods, keys[0] ?? null);
}
