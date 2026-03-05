# blackmatter-karakuri

Home-Manager module for [karakuri](https://github.com/pleme-io/karakuri), a programmable macOS automation framework. This module manages karakuri installation, launchd service lifecycle, YAML configuration generation, Rhai scripting, MCP server integration, and optional Stylix theme sourcing -- all declaratively through Nix.

## Architecture

```
flake.nix
  ├── inputs: nixpkgs, substrate (hm-service-helpers), karakuri (overlay + binary)
  └── outputs:
        └── homeManagerModules.default
              └── module/default.nix
                    ├── options: blackmatter.components.karakuri.*
                    ├── config generation: Nix attrs -> karakuri.yaml (via lib.generators.toYAML)
                    ├── launchd agent: io.pleme.karakuri (keepAlive, Interactive)
                    ├── Rhai scripts: init.rhai + extra scripts under ~/.config/karakuri/scripts/
                    ├── MCP server entry: karakuri mcp (stdio transport)
                    └── Stylix integration: auto-sources border/dim colors when Stylix is active
```

The module uses substrate's `hm-service-helpers.nix` factory pattern:
- `mkLaunchdService` creates the macOS launchd agent configuration
- `mkMcpOptions` / `mkMcpServerEntry` wire up the MCP server for Claude Code integration
- The karakuri overlay is applied in an isolated `import pkgs.path` call to provide `pkgs.karakuri`

## Features

- Declarative karakuri configuration via Nix attribute sets, serialized to YAML
- Automatic launchd agent management (keepAlive, log rotation)
- Rhai scripting support with init script and additional script file management
- MCP server integration for Claude Code (stdio transport via `karakuri mcp`)
- Window theme options (border color, dim inactive color) with Nord defaults
- Wallpaper path configuration applied on karakuri startup
- macOS system defaults (`com.apple.dock`, etc.) applied via karakuri's hot-reload
- Stylix auto-integration: border and dim colors sourced from Stylix palette when available
- Hot-reload of configuration and scripts on file changes

## Installation

Add as a flake input:

```nix
{
  inputs = {
    blackmatter-karakuri = {
      url = "github:pleme-io/blackmatter-karakuri";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
      inputs.karakuri.follows = "karakuri";
    };
  };
}
```

Import the home-manager module:

```nix
{
  home-manager.users.<user>.imports = [
    inputs.blackmatter-karakuri.homeManagerModules.default
  ];
}
```

## Usage

### Minimal

```nix
{
  blackmatter.components.karakuri.enable = true;
}
```

This installs karakuri, starts the launchd agent, and creates the log directory.

### Full Configuration

```nix
{
  blackmatter.components.karakuri = {
    enable = true;

    # Window management settings (serialized to ~/.config/karakuri/karakuri.yaml)
    settings = {
      options = {
        focus_follows_mouse = true;
        preset_column_widths = [ 0.25 0.33 0.5 0.66 0.75 ];
        swipe_gesture_fingers = 4;
        animation_speed = 4000;
        dim_inactive_windows = 0.15;
        border_active_window = true;
        border_opacity = 0.9;
        border_width = 2.0;
        border_radius = 10.0;
      };
      bindings = {
        window_focus_west = "cmd - h";
        window_focus_east = "cmd - l";
        window_focus_north = "cmd - k";
        window_focus_south = "cmd - j";
        window_swap_west = "ctrl+alt - h";
        window_swap_east = "ctrl+alt - l";
        window_center = "ctrl+alt - c";
        window_fullwidth = "ctrl+alt - f";
        quit = "ctrl+alt - q";
      };
      windows = {
        pip = { title = "picture.*picture"; floating = true; };
      };
    };

    # Desktop wallpaper
    wallpaper.path = "~/Pictures/wallpaper.png";

    # Theme colors (auto-sourced from Stylix when available)
    theme = {
      borderColor = "#88C0D0";
      dimColor = "#2E3440";
    };

    # macOS system defaults applied by karakuri at startup
    systemDefaults = {
      "com.apple.dock" = {
        autohide = true;
        autohide-delay = 0.0;
      };
    };

    # Rhai scripting
    scripting = {
      hotReload = true;
      initScript = ''
        log("karakuri init.rhai loaded");
        on_hotkey("cmd-h", || focus_west());
      '';
      extraScripts = {
        "window-rules" = ''
          log("window rules loaded");
        '';
      };
    };

    # MCP server for Claude Code
    mcp.enable = true;
  };
}
```

## Configuration Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable karakuri window manager |
| `package` | package | `pkgs.karakuri` | The karakuri package to use |
| `settings` | null or attrs | `null` | Full karakuri YAML config as Nix attrs |
| `wallpaper.path` | null or string | `null` | Desktop wallpaper image path |
| `theme.borderColor` | string | `"#88C0D0"` | Active window border color (hex) |
| `theme.dimColor` | string | `"#2E3440"` | Inactive window dim overlay color (hex) |
| `systemDefaults` | attrs | `{}` | macOS defaults domains and keys |
| `scripting.initScript` | lines | `""` | Contents of `~/.config/karakuri/init.rhai` |
| `scripting.extraScripts` | attrs of lines | `{}` | Additional Rhai scripts in `scripts/` |
| `scripting.hotReload` | bool | `true` | Enable hot-reload of Rhai scripts |
| `mcp.enable` | bool | `false` | Expose karakuri as an MCP server |

## Project Structure

```
blackmatter-karakuri/
├── flake.nix              # Flake: inputs (nixpkgs, substrate, karakuri), single HM module output
└── module/
    └── default.nix        # Home-Manager module: options, launchd agent, config generation, MCP
```

## How It Works

1. **Configuration**: Nix attrs are merged (wallpaper defaults + theme defaults + system defaults + user settings) and serialized to `~/.config/karakuri/karakuri.yaml` via `lib.generators.toYAML`
2. **Service**: A launchd agent (`io.pleme.karakuri`) runs `karakuri launch` with keepAlive and Interactive process type
3. **Scripting**: Rhai init script and extra scripts are written to `~/.config/karakuri/` and hot-reloaded on change
4. **MCP**: When enabled, a server entry is generated for Claude Code integration via stdio transport (`karakuri mcp`)
5. **Stylix**: When Stylix is active, border and dim colors are automatically sourced from the Stylix palette (overridable via `mkDefault`)

## Related Projects

- [karakuri](https://github.com/pleme-io/karakuri) -- The karakuri window manager itself
- [substrate](https://github.com/pleme-io/substrate) -- Shared Nix build patterns (hm-service-helpers)
- [blackmatter](https://github.com/pleme-io/blackmatter) -- Module aggregator that imports this repo
- [blackmatter-claude](https://github.com/pleme-io/blackmatter-claude) -- Claude Code MCP configuration

## License

MIT
