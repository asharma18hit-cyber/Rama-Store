import { useCallback, useEffect, useRef, useState } from "react";
import SmokeRing, { smokeRingPresets } from "@/components/ui/smoke-ring";

const MONO = '"Paper Mono", ui-monospace, SFMono-Regular, Menlo, monospace';

type ControlDef = {
  kind: "color" | "slider" | "select" | "checkbox";
  key: string;
  min?: number;
  max?: number;
  step?: number;
  int?: boolean;
  options?: string[];
};

const CONTROLS: ControlDef[] = [
  {
    kind: "color",
    key: "colorBack"
  },
  {
    kind: "slider",
    key: "noiseScale",
    min: 0.01,
    max: 5,
    step: 0.01
  },
  {
    kind: "slider",
    key: "noiseIterations",
    min: 1,
    max: 8,
    step: 1,
    int: true
  },
  {
    kind: "slider",
    key: "radius",
    min: 0,
    max: 1,
    step: 0.01
  },
  {
    kind: "slider",
    key: "thickness",
    min: 0.01,
    max: 1,
    step: 0.01
  },
  {
    kind: "slider",
    key: "innerShape",
    min: 0,
    max: 4,
    step: 0.01
  },
  {
    kind: "slider",
    key: "speed",
    min: 0,
    max: 4,
    step: 0.01
  },
  {
    kind: "slider",
    key: "scale",
    min: 0.01,
    max: 4,
    step: 0.01
  },
  {
    kind: "slider",
    key: "rotation",
    min: 0,
    max: 360,
    step: 1,
    int: true
  },
  {
    kind: "slider",
    key: "offsetX",
    min: -1,
    max: 1,
    step: 0.01
  },
  {
    kind: "slider",
    key: "offsetY",
    min: -1,
    max: 1,
    step: 0.01
  }
];

const PARAM_KEYS = ["colorBack","noiseScale","noiseIterations","radius","thickness","innerShape","speed","scale","rotation","offsetX","offsetY"];

type Params = Record<string, string | number | boolean>;

function pickParams(source: Record<string, unknown>): Params {
  const out: Params = {};
  for (const k of PARAM_KEYS) out[k] = source[k] as string | number | boolean;
  return out;
}

const DEFAULTS = pickParams(smokeRingPresets[0].params as Record<string, unknown>);

function fmt(value: number, def: ControlDef) {
  return def.int ? String(Math.round(value)) : Number(value).toFixed(2);
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, height: 26 }}>
      <div style={{ width: 104, flexShrink: 0, fontSize: 11, color: "#222" }}>{label}</div>
      <div style={{ flex: 1, display: "flex", alignItems: "center", gap: 8 }}>{children}</div>
    </div>
  );
}

function ValueBox({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        width: 58, flexShrink: 0, height: 24, borderRadius: 3,
        background: "rgba(0,0,0,0.055)", display: "flex", alignItems: "center",
        justifyContent: "flex-end", padding: "0 8px", fontSize: 11, color: "#222",
      }}
    >
      {children}
    </div>
  );
}

function Slider({ def, value, onChange }: { def: ControlDef; value: number; onChange: (v: number) => void }) {
  const min = def.min ?? 0;
  const max = def.max ?? 1;
  const pct = Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
  return (
    <>
      <div style={{ position: "relative", flex: 1, height: 24, display: "flex", alignItems: "center" }}>
        <div style={{ position: "absolute", left: 0, right: 0, height: 2, borderRadius: 1, background: "rgba(0,0,0,0.14)" }} />
        <div style={{ position: "absolute", left: 0, width: `${pct}%`, height: 2, borderRadius: 1, background: "#999997" }} />
        <div style={{ position: "absolute", left: `calc(${pct}% - 2.5px)`, width: 5, height: 12, borderRadius: 1, background: "#77756f" }} />
        <input
          type="range"
          min={min}
          max={max}
          step={def.step ?? 0.01}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          aria-label={def.key}
          style={{ position: "absolute", inset: 0, width: "100%", opacity: 0, cursor: "ew-resize" }}
        />
      </div>
      <ValueBox>{fmt(value, def)}</ValueBox>
    </>
  );
}

function ColorRow({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  const [text, setText] = useState(value);
  useEffect(() => setText(value), [value]);
  const commit = () => {
    if (/^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text)) onChange(text);
    else setText(value);
  };
  return (
    <Row label={label}>
      <label
        style={{
          position: "relative", width: 24, height: 24, flexShrink: 0, borderRadius: 3,
          background: value, boxShadow: "inset 0 0 0 1px rgba(0,0,0,0.12)", cursor: "pointer",
        }}
      >
        <input
          type="color"
          value={/^#[0-9a-fA-F]{6}/.test(value) ? value.slice(0, 7) : "#000000"}
          onChange={(e) => onChange(e.target.value)}
          aria-label={`${label} color`}
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", opacity: 0, cursor: "pointer" }}
        />
      </label>
      <div style={{ flex: 1, height: 24, borderRadius: 3, background: "rgba(0,0,0,0.055)", display: "flex", alignItems: "center", padding: "0 8px" }}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => e.key === "Enter" && commit()}
          aria-label={`${label} value`}
          style={{ width: "100%", background: "transparent", border: 0, outline: "none", fontSize: 11, color: "#222", fontFamily: MONO }}
        />
      </div>
    </Row>
  );
}

