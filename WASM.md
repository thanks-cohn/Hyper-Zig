# ZIGN01D WASM

## The application foundation

ZIGN01D should not become an Android clone first, and it should not inherit the JavaScript world as its founding app layer.

The kernel foundation is Zig. The app foundation should be WebAssembly.

WebAssembly gives ZIGN01D a way to become an app platform without requiring the JVM, Android, Node.js, npm, or a browser engine as the base of the system. Apps can be written in Zig, C, Rust, TinyGo, and later other languages, then compiled into a portable `.wasm` module that ZIGN01D can load, run, restrict, inspect, and log.

The goal is not to run every existing app on day one. The goal is to define a clean app contract that belongs to ZIGN01D.

```text
Zig source  -> app.wasm -> ZIGN01D WASM runtime
C source    -> app.wasm -> ZIGN01D WASM runtime
Rust source -> app.wasm -> ZIGN01D WASM runtime
TinyGo      -> app.wasm -> ZIGN01D WASM runtime
```

The wrong direction is:

```text
WASM -> C -> Zig
WASM -> Zig
JavaScript -> everything
```

ZIGN01D does not need to compile WASM into Zig. ZIGN01D needs to host WASM.

## Core split

```text
Kernel foundation:       Zig
System proof culture:    logs, breadcrumbs, smoke tests, tags
App foundation:          WASM
App package format:      .zapp
Preferred first apps:    Zig-to-WASM and C-to-WASM
JavaScript:              optional guest runtime later, never sovereign
Android/JVM:             compatibility research later, not the base
```

This keeps the operating system clear. Zig builds the machine. WASM opens the app world.

## Why WASM

WASM matters for ZIGN01D because it gives the project a small, portable, sandboxable app target.

A ZIGN01D app should be able to run without knowing the kernel internals. It should talk to the system through a stable set of imports, permissions, logs, and package metadata.

The pitch is simple:

```text
Write once.
Compile to WASM.
Package as .zapp.
Run inside ZIGN01D.
Every app gets permissions, logs, crash breadcrumbs, and a stable host ABI.
```

This is how ZIGN01D can enter the app game without becoming dependent on Android or JavaScript.

## The anti-JavaScript rule

WASM is not JavaScript.

Browsers often use JavaScript to call WASM, but ZIGN01D does not have to. Outside the browser, WASM can be hosted directly by the operating system.

ZIGN01D should follow this rule:

```text
ZIGN01D apps are WASM-first, JavaScript-never-required.
```

A JavaScript or TypeScript runtime can be supported later as a sandboxed compatibility environment, but it must not become the foundation.

```text
JavaScript may be supported.
JavaScript must never be sovereign.
```

No npm as a system dependency. No Node.js as the OS personality. No browser DOM as the first app model. No hidden dependency swamp.

If a JavaScript runtime exists later, it should be packaged as a normal restricted ZIGN01D runtime:

```text
zign01d> runtime install js
zign01d> js run calculator.js
runtime=js-sandbox-v0
permissions=none
app_log=enabled
exit=0
```

## The .zapp package idea

A ZIGN01D app package should be boring, inspectable, and local-first.

Possible early shape:

```text
notes.zapp/
  manifest.zon
  app.wasm
  assets/
  logs/
```

Possible manifest:

```zig
.{
    .id = "org.zign01d.notes",
    .name = "Notes",
    .version = "0.1.0",
    .entry = "app.wasm",
    .runtime = "wasm-interpreter-v0",
    .memory_limit = "4MiB",
    .permissions = .{
        "log.write",
        "ui.basic",
        "fs.notes",
    },
}
```

The package should be easy to inspect from the shell:

```text
zign01d> app inspect notes.zapp
app_id=org.zign01d.notes
entry=app.wasm
runtime=wasm-interpreter-v0
permissions=log.write,ui.basic,fs.notes
memory_limit=4MiB
```

## First host imports

The first WASM host ABI should be tiny. Do not recreate Android. Do not recreate the browser. Do not build a DOM first.

Start with the smallest useful imports:

```text
zlog_write(level, code, message_ptr, message_len)
zapp_exit(code)
ztime_now()
zfs_read(path_ptr, path_len, out_ptr, out_len)
zfs_write(path_ptr, path_len, data_ptr, data_len)
zui_text(x, y, text_ptr, text_len)
zui_button(id, label_ptr, label_len)
```

