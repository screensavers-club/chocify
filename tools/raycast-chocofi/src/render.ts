import { GEO, ROT, isRight, keyAt, LAYERS } from "./keymap";
import type { Plan } from "./plan";

const U = 64, S = 56, PULL = 1.4;
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);

export function boardSvg(plan: Plan | null, dark: boolean): string {
  const c = dark
    ? { bg: "#1B1E25", cap: "#272B34", edge: "#3E4552", ink: "#E8EBF0", muted: "#7F8796", hold: "#7E98FF", holdFill: "#22305E", tap: "#FF6E33", tapInk: "#140803", badge: "#E8EBF0", badgeInk: "#1B1E25" }
    : { bg: "#F4F5F8", cap: "#FFFFFF", edge: "#B9C0CC", ink: "#14171D", muted: "#6B7383", hold: "#2A57EE", holdFill: "#DCE3FF", tap: "#EE5419", tapInk: "#FFFFFF", badge: "#14171D", badgeInk: "#FFFFFF" };
  const layer = plan?.layer ?? "BASE";
  const pts = GEO.map(([x, y], i) => [(isRight(i) ? x - PULL : x) * U + U / 2, y * U + U / 2]);
  const W = Math.max(...pts.map((p) => p[0])) + U / 2 + 8, H = Math.max(...pts.map((p) => p[1])) + U / 2 + 10;
  // step number per key, in press order
  const order = new Map<number, number[]>();
  plan?.steps.forEach((s, n) => { if (s.act !== "release") order.set(s.idx, [...(order.get(s.idx) ?? []), n + 1]); });
  const parts: string[] = [];
  parts.push(`<rect x="-8" y="-30" width="${W + 16}" height="${H + 38}" rx="18" fill="${c.bg}"/>`);
  parts.push(`<text x="8" y="-10" font-family="Menlo,monospace" font-size="13" fill="${c.muted}" letter-spacing="2">LAYER · ${layer}</text>`);
  pts.forEach(([x, y], i) => {
    // a key used in a step shows what it does in that step's layer (e.g. S as ⌥ while NAV is held)
    const stepLayer = plan?.steps.filter((st) => st.idx === i).pop()?.layer;
    const shownLayer = stepLayer ?? layer;
    const own = LAYERS[shownLayer][i];
    const k = keyAt(shownLayer, i)!;
    const isTap = plan?.taps.includes(i), isHold = plan?.holds.includes(i) || plan?.steps.some((s) => s.idx === i && s.act !== "release" && !plan.taps.includes(i));
    const fill = isTap ? c.tap : isHold ? c.holdFill : c.cap;
    const stroke = isTap ? c.tap : isHold ? c.hold : c.edge;
    const ink = isTap ? c.tapInk : isHold ? c.hold : own === null && shownLayer !== "BASE" ? c.muted : c.ink;
    const label = k.label;
    const fs = label.length <= 1 ? 22 : label.length <= 3 ? 16 : 13;
    parts.push(`<g transform="translate(${x} ${y}) rotate(${ROT[i] ?? 0})">`);
    parts.push(`<rect x="${-S / 2}" y="${-S / 2}" width="${S}" height="${S}" rx="9" fill="${fill}" stroke="${stroke}" stroke-width="${isTap || isHold ? 3 : 1.4}"/>`);
    if (label) parts.push(`<text x="0" y="${k.sub ? -4 : 1}" text-anchor="middle" dominant-baseline="central" font-family="-apple-system,Helvetica,sans-serif" font-weight="700" font-size="${fs}" fill="${ink}">${esc(label)}</text>`);
    if (k.sub) parts.push(`<text x="0" y="17" text-anchor="middle" font-family="Menlo,monospace" font-size="9" fill="${isTap ? c.tapInk : c.muted}">${esc(k.sub)}</text>`);
    const nums = order.get(i);
    if (nums) {
      const t = nums.join(",");
      const bw = 12 + t.length * 7;
      parts.push(`<rect x="${S / 2 - bw + 6}" y="${-S / 2 - 8}" width="${bw}" height="20" rx="10" fill="${c.badge}"/>`);
      parts.push(`<text x="${S / 2 - bw / 2 + 6}" y="${-S / 2 + 2}" text-anchor="middle" dominant-baseline="central" font-family="Menlo,monospace" font-weight="700" font-size="12" fill="${c.badgeInk}">${t}</text>`);
    }
    parts.push(`</g>`);
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${Math.round(W + 16)}" height="${Math.round(H + 38)}" viewBox="-8 -30 ${W + 16} ${H + 38}">${parts.join("")}</svg>`;
}
