# Using Zigulator

Zigulator is a button-driven desktop calculator with expression paste,
history, graphing, and statistics. The first launch starts in Standard mode
with decimal input and degree-based trigonometry. After that, calculator
mode, language, and decimal separator are restored from
`~/.config/zigulator/prefs` (or `$XDG_CONFIG_HOME/zigulator/prefs`).

## Starting the application

From a source checkout with Zig 0.16.0 on `PATH`:

```bash
zig build run
```

To build once and launch the installed artifact:

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/zigulator
```

Use `tools/zig-x86_64-linux-0.16.0/zig` instead of `zig` if using the
repository-local toolchain.

## Main window and modes

Choose a layout from the **View** menu:

- **Simple** provides a compact 4-by-5 keypad with arithmetic, percent,
  backspace, clear, and a smart `()` button.
- **Standard** adds memory, CE, negate, square root, reciprocal, square, and
  power controls.
- **Scientific** adds trigonometry, logarithms, factorial, constants, number
  bases, bitwise operations, and display modifiers.

The display status line shows `M` when memory is populated, the active angle
unit, and any non-decimal base. A highlighted operator and the symbol appended
to the readout show which binary operation is pending.

## Button calculations

Enter the first value, choose an operator, enter the second value, then press
`=` or Enter. Operations execute immediately from left to right. For example,
button input `2 + 3 * 4 =` returns `20`, not `14`. Use expression paste when
standard mathematical precedence is required.

Useful controls:

- **CE** clears the current entry. **C** or Escape clears the whole pending
  calculation and unlocks the calculator after an error.
- **Back** or Backspace removes the last entered digit.
- **+/-** or F9 changes the sign.
- Press `=` repeatedly to apply the last operator and operand again.
- In Simple mode, `()` opens a group when a new value is expected and closes
  the current group after a value. `=` closes remaining groups automatically.

The `%` button follows classic calculator rules. With addition or subtraction,
the entered percentage is based on the first operand, so `200 + 10 % =`
returns `220`. With multiplication or division, it divides the second operand
by 100, so `200 * 10 % =` returns `20`.

## Memory

Zigulator has one memory register:

| Button | Action |
| ------ | ------ |
| `MS` | Store the displayed value |
| `MR` | Recall the stored value |
| `M+` | Add the displayed value to memory |
| `MC` | Clear memory |

The `M` status indicator appears while the register contains a stored value.

## Scientific mode

Scientific mode includes the Standard keypad plus these controls:

- `sin`, `cos`, and `tan` use the selected Deg, Rad, or Grad angle unit.
  `Inv` selects inverse trig functions. `Hyp` selects hyperbolic functions;
  combine both for inverse hyperbolic functions.
- `ln`, `log`, and `exp` provide natural log, base-10 log, and exponential.
- `x^2`, `x^3`, `^`, `n!`, `sqrt`, `1/x`, and `Int` provide common numeric
  operations. `Int` truncates toward zero.
- `pi` and `e` load constants without discarding a pending operation.
- Hex, Dec, Oct, and Bin change the display base. Switching bases truncates
  the displayed value to an integer. A-F entry is enabled only in Hex mode.
- `And`, `Or`, `Xor`, `Not`, and `Lsh` operate on values truncated to signed
  64-bit integers.
- `F-E` forces scientific notation. `dms` displays decimal degrees as packed
  degrees, minutes, and seconds in `D.MMSS` form.
- `Sta` opens Statistics.

## Evaluating pasted expressions

Copy an expression, then press Ctrl+V or choose **Edit → Paste**. A successful
result replaces the display and is added to History. Ctrl+C or **Edit → Copy**
copies the current ungrouped value so it can be pasted back safely.

The parser supports:

| Category | Syntax |
| -------- | ------ |
| Arithmetic | `+ - * /`, unary signs, parentheses |
| Powers and postfix | `^`, `**`, `!`, `%` |
| Bitwise | `&`, `|`, `xor`, `<<`, `>>` |
| Remainder | `mod` |
| Functions | `sqrt`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `ln`, `log`, `exp`, `abs` |
| Constants | `pi`, `e` |
| Literals | decimal, scientific notation, `0x`, `0o`, `0b` |

Power is right-associative and follows mathematical precedence. For example,
`-2^2` is `-4`, while `2^-3` is `0.125`. Parser postfix `%` simply divides by
100, so pasted `50%` is `0.5`; this differs from the `%` button behavior.
Pasted trig expressions use the currently selected angle unit. When comma is
the active decimal separator, clipboard commas are accepted as decimal points.

## History

Open **View → History**. Completed `=` calculations and successful pasted
expressions appear newest first. Select an entry to load its result into the
display. **Clear all** removes history without changing the current value.
History lasts only for the current application session.

## Graphing

Open **View → Graph**. The first row starts as `sin(x)`.

1. Enter an expression in a `yN=` field.
2. Select **Add function** for another curve, up to eight total.
3. Adjust `x min` and `x max`, or pan and zoom directly in the plot.
4. Select the `x` button beside a function to remove it.

Graph expressions use the same parser with `x` bound to each sampled value.
Trig functions always use radians here, regardless of the calculator angle
setting. Invalid syntax displays an inline error. Domain failures create gaps
instead of invalidating the entire curve. Calculator shortcuts are suppressed
while a graph text field has keyboard focus.

## Statistics

Open **View → Statistics** or select `Sta` in Scientific mode.

- `Dat` adds the current display value to the dataset.
- The `x` beside a value removes that item.
- `CAD` clears the dataset.
- Count, sum, mean, and sample standard deviation update immediately.

The dataset lasts only for the current application session.

## Language and decimal separator

Use **View → Language** for English or Brazilian Portuguese. Use
**View → Decimal separator** to select `.` or `,`. The separator changes typed
input, display formatting, copied values, pasted expressions, history, and
statistics. Digit grouping uses the opposite separator in decimal mode.

These two settings, together with the calculator mode under **View**, are
saved immediately when changed and reloaded on the next start.

## Keyboard reference

Shortcuts run when no text field is capturing the keyboard.

| Key | Action |
| --- | ------ |
| `0`-`9` | Enter digits |
| `A`-`F` | Enter Hex digits while Hex is active |
| `+`, `-`, `*`, `/` | Arithmetic operations |
| `^`, `**` | Power |
| Enter, `=` | Evaluate |
| Backspace | Remove the last digit |
| Delete | Clear entry |
| Escape | Clear all |
| F9 | Negate |
| Ctrl+C, Ctrl+V | Copy display, paste expression |
| `(`, `)` | Open or close a calculation group |
| `%` | Calculator percent operation |
| F2, F3, F4 | Deg, Rad, Grad |
| F5, F6, F7, F8 | Hex, Dec, Oct, Bin |
| `s`, `c`, `t` | sin, cos, tan in Scientific mode |
| `l`, `n`, `r` | ln, log, square root in Scientific mode |
| `p`, `!`, `@`, `#` | pi, factorial, square, cube in Scientific mode |
| `i`, `h`, `m`, `v` | Toggle Inv, Hyp, dms, F-E in Scientific mode |

In Hex mode, `A`-`F` are always digits; `c` therefore enters hex C instead of
calling cosine.

## Errors and recovery

Division by zero, invalid function domains, malformed expressions, and numeric
overflow show a localized error and lock normal input. Press CE, Delete, C, or
Escape to clear the error. A failed pasted expression preserves the previous
numeric entry behind the error state.
