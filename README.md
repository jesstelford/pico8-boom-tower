# PICO-8 Starter Project

## Files

```
.
├── README.md     This file
├── main.p8       The main cart entry point
├── main.lua      The code for your game, included by main.p8
├── debugger.lua  Useful debugging methods
└── *.sh          Various scripts (see below)
```

## Scripts

### `start.sh`

Run your game in the PICO-8 console

### `watch.sh`

Watch for changes in any `.p8` or `.lua` file and automatically build a HTML/JS
export (saved to `export/`).

### `serve.sh`

Serve a HTML/JS export (from `export/`), and automatically reload the browser
when that export changes.

Works great with `watch.sh`.
