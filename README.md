# mac2jb

**type a SmileBASIC bootstrap into a Nintendo Switch 2 using an Apple silicon Mac acting as a USB HID keyboard.**

mac2jb combines a USB HID text sender with vendored source from
[libusbd](https://github.com/shinyquagsire23/libusbd),
[macos_usb_gadget_poc](https://github.com/shinyquagsire23/macos_usb_gadget_poc),
and [ns2jb](https://gitlab.com/pepsipu/ns2jb).

**End-to-end status:** The maintainer has confirmed successful completion of the entire workflow on the documented M4 MacBook Pro and Switch 2: USB HID connection, complete SmileBASIC bootstrap transfer, saving and running the bootstrap, interactive `RUN`, `REMOVE NSR,&H60000000,&H3FFFFFFF`, and `V=START(...)` commands, and the remaining ns2jb host steps. Both the full game and demo can be used; the demo requires retransferring the bootstrap every session because it cannot save it. This is a verified physical-hardware result for one tested configuration; other hardware and firmware combinations have not been verified.

**Release layout:** the user-tested inherited-indentation implementation is now
`sender.c` and the default `mac2jb-send` executable. `make` and
`scripts/send.sh` use that same source. Earlier experimental senders are not
shipped in this package. This is experimental hardware-specific software,
not a supported general-purpose macOS USB gadget API.

**This fork** adds a native macOS GUI (`gui/`) that runs the whole workflow
from one **JAILBREAK** button, and switches the sender to a **German (QWERTZ)**
console keyboard layout. See [macOS GUI app](#macos-gui-app) and
[keyboard layout](#keyboard-layout).

## confirmed test machine and connection

These are **results from one user's physical hardware testing**, not blanket compatibility claims.

| item | working test configuration |
| --- | --- |
| mac | MacBook Pro with Apple M4, `Mac16,1`, 10-core CPU, 16 GB RAM |
| macOS | `26.4.1` |
| firmware observed | system firmware `18000.101.7`, OS loader `18000.101.7` |
| mac ports available | three USB-C ports: two left, one right |
| mac port used | **all three USB-C ports** with their matching controllers (see mapping below) |
| switch 2 connection | **top or bottom USB-C port on the Switch 2**; both confirmed working |
| switch 2 firmware | 23.0.1 |
| smilebasic version | 4.4.9 |
| switch 2 mode | **docked and undocked**, both consistently working with the tested build |
| cable | USB 2.0 **data-capable USB-C to USB-C** cable |
| USB controller selection | three port/controller pairs confirmed manually; automatic selection added and pending physical validation |
| USB power direction | Switch 2 **must not be charging from the Mac** for USB host enumeration to work; reconnect the cable to correct the power direction |
| gadget driver | `gay.bowser.usbgadget` / `usbgadget.kext`, version `1.01` observed loaded |
| keyboard smoke test | `hello` appeared inside SmileBASIC |
| capitalization | tested corrected inverse Shift handling for letters |
| indentation | inherited-space test sender worked on real SmileBASIC editor |
| bootstrap | full text transfer, saving, and execution confirmed |
| post-bootstrap commands | all three stages completed successfully, including the expected Out of memory response |
| ns2jb host and remaining steps | full end-to-end procedure confirmed successful by the maintainer |
| fast sending | 10 ms and 1 ms were reported to work, but below ~50 ms no noticeable speed improvement; lower settings were less stable |

The first successful USB keyboard test was docked. The next undocked test also succeeded, but several early subsequent attempts failed to enumerate in either mode. In the next build, the tester reported reliable operation **both docked and undocked**. The cause of the initial intermittent behavior was not isolated; it does not characterize the current verified build.

More recent testing confirmed that **either USB-C port on the Switch 2 works**, and that **all three MacBook USB-C ports work with their respective USB controllers**. USB host enumeration also requires that the Switch 2 **not draw charging power from the Mac**. If the Switch is charging from the Mac, disconnect and reconnect the USB-C cable; on the tested setup this corrects the power direction and allows enumeration. The Switch may supply power to the Mac instead. This procedure also works when the Mac is already charging separately, as long as the Mac is not supplying charging power to the Switch.

### tested Mac USB-C port mapping

| physical port on M4 MacBook Pro (`Mac16,1`) | USB controller | status |
| --- | --- | --- |
| upper-left USB-C | `usb-drd1` | confirmed working |
| lower-left USB-C | `usb-drd0` | confirmed working |
| right-side USB-C | `usb-drd3` | confirmed working |

**Automatic controller selection (new):** when `MAC2JB_CONTROLLER` is unset or set to `auto`, mac2jb tries `usb-drd0`, then `usb-drd1`, then `usb-drd3`, allowing **4 seconds for enumeration per controller**. Only after a controller enumerates does the sender transmit text. This behavior applies to both `mac2jb-send` and `mac2jb-commands`. If automatic probing fails, check the cable and charging direction, or set `MAC2JB_CONTROLLER=usb-drd1` (or `usb-drd0` / `usb-drd3`) for the matching physical port. An explicit override bypasses automatic probing. The timeout and automatic probing need physical-hardware validation before being considered verified; existing manual selection remains available.

The physical mapping is confirmed **only for the tested `Mac16,1`**. Do not assume other Apple silicon Macs have identical controller assignments. Some other models may expose `usb-drd2`, `usb-drd4`, or other numbered controllers; this is not verified by mac2jb testing. Auto mode intentionally probes only the three confirmed controllers (`usb-drd0`, `usb-drd1`, `usb-drd3`), while `MAC2JB_CONTROLLER=usb-drdN` accepts controller numbers from 0 through 15 for manual investigation. An accepted number does not guarantee that a controller exists or supports gadget mode.

## SmileBASIC full game vs. demo

mac2jb works with **both the full version and the demo of SmileBASIC** on the
verified Switch 2 setup. The important difference is whether you can **save
the transferred bootstrap** for future sessions:

| SmileBASIC edition | Bootstrap storage | What to do each time you want to run the exploit |
| --- | --- | --- |
| **Full game** | Can save the bootstrap | Transfer and save the bootstrap once. On later sessions, load the saved program, start the ns2jb host, and run **only the post-bootstrap command sender** (`mac2jb-commands`) for the SmileBASIC input stage. |
| **Demo** | Cannot save the bootstrap | Each session, use **the full mac2jb process**: resend the bootstrap with `mac2jb-send`, then start the ns2jb host and run `mac2jb-commands`. |

**Full game:** You do **not** need to resend the bootstrap each time, as long as
the saved program remains available and compatible with your setup. Load it
before sending the post-bootstrap commands.

**Demo:** Because the bootstrap cannot be saved, it must be transferred again
whenever you want to repeat the process. Do not skip Step 5 when starting a new
session in the demo.

Both editions still require the relevant ns2jb host and post-bootstrap stages
for each new execution; saving the bootstrap does not make the exploit permanent.

## before you begin

- Use only a console and computer you own or are authorized to test.
- This project depends on a **third-party experimental kernel extension** and a USB device-controller path that Apple does not provide as a supported general-purpose USB gadget API. The original upstream driver targets older Apple silicon/macOS software.
- The test Mac had **Reduced Security** and **System Integrity Protection (SIP) disabled** temporarily to load the experimental driver. That is a **record of the test environment, not a recommendation** to disable them. These changes reduce protections for your Mac. Review Apple's kernel-extension security guidance and restore your normal security policy after research testing.
- A successful `make`, a loaded kext, a charging indicator, or macOS's accessory-approval prompt **does not** prove USB HID enumeration. The real proof is text appearing on the target.
- The sender **types into the focused editor**. It does not run the code. Unexpected input focus can cause accidental typing elsewhere.
- A USB disconnect or interrupted write may leave the receiver believing a key is still down. The tested sender attempts a neutral HID release report on exit, but that is best-effort. If a key repeats indefinitely, **unplug the cable** to reset the connection.

## files and prerequisites

You need an Apple silicon Mac, Xcode Command Line Tools, **full Xcode for building the kext**, and the checked-in vendored source. For later `ns2jb` network-host work, the pinned project's host also needs Node.js 22+ and an appropriate local network. The complete bootstrap transfer, post-bootstrap command sequence, and ns2jb network-host workflow were successfully tested end-to-end on **Nintendo Switch 2 system software `23.0.1` with SmileBASIC `4.4.9`**. Other software versions have not been verified.

From the extracted project folder (containing `Makefile`):

```sh
xcode-select --install  # only if developer tools are not installed
uname -m
sw_vers -productVersion
bash scripts/check.sh
```

Expected architecture: `arm64`. No upstream clone is needed: the source is under `vendor/`, and the bootstrap to type is `assets/bootstrap.bas`.

## build and test — step by step

### prerequisite: allow legacy kernel extensions in startup security settings

This project depends on an experimental, third-party `usbgadget.kext`. On Apple
silicon, macOS normally blocks legacy kernel extensions unless the startup
disk is configured for **Reduced Security** with kernel-extension management
enabled. This reduces the protection of the computer and should only be done
on a dedicated research machine by someone who understands the risk.

1. Shut down the Mac.
2. Hold the power button until **Loading startup options** appears.
3. Select **Options** and **Continue**, then authenticate if prompted.
4. Open **Utilities → Startup Security Utility**.
5. Select the startup disk, choose **Security Policy**, and select
   **Reduced Security**.
6. Enable **Allow user management of kernel extensions from identified
   developers**, then confirm and restart.
7. Build/install the experimental kext according to its bundled upstream
   instructions. If macOS requests approval, review it in
   **System Settings → Privacy & Security** and restart as directed.

**Important:** The maintainer's tested configuration also had **System
Integrity Protection (SIP) disabled**. Reduced Security and kernel-extension
approval do **not** automatically disable SIP, and we have not established that
SIP must be disabled on every supported macOS configuration. Do not turn it
off automatically as part of setup; investigate any specific code-signing
or loading errors first. Restore your normal security policy when finished
with testing.

Apple documentation:
[Startup security settings on Apple silicon](https://support.apple.com/en-euro/guide/mac-help/mchl768f7291/27/mac/27)
and [installing a custom kernel extension](https://developer.apple.com/documentation/apple-silicon/installing-a-custom-kernel-extension).

### 1. verify the kext already installed on your test Mac

```sh
kmutil showloaded | grep -i usbgadget
```

The experimental kext is built using the Xcode project at:

```text
vendor/macos_usb_gadget_poc/usbgadget/usbgadget.xcodeproj
```

A loaded extension is required but is **not sufficient** for successful gadget mode. Do not change security settings further just because enumeration fails.

### 2. build the default sender

From the project root (the folder containing `Makefile`):

```sh
make clean
make
ls -l mac2jb-send
```

`make` builds the verified inherited-indentation `sender.c` into
`mac2jb-send` and builds `commands.c` into `mac2jb-commands`, signs both ad hoc, and uses a bundled `libusbd.dylib` with an
executable-relative runtime search path. `make clean` removes both senders and
the vendored library binary, so the next `make` recompiles them both.

### 3. test the USB connection before sending code

Use **any of the three Mac USB-C ports** to **either the top or bottom Switch 2 USB-C port** with
a data-capable USB 2.0 USB-C-to-USB-C cable. Both Switch ports work on
the tested console; all three Mac ports have worked with matching controllers. The connection
has been confirmed in docked and undocked use, and mac2jb now attempts to select the controller by enumeration unless you override it.

**Important — USB charging direction:** USB host enumeration will not work
if the Switch 2 is charging from the Mac. If it is, unplug and replug the
USB-C cable. On the tested hardware, reconnecting reverses/corrects the power
direction: the Switch may charge the Mac rather than the Mac charging the
Switch. This also works if the Mac is already connected to a separate charger,
as long as the Switch is not drawing charging power from the Mac.
Open an *empty, focused* SmileBASIC editor.

```sh
bash scripts/test-usb.sh
```

When prompted, press Enter. Check that `hello` appears on the
Switch 2. The script sends text only; it does not press Run. If enumeration
fails, check whether the Switch is charging from the Mac, then unplug and
replug the USB-C cable to correct the power direction. Retry the known-good
Mac port/controller combination or try automatic selection again. Other Macs may use a different controller.

### 4. verify indentation using the included small test

Clear the editor completely. The included `indent-test.bas` contains
`COMMON DEF P$(V#)` followed by nested `VAR`, `FOR`, `NEXT`, `RETURN`, and
`END` statements:

```sh
./mac2jb-send indent-test.bas --delay-ms 50
```

Inspect the received indentation. After each Enter, SmileBASIC carries
the previous line's leading spaces into the next line. The sender
compares that *inherited* indentation with the desired leading spaces from
the file, sending only the extra spaces or Backspaces. It does not use
Home or Shift+Home and does not guess indentation from BASIC keywords.

Expected leading indentation counts for the sample's eight lines:
`0, 1, 1, 2, 1, 1, 0, 0` spaces. These are ordinary single spaces.

### 5. dry-run, then send the full bootstrap

**Demo users:** Repeat this bootstrap transfer every time you start a new
exploit session; the demo cannot save the program. **Full-game users:** Once
you have successfully transferred and saved the bootstrap, skip this transfer
on later sessions and load the saved program instead.

Before sending, make sure the receiving editor is empty and the
correct editor window has focus.

```sh
shasum -a 256 -c assets/bootstrap.bas.sha256
bash scripts/send.sh --dry-run
bash scripts/send.sh --delay-ms 50
```

Press Enter when prompted. `scripts/send.sh` uses the default
**`mac2jb-send`**, so the indent behavior is identical to Step 4.

`assets/bootstrap.bas` is the trimmed copy sent to SmileBASIC; it omits
four introductory comments and the subsequent blank line. Its original
unmodified source remains at `vendor/ns2jb/bootstrap.bas`. The checksum
in `assets/bootstrap.bas.sha256` is for the **trimmed** copy.

Do not interact with the editor while mac2jb is typing. After the sender
reports completion, verify the text is complete and its capitalization,
punctuation, and indentation are correct **before saving or running** the
program. Text transfer alone does not prove successful execution; the maintainer
has now separately confirmed successful bootstrap execution, post-bootstrap
command submission, and completion of the ns2jb network stages on the tested setup.

### 6. start the ns2jb host

The bundled host is `vendor/ns2jb/run.cjs`. Read its pinned README and
configure its network settings before using the wrapper:

```sh
bash scripts/host.sh
```

Keep the host running in a separate Terminal session. **The pairing values change every host run.** Start it through `bash scripts/host.sh`, which publishes the current session command for `mac2jb-commands`. Never reuse a previous `V=START(...)` line. The `V=START(...)`
command below contains specific IP-address and other parameters; verify they
match your actual host configuration before sending it.

### 7. send the post-bootstrap commands

Both senders are included and built by the same `make` command:

```sh
make clean && make
./mac2jb-commands --dry-run
```

No extra `commands.mk` or manual `install_name_tool` commands are required.
The vendored libusbd build sets its install name to `@rpath/libusbd.dylib`,
and both executables use a bundled, executable-relative runtime search path.

Once the host is initialized, open a fresh SmileBASIC session and focus the
command entry. **In the full game**, load the bootstrap you previously saved.
**In the demo**, first repeat Step 5 to transfer the bootstrap because it cannot
be saved. Then run:

```sh
./mac2jb-commands --delay-ms 50
```

The sender pauses for Enter at the start and before each command, then sends it
followed by Enter:

1. `RUN`
2. `REMOVE NSR,&H60000000,&H3FFFFFFF`
3. The **fresh `V=START(...)` command from the currently running host**, loaded automatically from its active session (never hardcoded).

Before the third command it asks you to confirm the expected **Out of memory**
message before pressing Enter to continue. The sender cannot observe the Switch screen or
verify the host/exploit stage automatically; it only types approved commands.
**The maintainer confirmed successful completion of these commands and the
subsequent ns2jb steps with manual controller selection on the documented physical setup.** If a USB key
starts repeating after disconnection, unplug and reconnect the cable.

## keyboard layout

`sender.c` types for a **German (QWERTZ) USB keyboard layout** on the console.
Set the Switch 2 USB keyboard language to German before sending. SmileBASIC on
the tested console inverts Shift, so the sender inverts it for letters, digits
and symbols (AltGr characters such as `@ [ ] | \ { } ~` are sent unchanged).
The dead keys `^` and `` ` `` are followed by a Space so they do not combine
with the next character. Tab is rejected because it triggers editor completion.

`test-operators.c` checks the keycodes that `encode()` produces for the
operators used by the bootstrap. Build and run it from the repository root:

```sh
make
clang -std=c11 -D_POSIX_C_SOURCE=200809L -arch arm64 -Ivendor/libusbd/include \
  -o test-operators test-operators.c -Lvendor/libusbd -lusbd \
  -Wl,-rpath,@executable_path/vendor/libusbd -framework CoreFoundation -framework IOKit
./test-operators   # prints "OK (29 cases)"
```

Users with a US console layout should use the upstream
[cpypwn/mac2jb](https://github.com/cpypwn/mac2jb) sender instead.

## macOS GUI app

`gui/` contains a SwiftUI app that wraps the command-line tools. It does not
replace them: it runs `mac2jb-send`, `scripts/host.sh` and `mac2jb-commands`
and shows their output. The prerequisites above (Reduced Security, loaded
`usbgadget.kext`, Node.js 22+) still apply.

**Requirements:** macOS 14 or later on Apple silicon and a recent Xcode
(the package uses Swift tools 6.4).

### build and run

```sh
make                          # build mac2jb-send and mac2jb-commands first
cd gui
swift build -c release
.build/release/mac2jb_gui
```

You can also open `gui/Package.swift` in Xcode and run the `mac2jb-gui`
scheme. The app finds the repository from the location of its source files,
so keep it inside `gui/`. To point it elsewhere, set `MAC2JB_ROOT` to the
repository root before launching.

### what the JAILBREAK button does

The button is enabled only when all checks pass: `arm64`, Xcode command-line
tools, Node.js 22+, the `usbgadget` kext loaded (`kmutil showloaded`), the
bootstrap file, and both built senders.

1. **Bootstrap.** The app asks whether to type the bootstrap again.
   *Weiter* (continue) runs `mac2jb-send`; *Abbrechen* (cancel) skips it and
   uses a bootstrap you already saved in the full game.
2. **Host.** If `vendor/ns2jb/runs/mac2jb-active-connect.txt` belongs to a
   running host, that host is reused. Otherwise the app starts
   `scripts/host.sh` and waits up to 120 seconds for the session's
   `V=START(...)` command.
3. **Commands.** `mac2jb-commands` types `RUN`,
   `REMOVE NSR,&H60000000,&H3FFFFFFF` and the current `V=START(...)`, in that
   order. Every "press Enter" prompt from the command-line tools appears as a
   dialog; watch the Switch screen before you confirm each step.
4. **HBLauncher (experimental, untested).** Afterwards the app tries to run
   [HBLauncher](https://github.com/ravensclawx/HBLauncher)'s `start.sh` with
   the Mac's LAN address (taken from `en0`, `en1` or `en2`). It looks for
   HBLauncher next to this repository (`../HBLauncher`); set `HBLAUNCHER_DIR`
   to override. HBLauncher documents a Linux host and its own Pico-based
   entry, so this step has not been shown to work with mac2jb.

The ns2jb host keeps running after the commands; stop it with **Host stoppen**.

### Details panel

Status lights, configuration and the console are in the collapsible
**Details** section:

| setting | meaning |
| --- | --- |
| USB Controller | `Auto` probes `usb-drd0`, `usb-drd1`, `usb-drd3`; or pick one explicitly (sets `MAC2JB_CONTROLLER`) |
| Delay (ms) | inter-key pacing passed as `--delay-ms`, 1–2000 ms, default 10 |
| Bootstrap File | file typed by `mac2jb-send`, default `assets/bootstrap.bas` |
| Console Output | live output of all stages; the copy button puts the whole log on the clipboard |

### GUI status

The GUI has typed the bootstrap and the three post-bootstrap commands on a
Mac mini M4 (`Mac16,10`) through a rear USB-C port. A complete ns2jb session
through the GUI has **not** been confirmed yet: in testing, `V=START(...)`
answered `BOOT FAILED 2`. The upstream README notes that this stage is
timing-sensitive and recommends restarting the console before retrying; do
not repeat `REMOVE` in the same SmileBASIC session.

## timing and safety notes

The default inter-key pacing is **50 ms**. Use `--delay-ms N` to change
it (supported range 1–2000 ms; decimal values are accepted and rounded to whole milliseconds). This setting does not control the time
spent inside USB write calls; in testing, settings below around 50 ms
offered little apparent improvement and shorter values sometimes became
unstable.

The sender transmits a press and release for each key, and attempts a
neutral HID report during normal exit or interruption. If the connection
fails after a key press, a release might never reach the Switch and the
key may repeat. **Unplug and reconnect the USB cable** if that happens.
The sender prints elapsed time, cumulative USB write time, pacing time,
and retry counts; this is diagnostic, not proof the target received all
characters.

## troubleshooting

| symptom | what happened during development / what to check |
| --- | --- |
| `dyld: Library not loaded: libusbd.dylib` | the sender lacked an appropriate executable-relative rpath; confirm `-Wl,-rpath,@executable_path/vendor/libusbd` in the Makefile and rebuild |
| `Bad code signature` when loading the kext | macOS refused the experimental kernel extension under the initial security configuration; do not interpret sender compilation as kext approval |
| `Failed to find gay_bowser_usbgadget` | upstream `libusbd` selected only hardcoded `usb-drd2`, which was **absent** from the M4 test Mac; discovered services were `usb-drd0`, `usb-drd1`, `usb-drd3` |
| `Error matching IOUSBDeviceInterface (0)` | appeared transiently even during runs that later found the interface; the zero status alone did not establish a fatal failure |
| `Waiting for USB host enumeration...` | the gadget path was found but the target had not successfully enumerated the HID device; for this test Mac, `usb-drd1` eventually worked |
| Switch 2 charging from the Mac; enumeration fails | USB host enumeration did not work when the Mac was charging the Switch. Unplug and replug the USB-C cable so the Switch no longer draws power from the Mac; the Switch may instead charge the Mac. This also works if the Mac has another charger connected. |
| charging works, keyboard doesn't | Charging alone does not prove USB HID enumeration. Check the charging direction, reconnect the cable, and match the Mac USB-C port to its controller, or use automatic selection. |
| wrong letter case | SmileBASIC mapped unshifted letters to uppercase and shifted letters to lowercase during this test; the sender inverted Shift for letters |
| text typed, but indentation grows incorrectly | the default `sender.c` now implements inherited-space correction; rebuild with `make clean && make` if using an earlier snapshot |
| no indentation | an earlier keyword-based algorithm overcorrected; it was abandoned |
| line breaks disappear | an earlier Shift+Home/Backspace reset deleted newlines; **do not use `--indent-reset`** |
| compiler error at `auto_indent=0;\\n` | this occurred only in an abandoned experimental sender; use the current default `sender.c` and rebuild |
| stuck repeating character after cancellation | key-down was delivered but key-up was missed; stop sender and disconnect/reconnect the cable |
| wrong symbols such as `;` instead of `,` or `_` instead of `-` | the console keyboard language does not match the sender; this fork types for a **German** layout. Set the console to German, or use the upstream US sender |
| Mac mini M4 front USB-C ports: `Failed to find gay_bowser_usbgadget` on `usb-drd2` | on `Mac16,10` the front ports (`usb-drd2`) have the device-tree property `usb-device-disable`, no USB-C port controller, and no `AppleT8132USBXDCI` device controller, so the kext has nothing to attach to. Use a rear USB-C port (`usb-drd0`, `usb-drd1` or `usb-drd3`) |
| `mac2jb-send: no such file or directory` | run `make` from the folder containing `Makefile`, then run `./mac2jb-send` |

## development log: how we got here

This is a **chronological troubleshooting history**, not a Git commit history or independently timestamped lab journal. All observations below come from the tests and logs shared during the project; dates for individual experiments were not consistently recorded.

1. **Bundled the source and bootstrap.** Created the mac2jb integration from pinned `libusbd`, `macos_usb_gadget_poc`, and `ns2jb`, with offline source builds and USB text-sending scripts.
2. **First build/runtime problem: dylib search path.** `mac2jb-send` originally couldn't launch because `libusbd.dylib` wasn't found by the dynamic loader. Added an executable-relative rpath to the Makefile and rebuilt.
3. **Loaded the experimental driver.** After code-signing/security investigation, `kmutil` confirmed `gay.bowser.usbgadget (1.01)` was loaded on the M4 test Mac. SIP was temporarily disabled in that research environment.
4. **Discovered the wrong hardcoded controller.** The first `hello` test failed with `Failed to find gay_bowser_usbgadget`. `ioreg` showed `usb-drd0`, `usb-drd1`, and `usb-drd3` services — **no `usb-drd2`** — while vendored `libusbd` searched for `usb-drd2` in **two places**.
5. **Confirmed service discovery after editing both references.** Replacing the hardcoded controller enabled `libusbd` to connect to `gay_bowser_usbgadget` and its generated `IOUSBDeviceInterface`. Enumeration still initially timed out.
6. **Corrected an HID descriptor inconsistency.** The embedded keyboard report descriptor was **65 bytes**, but the HID descriptor advertised **93 bytes (`0x5D`)**. The updated test build used the actual report length.
7. **Added controller selection.** Instead of editing the C source for every test, introduced `MAC2JB_CONTROLLER` and a controller test script for `usb-drd0`, `usb-drd1`, and `usb-drd3`.
8. **First successful physical USB HID transmission.** With **`usb-drd1`**, the Mac's **upper-left USB-C port**, the Switch 2's **top USB-C port**, a **USB 2.0 data-capable USB-C cable**, and the Switch **docked**, `hello` appeared in SmileBASIC. An undocked attempt reportedly worked once too, but it could not be reproduced consistently.
9. **Worked around intermittent enumeration.** Several docked/undocked tests and Mac ports failed after the first success. Returning to the known port/controller setup eventually restored successful typing. Root cause of the intermittent behavior was **not fully identified**.
10. **Found inverted letter capitalization.** SmileBASIC produced uppercase letters without Shift, and lowercase with Shift on the tested editor. Reversed letter Shift handling in the sender. Symbol and punctuation correctness still requires inspection of the received code.
11. **Transferred bootstrap text.** After dry-run validation and typing tests, the tester confirmed the bootstrap reached the editor. First transfers exposed performance and whitespace problems.
12. **Measured delay behavior.** Lowered pacing from 100 ms to 20, 10, 5, and 1 ms. The tester reported 10 and 1 ms worked, but little perceptible speed increase below about 50 ms; very short delays were less reliable.
13. **Discovered a stuck-key failure mode.** Interrupting a transfer between key-down and key-up could leave a repeating character on the Switch. Added best-effort neutral-report cleanup, bounded retries, and transfer timing statistics.
14. **Removed nonexecutable bootstrap header text.** Removed the first four comment lines and one blank line in the sendable copy, trimming it from **8,108 to 7,804 bytes**, while retaining the untouched upstream copy under `vendor/ns2jb`.
15. **First indentation attempt: literal spaces.** The sender typed every source indent again after SmileBASIC had already carried the previous line's indent. Nested blocks accumulated too many spaces.
16. **Second attempt: keyword-aware “smart” indentation.** Tried guessing new indent levels from `COMMON DEF`, `FOR`, etc. This removed required indentation, because the editor actually inherits whitespace rather than indenting by syntax.
17. **Third attempt: Shift+Home/Backspace reset.** Attempted to clear each new line's indent wholesale. On the console, this also removed line breaks. The method was abandoned.
18. **Determined the editor's real rule.** The tester established that **Enter carries the previous line's manually entered leading spaces**, and extra spaces or Backspace are needed only when the desired indentation changes.
19. **Built a separate inherited-indent sender.** The tested `sender-indent-test.c` tracked the carried-forward indent and applies a per-line difference. A real `COMMON DEF P$(V#)` / `FOR` / `NEXT` / `RETURN` / `END` test typed with correct spaces and newlines. The tester reported that the full bootstrap also worked flawlessly with this approach.
22. **Consolidated the working sender for a manual GitHub push.** The tested `sender-indent-test.c` was promoted to `sender.c`, the default `make` target and scripts were aligned, and the trimmed bootstrap checksum was updated. Previously, the GitHub connector could read files but could not write branches.  The GitHub integration could read `cpypwn/mac2jb` but returned `403 Resource not accessible by integration` for branch creation despite reporting push permission. The maintainer chose to push from the Mac. This entry records an earlier development stage; the corresponding source has since been committed to GitHub.

23. **Added Interactive Post-Bootstrap Command Sender.** Introduced `mac2jb-commands`, an interactive USB HID sender that asks for confirmation before typing `RUN`, `REMOVE NSR,&H60000000,&H3FFFFFFF`, and `V=START(...)`. It is intended for use after the `run.cjs` host is initialized.
24. **Permanent USB Controller Selection Fix.** Updated both libusbd service lookups to use `MAC2JB_CONTROLLER` with `usb-drd1` as the default on the tested M4, instead of hardcoding `usb-drd2`.
25. **Consolidated Builds and Release Packaging.** Both senders now build with `make`; libusbd has an `@rpath` install name; release packaging includes both sender sources; and macOS CI validates compilation and packaging.
26. **Confirmed Successful End-to-End ns2jb Workflow.** The maintainer successfully completed every stage on the documented M4 MacBook Pro (macOS 26.4.1) and Switch 2 (firmware 23.0.1, SmileBASIC 4.4.9): USB HID input, accurate bootstrap transfer, saving and executing the bootstrap, the interactive `RUN`, `REMOVE NSR,&H60000000,&H3FFFFFFF` (with the expected Out of memory message), `V=START(...)`, and the remaining ns2jb network-host procedure. This verifies the entire workflow on the tested hardware, beyond the earlier typing-only and dry-run tests. Other configurations remain unverified.
27. **Documented Full-Game and Demo Workflows.** Confirmed support for both editions of SmileBASIC. The full game can save the bootstrap for later sessions, so only the saved-program loading and post-bootstrap command sequence must be repeated. The demo cannot save the bootstrap, so the complete text-transfer and post-bootstrap procedure must be repeated for every new session.
28. **Confirmed Both Switch USB-C Ports and USB Power-Direction Requirement.** Further testing showed that both the top and bottom USB-C ports on the Switch 2 work, before the other two Mac ports were tested successfully later. USB host enumeration fails when the Switch is charging from the Mac. Unplugging and reconnecting the USB-C cable corrects the power direction on the tested setup, potentially causing the Switch to supply power to the Mac instead. Reconnecting also works when the Mac has separate charging power, provided the Mac is not charging the Switch.


29. **Confirmed All Three Mac USB-C Controllers.** Subsequent hardware testing confirmed upper-left = `usb-drd1`, lower-left = `usb-drd0`, and right-side = `usb-drd3` on the tested M4 MacBook Pro (`Mac16,1`). Both Switch 2 USB-C ports remain compatible.
30. **Added Automatic Controller Selection and Enter-Only Prompts.** Both senders now attempt available controllers in order (`usb-drd0`, `usb-drd1`, `usb-drd3`) with a 4-second enumeration window each, while retaining the `MAC2JB_CONTROLLER` manual override. Text is sent only after successful enumeration. Prompts now require pressing Enter rather than typing `SEND`, `READY`, or `OOM`. The new probing behavior requires another on-device test before release.

31. **Shortened Auto-Selection Timeout and Expanded Manual Controller IDs.** After the maintainer observed USB enumeration completing in about 2 seconds, reduced the automatic probe window from 8 seconds to 4 seconds per controller. Auto mode still tests the three controllers confirmed on the M4 MacBook Pro (`usb-drd0`, `usb-drd1`, `usb-drd3`), while manual `MAC2JB_CONTROLLER` selection now accepts `usb-drd0` through `usb-drd15` for research on other Macs. Added explicit Apple silicon Reduced Security / kernel-extension approval steps to the setup guide; additional controllers and the shorter timeout await validation on physical hardware.

### lessons from the debugging log

A driver **loading** is not the same as a device **enumerating**, and an enumerated keyboard isn't the same as correctly **typing the full program**. Correct HID report lengths, controller selection, key-release safety, case mapping, and editor whitespace behavior all mattered. Keep the smallest working test (a single line, then an indentation sample) before retrying a large transfer.

## repository layout

```text
Makefile                             builds both senders from source
sender.c                             tested inherited-indentation HID sender
commands.c                           interactive post-bootstrap command sender
test-operators.c                     keycode regression test for sender.c
gui/                                 SwiftUI app that runs the full workflow
indent-test.bas                      short indentation test input
assets/bootstrap.bas                 trimmed sendable bootstrap
assets/bootstrap.bas.sha256          checksum of trimmed sendable bootstrap
vendor/ns2jb/bootstrap.bas           original upstream bootstrap
assets/hello.txt                     simple keyboard smoke-test input
scripts/test-controllers.sh          test selectable USB controllers
scripts/test-usb.sh                  send hello using default sender
scripts/send.sh                      send assets/bootstrap.bas using default sender
scripts/check.sh                     prerequisite and checksum verification
scripts/host.sh                      pinned ns2jb host launcher
vendor/libusbd/                      pinned USB device-mode library
vendor/macos_usb_gadget_poc/         pinned research kext source
vendor/ns2jb/                        pinned ns2jb project
upstream.lock                        pinned upstream revision identifiers
```

Use `make-release-zip.command` on macOS to generate a release archive
without compiled binaries or local build artifacts. The vendor source
is included; **the prebuilt, locally approved kernel extension is not**.

## credits and licensing

- [shinyquagsire23](https://github.com/shinyquagsire23) — [libusbd](https://github.com/shinyquagsire23/libusbd) and [macos_usb_gadget_poc](https://github.com/shinyquagsire23/macos_usb_gadget_poc).
- [pepsipu / sammy hajhamid](https://gitlab.com/pepsipu/ns2jb) — original `ns2jb`, SmileBASIC bootstrap, and network host.
- [cpypwn](https://github.com/cpypwn) — mac2jb integration and testing.

This project is independent and not affiliated with Nintendo or SmileBASIC. Respect the licenses and redistribution terms of the vendored upstream projects; an integration-level license does not override third-party rights.

## release maintenance

`make` builds `mac2jb-send` and `mac2jb-commands`. `make clean` removes
both binaries and the vendored dylib; perform a clean rebuild after any
change to vendored libusbd build flags or USB controller code.

```sh
make clean && make
bash make-release-zip.command
```

The release archive includes both sender source files, test inputs, docs,
assets and pinned vendored source; it excludes local compiled binaries.
The prior macOS GitHub Actions workflow passed source builds, dry-runs, checksum
validation, and release packaging. CI cannot itself verify USB operation on actual
hardware, but the maintainer has separately completed the full process on the
documented physical test setup.


## Session-specific V=START command (critical)

**Never hardcode or reuse `V=START(...)`.** The IP address may differ and the
ns2jb host generates four new pairing token values on each launch.
Start the host using `bash scripts/host.sh` in Terminal 1; the included
`scripts/host-wrapper.cjs` copies the newly printed command to
`vendor/ns2jb/runs/mac2jb-active-connect.txt` while the host is running.
In Terminal 2, run `./mac2jb-commands --delay-ms 50`: the sender validates
the command and checks that its associated host process is still active.
If the host is not running, **the sender refuses to transmit any commands**.
This avoids accidentally submitting an old session's pairing token.

`./mac2jb-commands --dry-run` does not require an active host and shows a
placeholder instead. Use `bash scripts/host.sh` rather than invoking
`node vendor/ns2jb/run.cjs` directly, since direct invocation will not create
the active-session record for automatic sending.

The active-session file includes secret pairing values and should not be
committed to Git or included in release archives. The host wrapper removes
it on normal exit; after an abnormal termination, the sender checks whether
the recorded host process is still running.
