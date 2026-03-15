# ABCall — Arathi Basin Callout Addon

A compact, one-click callout tool for Arathi Basin. Sends pre-formatted status messages to battleground chat instantly — no typing required.

Compatible with **WoW 1.12.1** and **Turtle WoW**.

---

## Installation

1. Copy the `ABCall` folder into your addons directory:
   ```
   World of Warcraft/Interface/AddOns/ABCall/
   ```
2. The folder should contain:
   ```
   ABCall.lua
   ABCall.toc
   ```
3. Launch the game and enable **ABCall** in the AddOns list on the character select screen.

---

## Usage

The callout frame **automatically appears when you enter Arathi Basin** and hides when you leave.

### Clicking a button
Each button sends a message to battleground chat (`/bg`) immediately on click. No confirmation step required.

### Message format examples
| Button clicked | Message sent |
|---|---|
| ST → Safe | `ST Safe.` |
| LM → 3 | `LM 3` |
| BS → BIG | `BS BIG inc!` |
| GM → Help! | `Help GM!` |
| FM → OMW | `OMW FARM` |
| FM → NDef | `FARM Undefended!` |

> Farm is always spelled out as **FARM** in full. OMW and Help messages swap order so the intent reads first.

---

## Layouts

ABCall has three layouts. The **gold dot in the top-right corner** cycles through them, or use `/abcall layout`.

### Vertical (default)
Columns = bases, rows = message types. Compact and tall.
```
ST    LM    BS    GM    FM
Safe  Safe  Safe  Safe  Safe
1  2  1  2  1  2  1  2  1  2
3 4+  3 4+  3 4+  3 4+  3 4+
BIG   BIG   BIG   BIG   BIG
Help! Help! Help! Help! Help!
NDef  NDef  NDef  NDef  NDef
OMW   OMW   OMW   OMW   OMW
```

### Horizontal
Rows = bases, columns = message types. Wide and short.
```
ST  Safe  1  2  3  4+  BIG  Help!  NDef  OMW
LM  Safe  1  2  3  4+  BIG  Help!  NDef  OMW
BS  Safe  1  2  3  4+  BIG  Help!  NDef  OMW
GM  Safe  1  2  3  4+  BIG  Help!  NDef  OMW
FM  Safe  1  2  3  4+  BIG  Help!  NDef  OMW
```

### Sequential (two-step)
Pick a base, then pick a message. Fewer, larger buttons. Good for one-handed use or smaller screens.
```
[ ST ]  [ LM ]  [ BS ]  [ GM ]  [ FM ]
[  1  ] [  2  ] [  3  ] [ 4+  ]
[ Safe ]        [ Help! ]       [ OMW  ]
```
- Click a base to select it (highlights gold)
- Click a message to send and auto-reset
- Message buttons are dimmed until a base is selected

---

## Hover Highlighting

Hovering over any row (horizontal) or column (vertical) fades out all other bases so you can instantly confirm you're clicking the right one. Highlight clears only when the mouse leaves the frame entirely — no flicker between rows.

---

## Message Customisation

Click the **gold dot in the top-left corner** to open the settings panel.

Each message type has an editable format template:

| Field | Default |
|---|---|
| Safe | `%location% Safe.` |
| Numbers | `%location% %num%` |
| Big | `%location% BIG inc!` |
| Help | `Help %location%!` |
| NDef | `%location% Undefended!` |
| OMW | `OMW %location%` |

**Available tokens:**
- `%location%` — replaced with the base code (`ST`, `LM`, `BS`, `GM`, `FARM`)
- `%num%` — replaced with the number (`1`, `2`, `3`, `4+`) — only meaningful in the Numbers template

**Example custom format:**
```
Numbers: %location% - %num% INCOMING
→ sends: ST - 3 INCOMING
```

Changes apply as soon as you click out of the editbox and are saved automatically.

---

## Saved Settings

Layout preference and message format templates are saved between sessions automatically. No manual saving required.

---

## Commands

| Command | Action |
|---|---|
| `/abcall` | Show or hide the frame |
| `/abcall layout` | Cycle layout: vertical → horizontal → sequential |
| `/abcall debug` | Toggle debug mode (prints messages to chat instead of `/bg`) |

---

## Debug Mode

`/abcall debug` toggles debug mode on. While active, all button clicks print the message to your local chat frame instead of broadcasting to the battleground — useful for testing formats and layouts outside of a BG. Toggle it off before entering a real battleground. Resets to off on each login.

---

## Moving the Frame

Click and drag anywhere on the frame background to reposition it. Position is not saved between sessions.

---

## Troubleshooting

**Frame doesn't auto-show in Arathi Basin:**
Run this in-game to check your exact zone name:
```
/script DEFAULT_CHAT_FRAME:AddMessage(GetRealZoneText())
```
Compare the output to `AB_MAP_NAME` at the top of `ABCall.lua` and update it if needed.
