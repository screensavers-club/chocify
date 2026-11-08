import { Action, ActionPanel, Icon, List, LaunchProps, environment } from "@raycast/api";
import { useState } from "react";
import { parse, Plan } from "./plan";
import { boardSvg } from "./render";

const EXAMPLES = ["cmd l", "cmd shift a", "cmd alt e", "ctrl c", "_", "{", "alt left", "cmd shift left", "cmd tab", "esc", "f5", "boot", "mouse", "click", "cmd click", "scroll down"];

function markdown(plan: Plan): string {
  const svg = boardSvg(plan, environment.appearance === "dark");
  const img = `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`;
  const verb = { hold: "Hold", tap: "Tap", release: "Let go of" } as const;
  const steps = plan.steps.map((s, n) => `${n + 1}. **${verb[s.act]} ${s.label}** · ${s.why ?? ""}`).join("\n");
  const notes = plan.notes.length ? `\n\n${plan.notes.map((n) => `> ${n}`).join("\n")}` : "";
  return `## ${plan.title}\n\n![board](${img})\n\n${steps}\n\nThen let go of everything.${notes}`;
}

export default function Command(props: LaunchProps<{ arguments: { query?: string } }>) {
  const [text, setText] = useState(props.arguments.query ?? "");
  const result = parse(text);
  const items = text.trim() ? [text.trim()] : EXAMPLES;
  return (
    <List isShowingDetail searchText={text} onSearchTextChange={setText} searchBarPlaceholder="Key or shortcut: cmd alt e, _, ctrl c, alt left…">
      {items.map((q) => {
        const r = text.trim() ? result : parse(q);
        const ok = r && typeof r !== "string";
        return (
          <List.Item
            key={q}
            title={q}
            subtitle={ok ? (r as Plan).title : undefined}
            icon={ok ? Icon.Keyboard : Icon.QuestionMark}
            detail={<List.Item.Detail markdown={ok ? markdown(r as Plan) : `${typeof r === "string" ? r : "Type a key or shortcut."}`} />}
            actions={
              <ActionPanel>
                {!text.trim() && <Action title="Show This One" icon={Icon.Eye} onAction={() => setText(q)} />}
                {ok && <Action.CopyToClipboard title="Copy Steps" content={(r as Plan).steps.map((s, n) => `${n + 1}. ${s.act} ${s.label}`).join("\n")} />}
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
