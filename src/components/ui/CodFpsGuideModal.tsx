interface CodFpsGuideModalProps {
  open: boolean;
  onClose: () => void;
}

export default function CodFpsGuideModal({ open, onClose }: CodFpsGuideModalProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm px-4">
      <div className="w-full max-w-3xl bg-sq-surface border border-sq-border rounded-2xl shadow-2xl">
        <div className="px-6 py-4 border-b border-sq-border flex items-start justify-between gap-4">
          <div>
            <h2 className="text-lg font-bold text-sq-text">Call of Duty Max FPS Settings</h2>
            <p className="text-xs text-sq-text-muted mt-1">
              Apply these in-game manually after optimization.
            </p>
          </div>
          <button
            onClick={onClose}
            className="px-3 py-1.5 rounded-lg text-xs font-semibold text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors"
          >
            Close
          </button>
        </div>

        <div className="px-6 py-5 text-xs text-sq-text-muted max-h-[70vh] overflow-y-auto space-y-4">
          <section>
            <h3 className="text-sm font-semibold text-sq-text mb-2">Display</h3>
            <ul className="space-y-1">
              <li>Display Mode: Fullscreen Exclusive</li>
              <li>Resolution: Native monitor resolution</li>
              <li>Refresh Rate: Maximum available</li>
              <li>Render Resolution: 100%</li>
              <li>V-Sync: Off</li>
              <li>FOV: 100-110, ADS FOV: Affected, Weapon FOV: Wide</li>
              <li>Motion Blur / Depth of Field: Off, Film Grain: 0.00</li>
            </ul>
          </section>

          <section>
            <h3 className="text-sm font-semibold text-sq-text mb-2">Quality (Competitive)</h3>
            <ul className="space-y-1">
              <li>Preset: Custom</li>
              <li>Texture Resolution: Low (raise only if VRAM headroom is large)</li>
              <li>Texture Filter: Normal to High (Aniso 4x to 8x)</li>
              <li>Particle Quality: Low</li>
              <li>Shader Quality: Low to Medium</li>
              <li>Shadow Map: Low to Normal, Screen Space Shadows: Off</li>
              <li>Ambient Occlusion / SSR / Weather Grid Volumes: Off</li>
              <li>Variable Rate Shading: On</li>
            </ul>
          </section>

          <section>
            <h3 className="text-sm font-semibold text-sq-text mb-2">Upscaling</h3>
            <ul className="space-y-1">
              <li>NVIDIA: DLSS Quality or Balanced (if GPU-limited)</li>
              <li>AMD: FSR Quality or Balanced (if GPU-limited)</li>
              <li>Do not stack multiple upscalers at once</li>
            </ul>
          </section>

          <section>
            <h3 className="text-sm font-semibold text-sq-text mb-2">Audio and Input</h3>
            <ul className="space-y-1">
              <li>Audio Mix: Headphone / Headphone Bass Boost</li>
              <li>Music: 0, Dialogue: ~20, Effects: ~80</li>
              <li>Mouse Filtering: 0, Acceleration: 0, Raw Input: On</li>
              <li>Mouse Polling Rate: 1000Hz or higher</li>
            </ul>
          </section>

          <p className="text-[11px] text-sq-text-dim">
            BO7 cloud sync and auto-detect can overwrite config files; this app restores BO7 template files using direct byte-for-byte copy.
          </p>
        </div>
      </div>
    </div>
  );
}
