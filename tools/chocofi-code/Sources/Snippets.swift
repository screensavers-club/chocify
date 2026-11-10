// Built-in TypeScript practice snippets. Two-space indentation; the trainer skips leading
// spaces for you (like an editor's auto-indent), so only the code itself is typed.
enum Category: String, CaseIterable {
    case basics = "Basics", types = "Types", functions = "Functions", async = "Async", react = "React", weak = "Weak Symbols", folder = "My Code"
}

struct Snippet {
    let title: String
    let category: Category
    let code: String
}

enum Snippets {
    static let all: [Snippet] = [
        // MARK: basics
        Snippet(title: "Constants and template literals", category: .basics, code: """
const name = "Chocofi";
const keys = 36;
const label = `${name} has ${keys} keys`;
console.log(label.toUpperCase());
"""),
        Snippet(title: "Arrays: map, filter, reduce", category: .basics, code: """
const prices = [12, 40, 7.5, 99];
const withTax = prices.map((p) => p * 1.09);
const cheap = withTax.filter((p) => p < 50);
const total = cheap.reduce((sum, p) => sum + p, 0);
"""),
        Snippet(title: "Object destructuring", category: .basics, code: """
const user = { id: 7, name: "Ada", roles: ["admin", "dev"] };
const { id, name, roles = [] } = user;
const [firstRole, ...otherRoles] = roles;
const copy = { ...user, name: name.trim() };
"""),
        Snippet(title: "Optional chaining and nullish", category: .basics, code: """
const city = order?.customer?.address?.city ?? "unknown";
const count = items?.length ?? 0;
const first = items?.[0]?.title;
settings.theme ||= "light";
"""),
        Snippet(title: "Loops", category: .basics, code: """
for (let i = 0; i < rows.length; i++) {
  if (rows[i] === undefined) continue;
  console.log(i, rows[i]);
}
for (const [key, value] of Object.entries(config)) {
  console.log(`${key}=${value}`);
}
"""),
        Snippet(title: "Switch on a string", category: .basics, code: """
switch (event.key) {
  case "ArrowUp":
    move(0, -1);
    break;
  case "ArrowDown":
    move(0, 1);
    break;
  default:
    return;
}
"""),
        Snippet(title: "Comparisons and logic", category: .basics, code: """
const isValid = age >= 18 && age < 65 && !banned;
const isEmpty = list.length === 0 || list == null;
const sign = n > 0 ? 1 : n < 0 ? -1 : 0;
const masked = (flags & 0b0100) !== 0;
"""),
        Snippet(title: "Regular expressions", category: .basics, code: """
const email = /^[\\w.+-]+@[\\w-]+\\.[a-z]{2,}$/i;
const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-");
const [, year, month] = /^(\\d{4})-(\\d{2})/.exec(date) ?? [];
"""),
        // MARK: types
        Snippet(title: "Interface", category: .types, code: """
interface User {
  id: number;
  name: string;
  email?: string;
  readonly createdAt: Date;
  tags: string[];
}
"""),
        Snippet(title: "Union and literal types", category: .types, code: """
type Status = "idle" | "loading" | "done" | "error";
type Result<T> = { ok: true; value: T } | { ok: false; error: string };

function isDone(s: Status): s is "done" {
  return s === "done";
}
"""),
        Snippet(title: "Generics", category: .types, code: """
function first<T>(items: T[]): T | undefined {
  return items[0];
}

function pluck<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}
"""),
        Snippet(title: "Utility types", category: .types, code: """
type UserPatch = Partial<Pick<User, "name" | "email">>;
type ReadonlyUser = Readonly<User>;
type ById = Record<number, User>;
type Keys = keyof User;
type Names = User["name"][];
"""),
        Snippet(title: "Mapped and conditional types", category: .types, code: """
type Nullable<T> = { [K in keyof T]: T[K] | null };
type ElementOf<T> = T extends (infer U)[] ? U : never;
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};
"""),
        Snippet(title: "Enum and satisfies", category: .types, code: """
enum Layer {
  Base,
  Sym,
  Nav,
}

const colors = {
  base: "#ffffff",
  sym: "#7e98ff",
} satisfies Record<string, `#${string}`>;
"""),
        Snippet(title: "Class with private fields", category: .types, code: """
class Counter {
  #count = 0;
  constructor(private readonly step: number = 1) {}

  increment(): number {
    this.#count += this.step;
    return this.#count;
  }
}
"""),
        Snippet(title: "Type guards", category: .types, code: """
function isString(x: unknown): x is string {
  return typeof x === "string";
}

if (isString(input) && input.length > 0) {
  print(input);
} else if (Array.isArray(input)) {
  input.forEach(print);
}
"""),
        // MARK: functions
        Snippet(title: "Arrow functions", category: .functions, code: """
const add = (a: number, b: number): number => a + b;
const square = (n: number) => n ** 2;
const toPair = <A, B>(a: A, b: B): [A, B] => [a, b];
const noop = (): void => {};
"""),
        Snippet(title: "Default and rest parameters", category: .functions, code: """
function greet(name: string, greeting = "Hello", ...extras: string[]) {
  const tail = extras.length ? ` (${extras.join(", ")})` : "";
  return `${greeting}, ${name}!${tail}`;
}
"""),
        Snippet(title: "Overloads", category: .functions, code: """
function parse(input: string): number;
function parse(input: string[]): number[];
function parse(input: string | string[]) {
  return Array.isArray(input) ? input.map(Number) : Number(input);
}
"""),
        Snippet(title: "Closures and currying", category: .functions, code: """
const makeCounter = (start = 0) => {
  let n = start;
  return { next: () => ++n, reset: () => (n = start) };
};

const multiply = (a: number) => (b: number) => a * b;
const double = multiply(2);
"""),
        Snippet(title: "Debounce", category: .functions, code: """
function debounce<T extends (...args: any[]) => void>(fn: T, ms = 200) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  return (...args: Parameters<T>) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}
"""),
        Snippet(title: "Sorting with a comparator", category: .functions, code: """
const sorted = [...users].sort((a, b) => {
  if (a.lastName !== b.lastName) {
    return a.lastName.localeCompare(b.lastName);
  }
  return b.age - a.age;
});
"""),
        // MARK: async
        Snippet(title: "Async/await with fetch", category: .async, code: """
async function getUser(id: number): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }
  return (await res.json()) as User;
}
"""),
        Snippet(title: "Try, catch, finally", category: .async, code: """
try {
  setLoading(true);
  const data = await load();
  setItems(data);
} catch (err) {
  console.error((err as Error).message);
} finally {
  setLoading(false);
}
"""),
        Snippet(title: "Promise.all", category: .async, code: """
const [user, posts, likes] = await Promise.all([
  getUser(id),
  getPosts(id),
  getLikes(id),
]);
const results = await Promise.allSettled(urls.map((u) => fetch(u)));
"""),
        Snippet(title: "Sleep and retry", category: .async, code: """
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function retry<T>(fn: () => Promise<T>, tries = 3): Promise<T> {
  for (let i = 1; ; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i >= tries) throw e;
      await sleep(2 ** i * 100);
    }
  }
}
"""),
        Snippet(title: "Event listeners", category: .async, code: """
const onKey = (e: KeyboardEvent) => {
  if (e.metaKey && e.key === "k") {
    e.preventDefault();
    openPalette();
  }
};
window.addEventListener("keydown", onKey);
return () => window.removeEventListener("keydown", onKey);
"""),
        // MARK: react
        Snippet(title: "Component with props", category: .react, code: """
type ButtonProps = {
  label: string;
  onClick: () => void;
  disabled?: boolean;
};

export function Button({ label, onClick, disabled = false }: ButtonProps) {
  return <button onClick={onClick} disabled={disabled}>{label}</button>;
}
"""),
        Snippet(title: "useState and useEffect", category: .react, code: """
const [items, setItems] = useState<Item[]>([]);
const [query, setQuery] = useState("");

useEffect(() => {
  const ctrl = new AbortController();
  search(query, ctrl.signal).then(setItems);
  return () => ctrl.abort();
}, [query]);
"""),
        Snippet(title: "Rendering a list", category: .react, code: """
<ul className="todos">
  {todos.map((t) => (
    <li key={t.id} className={t.done ? "done" : ""}>
      <input type="checkbox" checked={t.done} onChange={() => toggle(t.id)} />
      {t.title}
    </li>
  ))}
</ul>
"""),
        Snippet(title: "Custom hook", category: .react, code: """
export function useToggle(initial = false) {
  const [on, setOn] = useState(initial);
  const toggle = useCallback(() => setOn((v) => !v), []);
  return [on, toggle] as const;
}
"""),
        Snippet(title: "Reducer", category: .react, code: """
type Action = { type: "add"; text: string } | { type: "remove"; id: number };

function reducer(state: Todo[], action: Action): Todo[] {
  switch (action.type) {
    case "add":
      return [...state, { id: Date.now(), text: action.text }];
    case "remove":
      return state.filter((t) => t.id !== action.id);
  }
}
"""),
    ]
}
