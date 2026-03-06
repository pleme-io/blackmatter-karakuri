# blackmatter-karakuri

Home-manager module for the Karakuri macOS window manager and automation framework.

## Overview

Integrates the Karakuri window manager into home-manager with declarative YAML configuration, Rhai scripting support, launchd service management, and an MCP server for AI-driven window control. Darwin-only -- no-ops on Linux. Uses substrate's `hm-service-helpers` for launchd and MCP patterns.

## Flake Outputs

- `homeManagerModules.default` -- home-manager module at `blackmatter.components.karakuri`

## Usage

```nix
{
  inputs.blackmatter-karakuri.url = "github:pleme-io/blackmatter-karakuri";
}
```

```nix
blackmatter.components.karakuri = {
  enable = true;
  theme.borderColor = "#88C0D0";
  wallpaper.path = "~/Pictures/wallpaper.png";
  mcp.enable = true;
  settings = {
    bindings.window_focus_west = "cmd - h";
    bindings.window_focus_east = "cmd - l";
  };
  scripting.initScript = ''
    log("karakuri loaded");
  '';
};
```

## Features

- Declarative YAML config via Nix attrs (figment-based, hot-reloaded)
- Rhai scripting with init script + extra script directories
- Launchd agent with log rotation
- MCP server entry for AI integration
- Stylix theme auto-sourcing when available

## Structure

- `module/` -- home-manager module factory
