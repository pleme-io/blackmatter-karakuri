# Module factory — receives { hmHelpers, karakuriOverlay } from flake.nix
{
  hmHelpers,
  karakuriOverlay,
}:
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  inherit (hmHelpers) mkLaunchdService;
  cfg = config.blackmatter.components.karakuri;
  isDarwin = pkgs.stdenv.isDarwin;

  # Apply karakuri overlay so pkgs.karakuri is available
  karakuriPkgs = import pkgs.path {
    inherit (pkgs) system;
    overlays = [ karakuriOverlay ];
  };

  # Merge theme + wallpaper defaults with user settings (user's explicit options win)
  themeDefaults = {
    options = {
      border_color = cfg.theme.borderColor;
      dim_inactive_color = cfg.theme.dimColor;
    };
  };
  wallpaperDefaults = lib.optionalAttrs (cfg.wallpaper.path != null) {
    options.wallpaper = cfg.wallpaper.path;
  };
  mergedSettings = lib.recursiveUpdate
    (lib.recursiveUpdate wallpaperDefaults themeDefaults)
    (if cfg.settings != null then cfg.settings else {});

  # Generate YAML config from nix attrs
  yamlConfig = pkgs.writeText "karakuri.yaml" (lib.generators.toYAML { } mergedSettings);

  logDir =
    if isDarwin then
      "${config.home.homeDirectory}/Library/Logs"
    else
      "${config.home.homeDirectory}/.local/share/karakuri/logs";
in
{
  options.blackmatter.components.karakuri = {
    enable = mkEnableOption "Karakuri — programmable macOS automation framework";

    package = mkOption {
      type = types.package;
      default = karakuriPkgs.karakuri;
      description = "The karakuri package to use.";
    };

    settings = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = ''
        Configuration written to `~/.config/karakuri/karakuri.yaml`.
        Accepts any attrs that serialize to valid karakuri YAML config.
        Figment loads: defaults -> env vars (KARAKURI_*) -> this file.
      '';
      example = {
        options = {
          focus_follows_mouse = true;
          preset_column_widths = [
            0.25
            0.33
            0.5
            0.66
            0.75
          ];
          swipe_gesture_fingers = 4;
          animation_speed = 4000;
          dim_inactive_windows = 0.15;
          border_active_window = true;
          border_color = "#89b4fa";
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
          window_resize = "ctrl+alt - r";
          window_fullwidth = "ctrl+alt - f";
          quit = "ctrl+alt - q";
        };
        windows = {
          pip = {
            title = "picture.*picture";
            floating = true;
          };
        };
        scripting = {
          init_script = "~/.config/karakuri/init.rhai";
          script_dirs = [ "~/.config/karakuri/scripts" ];
          hot_reload = true;
        };
      };
    };

    wallpaper = {
      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Desktop wallpaper image path (applied on karakuri startup).";
        example = "~/Pictures/wallpaper.png";
      };
    };

    theme = {
      borderColor = mkOption {
        type = types.str;
        default = "#88C0D0";
        description = "Active window border color (hex).";
      };
      dimColor = mkOption {
        type = types.str;
        default = "#2E3440";
        description = "Inactive window dim overlay color (hex).";
      };
    };

    scripting = {
      initScript = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Contents of `~/.config/karakuri/init.rhai`.
          Main Rhai script loaded on startup.
        '';
        example = ''
          log("karakuri init.rhai loaded");
          on_hotkey("cmd-h", || focus_west());
        '';
      };

      extraScripts = mkOption {
        type = types.attrsOf types.lines;
        default = { };
        description = ''
          Additional Rhai scripts written to `~/.config/karakuri/scripts/<name>.rhai`.
        '';
        example = {
          "window-rules" = ''
            log("window rules loaded");
          '';
        };
      };

      hotReload = mkOption {
        type = types.bool;
        default = true;
        description = "Enable hot-reload of Rhai scripts on file changes.";
      };
    };
  };

  config = mkIf (cfg.enable && isDarwin) (mkMerge [
    # Install the package
    {
      home.packages = [ cfg.package ];
    }

    # Create log directory
    {
      home.activation.karakuri-log-dir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${logDir}"
      '';
    }

    # Launchd agent
    (mkLaunchdService {
      name = "karakuri";
      label = "io.pleme.karakuri";
      command = "${cfg.package}/bin/karakuri";
      args = [ "launch" ];
      logDir = logDir;
      processType = "Interactive";
      keepAlive = true;
    })

    # YAML configuration (figment-based, hot-reloaded on change)
    (mkIf (cfg.settings != null) {
      xdg.configFile."karakuri/karakuri.yaml".source = yamlConfig;
    })

    # Rhai init script
    (mkIf (cfg.scripting.initScript != "") {
      xdg.configFile."karakuri/init.rhai".text = cfg.scripting.initScript;
    })

    # Extra Rhai scripts
    (mkIf (cfg.scripting.extraScripts != { }) {
      xdg.configFile = mapAttrs' (
        name: content: nameValuePair "karakuri/scripts/${name}.rhai" { text = content; }
      ) cfg.scripting.extraScripts;
    })

    # Auto-source theme colors from Stylix when available
    (mkIf (config.lib ? stylix && config.stylix.enable) {
      blackmatter.components.karakuri.theme = {
        borderColor = mkDefault "#${config.lib.stylix.colors.base0C}";
        dimColor = mkDefault "#${config.lib.stylix.colors.base00}";
      };
    })
  ]);
}