Every import must be permission-aware and breadcrumbed.

If an app asks for a file without permission, the system should say so clearly:

```text
[ZIGN01D][WARN][APP][APPFS001] app_id=org.zign01d.notes denied fs.write path=/system/config reason=permission-missing permission=fs.system.write
```

Nothing should fail silently.

## First holy moment

The first app milestone should be small and undeniable.

```text
zign01d> wasm run hello.wasm
wasm_module=loaded
wasm_runtime=interpreter-v0
wasm_export=_start
wasm_host_import=zign01d.log
hello from wasm app
wasm_exit_code=0
PASS ZIGN01D WASM HOST V0 smoke
```

This is the moment ZIGN01D becomes more than a kernel experiment. It becomes the seed of an app platform.

## C apps through WASM

C does not need to become Zig. WASM does not need to become Zig.

C can compile to WASM, and ZIGN01D can run the resulting module.

```text
hello.c
  -> clang --target=wasm32 ...
  -> hello.wasm
  -> zign01d> wasm run hello.wasm
```

Expected proof:

```text
zign01d> wasm run hello-c.wasm
wasm_runtime=interpreter-v0
wasm_module=loaded
wasm_language=c
hello from C/WASM app
wasm_exit_code=0
```

This gives ZIGN01D a path to C applications without turning the kernel into C and without inventing a full native C userland first.

## Zig apps through WASM

Zig should be the first-class app language because it matches the kernel culture.

```text
hello.zig
  -> zig build-lib -target wasm32-freestanding ...
  -> hello.wasm
  -> zign01d> wasm run hello.wasm
```

Expected proof:

```text
zign01d> wasm run hello-zig.wasm
wasm_runtime=interpreter-v0
wasm_module=loaded
wasm_language=zig
hello from Zig/WASM app
wasm_exit_code=0
```

## What WASM V0 must not claim

WASM HOST V0 must be honest.

It must not claim:

```text
browser=implemented
javascript=implemented
android_apps=implemented
jvm=implemented
jit=implemented
native_speed=implemented
full_wasi=implemented
networking=implemented
ui_framework=implemented
app_store=implemented
production_sandbox=implemented
```

Honest V0 claims should look more like:

```text
wasm_runtime=interpreter-v0
wasm_validation=minimal-v0
wasm_module_load=implemented-v0
wasm_start_function=implemented-v0
wasm_host_log=implemented-v0
wasm_exit_code=implemented-v0
browser=not-implemented
javascript=not-implemented
android_apps=not-implemented
jvm=not-implemented
jit=not-implemented
full_wasi=not-implemented
production_sandbox=not-implemented
```

## Roadmap placement

WASM should not come before the machine can support it.

The earned path is:

```text
PMM V0
PAGING V0
TARFS / RAMFS V0
SYSCALL V0
USERMODE V0
APP ABI V0
WASM HOST V0
ZAPP PACKAGE V0
WASM UI V0
JS SANDBOX V0 later
ANDROID / ART research much later
```

WASM is not a shortcut around the operating system. It is the app layer that becomes possible once the operating system has enough bones.

## The ZIGN01D app doctrine

ZIGN01D apps should be:

```text
portable
sandboxed
inspectable
permissioned
logged
crash-breadcrumbed
small enough to understand
honest about what they can and cannot do
```

Every app should leave a trail:

```text
app installed
app started
permission requested
permission granted or denied
host import called
file opened
file denied
memory limit reached
trap occurred
exit code returned
crash report written
```

The operating system should make debugging humane. The goal is to reduce a two-hour bug hunt to five minutes by making the trail visible.

## Strategic direction

ZIGN01D should not try to win by becoming Android badly.

ZIGN01D should win by becoming itself:

```text
A proof-first, phone-oriented, WASM-native operating system for repairable computing.
```

That phrase is the north star.

Kernel in Zig. Apps in WASM. Packages as `.zapp`. Logs everywhere. Breadcrumbs everywhere. Honest smoke tests. No fake success.

The first victory is not millions of apps.

The first victory is one app that runs, logs, exits, and proves the platform contract.
