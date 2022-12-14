<div align="center">
  <br>
  <h1>Boom Tower</h1>
  <p>
    <b>A <a href="https://www.lexaloffle.com/pico-8.php">PICO-8</a> infinite tower game.</b><br />
  </p>
  <br>
  <br>
  <img src="./assets/boom-tower-demo.gif" atl="8 second gameplay recording of a small blue-hatted character jumping onto platforms, falling down, then jumping up again" />
</div>

## Files

```
.
├── README.md     This file
├── main.p8       Cart entry point, includes sprites, map, audio
├── main.lua      The game code, included by main.p8
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
