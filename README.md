# statorio

This mod is based on [`graftorio2`](https://github.com/remijouannet/graftorio2).
See [Attribution](#attribution).

## Intro

- Make yourself familiar with the structure of Factorio [Application directory](https://wiki.factorio.com/Application_directory)
- The instructions assume that the OS is Linux and the Application directory is `~/.factorio`


## Development

- Use Visual Studio Code
    - Install this plugin: https://marketplace.visualstudio.com/items?itemName=justarandomgeek.factoriomod-debug
    - Select the Factorio binary in the bottom bar

Here is what your `.vscode/settings.json` might look like after this:

```json
{
    "factorio.versions": [
        {
            "name": "steam",
            "factorioPath": "/home/{username}/.steam/steam/steamapps/common/Factorio/bin/x64/factorio"
        }
    ],
    "Lua.workspace.userThirdParty": [
        "/home/{username}/.config/Code/User/workspaceStorage/ba3391d3778925ecb1006e8e1d038d97/justarandomgeek.factoriomod-debug/sumneko-3rd"
    ],
    "Lua.workspace.checkThirdParty": "ApplyInMemory"
}
```


## Installation

To install the mod, it's enough to copy the `mod` directory into your Factorio mods folder like this:

```sh
# Note: the directory name MUST be `{mod-name}_{version}`.
rm -rf ~/.factorio/mods/statorio_0.0.1 && cp -r mod ~/.factorio/mods/statorio_0.0.1
```

Then you can enable the mod in-game.
Once the mod is activated, you don't actually need to reload/reopen the game whenever you re-install the mod this way.
I assume that only works because the mod does not need to load any resources.

When the mod is loaded and a savefile is running, the mod will periodically write into a file in Factorio's `script-output` directory.
You can display the contents of the file for debugging purposes:

```sh
cat ~/.factorio/script-output/statorio/game.prom
```

Once the file is there, you can set up Prometheus and Grafana:

1. Copy `.env.base` to `.env` and fill in the blanks
    - `FACTORIO_APPDIR` is the path to the Factorio Application directory
2. Run `docker-compose up`
    - You might need to update `user: "1000:1000"` in the `docker-compose.yml` if your user id is not `1000`
3. Open Grafana on http://localhost:3000


## Attribution

- `graftorio2` is released under MIT
    - Commit [1b8ca38](https://github.com/remijouannet/graftorio2/tree/1b8ca38db745c9a8c720022213fd2d067c5600b8)
- A part of `graftorio2` under `/prometheus` is released under BSD-2
    - Commit [1b8ca38, `/prometheus`](https://github.com/remijouannet/graftorio2/tree/1b8ca38db745c9a8c720022213fd2d067c5600b8/prometheus)

Specific directories and files:

- `config/` was copied verbatim from `graftorio2`
- `mod/control.lua` was written from scratch but inspired by `graftorio2` code
- `mod/lib/prometheus` contains the prometheus API based on the BSD-2 version from `graftorio2` but with significant modifications
- `docker-compose.yml` was copied from `graftorio2` with minor modifications
