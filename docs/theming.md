# Chrome Styling

Supaterm chrome has one default look. The mac app owns the palette, window background, blurred card styling, selectable row style, and grain texture in `apps/mac/supaterm/Features/Chrome`.

## Consumption

- Views take an explicit `let palette: Palette` and read semantic chrome tokens.
- `TerminalView` builds `Palette(colorScheme:)` from the resolved chrome color scheme.
- `ChromeBackgroundView` renders the fixed opaque window ramp with deterministic grain.
- Spaces store identity and name only; the create and rename flows do not expose chrome choices.

## Boundaries

Deliberately outside the palette: Ghostty terminal content colors, the Ghostty terminal progress bar, the window traffic lights, and Settings feature form styling.

## Snapshots

Default chrome changes can refresh snapshot baselines with `make mac-record-snapshots`. The Chrome catalog group renders the window background and palette token sheet for review.