function SelectRow({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (v: string) => void }) {
  return (
    <Row label={label}>
      <div style={{ position: "relative", flex: 1 }}>
        <select
          value={value}
          onChange={(e) => onChange(e.target.value)}
          aria-label={label}
          style={{
            width: "100%", height: 24, borderRadius: 3, border: 0,
            background: "rgba(0,0,0,0.055)", fontSize: 11, color: "#222",
            fontFamily: MONO, padding: "0 8px", appearance: "none", cursor: "pointer",
          }}
        >
          {options.map((o) => (
            <option key={o} value={o}>{o}</option>
          ))}
        </select>
        <div style={{ position: "absolute", right: 8, top: 9, pointerEvents: "none", borderLeft: "4px solid transparent", borderRight: "4px solid transparent", borderTop: "5px solid #222" }} />
      </div>
    </Row>
  );
}

function PanelButton({ children, onClick }: { children: React.ReactNode; onClick: () => void }) {
  const [hover, setHover] = useState(false);
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        height: 24, borderRadius: 3, border: 0, cursor: "pointer",
        background: hover ? "#8a8a88" : "#999997", color: "#fefefe",
        fontSize: 11, fontFamily: MONO, letterSpacing: "0.2px",
      }}
    >
      {children}
    </button>
  );
}

export default function SmokeRingDemo() {
  const [params, setParams] = useState<Params>({ ...DEFAULTS });
  const [colors, setColors] = useState<string[]>(
    (smokeRingPresets[0].params as Record<string, unknown>).colors as string[],
  );


  const set = (key: string, value: string | number | boolean) => setParams((p) => ({ ...p, [key]: value }));

  const applyPreset = (presetParams: Record<string, unknown>) => {
    setParams(pickParams(presetParams));
    const presetColors = (presetParams as Record<string, unknown>).colors as string[] | undefined;
    if (presetColors) setColors([...presetColors]);
  };

  return (
    <div
      style={{
        display: "flex", alignItems: "stretch", gap: 32, width: "100%", minHeight: "100vh",
        padding: 32, background: "#f8f8f6", fontFamily: MONO, boxSizing: "border-box",
      }}
    >
      <div style={{ flex: 1, minHeight: 480, display: "flex", minWidth: 0 }}>
        <SmokeRing {...(params as object)} colors={colors} style={{ width: "100%", height: "100%" }} />
      </div>

      <div
        style={{
          width: 300, flexShrink: 0, alignSelf: "flex-start", borderRadius: 12,
          background: "#f4f3eb", padding: "12px 12px 14px",
          boxShadow:
            "0px 4px 40px -8px rgba(58,34,17,0.1), 0px 12px 20px -8px rgba(58,34,17,0.2), 0px 0px 0px 1px rgba(58,34,17,0.1)",
        }}
      >
        <div style={{ fontSize: 11, color: "#222", padding: "2px 0 8px" }}>Presets</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
          {smokeRingPresets.map((preset) => (
            <PanelButton key={preset.name} onClick={() => applyPreset(preset.params as Record<string, unknown>)}>
              {preset.name}
            </PanelButton>
          ))}
        </div>

        <div style={{ height: 1, background: "rgba(0,0,0,0.08)", margin: "12px 0" }} />

        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
          <Row label="colorCount">
            <Slider
              def={{ key: "colorCount", kind: "slider", min: 1, max: 10, step: 1, int: true }}
              value={colors.length}
              onChange={(v) => {
                const n = Math.round(v);
                setColors((c) =>
                  n > c.length
                    ? [...c, ...Array.from({ length: n - c.length }, (_, i) => `hsl(${(40 * (c.length + i)) % 360} 60% 50%)`)]
                    : c.slice(0, n),
                );
              }}
            />
          </Row>
          {colors.map((c, i) => (
            <ColorRow key={i} label={`color${i + 1}`} value={c} onChange={(v) => setColors((arr) => arr.map((x, j) => (j === i ? v : x)))} />
          ))}
          {CONTROLS.map((def) => {
            if (def.kind === "color")
              return <ColorRow key={def.key} label={def.key} value={String(params[def.key])} onChange={(v) => set(def.key, v)} />;
            if (def.kind === "select")
              return <SelectRow key={def.key} label={def.key} value={String(params[def.key])} options={def.options ?? []} onChange={(v) => set(def.key, v)} />;
            return (
              <Row key={def.key} label={def.key}>
                <Slider def={def} value={Number(params[def.key])} onChange={(v) => set(def.key, v)} />
              </Row>
            );
          })}
        </div>
      </div>
    </div>
  );
}
