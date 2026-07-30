---
title: Quick Select
description: Select, copy, or paste visible terminal text without the mouse.
---

Press `Control-Shift-Space` to mark text in the active pane with keyboard hints. Quick Select finds visible URLs, paths, hashes, colors, addresses, and long numbers.

Type a lowercase hint to select and copy its text. Type an uppercase hint to select, copy, and paste it into the active terminal.

While Quick Select is open:

- type a hint to narrow the matches
- press Backspace to remove the last key
- press `Control-U` to clear the typed hint
- press Escape to close Quick Select

Quick Select closes if the pane loses focus, changes size, scrolls, or receives new output.

## Configure matching

Add `quick-select-pattern` more than once to check your patterns before the built-in set:

```ini
quick-select-pattern = TICKET-[0-9]+
quick-select-pattern = task/[a-z0-9-]+
```

Disable the built-in patterns when you want only your own:

```ini
quick-select-use-default-patterns = false
```

Change the hint keys with a unique set of lowercase letters:

```ini
quick-select-alphabet = asdfjkl
```

The `quick_select` Ghostty action appears in Supaterm's command palette and can use any Ghostty key binding.
