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
Each button sends a message to battleground chat (`/bg`) immediately on click. No confirmation, no selection step — just click and it's sent.

### Message format examples
| Button clicked | Message sent |
|---|---|
| ST → Safe | `ST Safe.` |
| LM → BIG | `LM BIG inc!` |
| BS → Help! | `Help BS!` |
| GM → OMW | `OMW GM` |
| FM → NDef | `FARM Undefended!` |

> Note: Farm is always spelled out as **FARM** in full. OMW and Help messages swap the order so the intent reads first.

---

## Layouts

ABCall has two layouts, toggled at any time.

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

### Switching layouts
- Click the **small gold dot** in the top-right corner of the frame
- Or type `/abcall layout`

---

## Hover highlighting

Hovering over any row (horizontal) or column (vertical) fades out all other bases so you can instantly confirm you're clicking the right one. Highlight clears when the mouse leaves the frame entirely.

---

## Commands

| Command | Action |
|---|---|
| `/abcall` | Show or hide the frame |
| `/abcall layout` | Toggle between vertical and horizontal layouts |

---

## Moving the frame

Click and drag anywhere on the frame background to reposition it. Position is not saved between sessions — drag it where you want it after each login.

---

## Notes

- Only sends to **battleground chat**. Will silently fail if used outside a battleground without a manual override (`/abcall` to force-show the frame).
- The frame can be force-shown outside Arathi Basin with `/abcall` for testing or setup purposes.
- To check your current zone name if auto-show isn't triggering, run:
  ```
  /script DEFAULT_CHAT_FRAME:AddMessage(GetRealZoneText())
  ```
  and compare it to `AB_MAP_NAME` at the top of `ABCall.lua`.
