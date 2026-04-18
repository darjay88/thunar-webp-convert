# thunar-webp-convert

Small Bash utility for converting image files to WebP and exposing the converter as a right-click action in Thunar.

The project includes:

- `convert-to-webp.sh`: converts one or more input images to WebP.
- `install.sh`: installs the converter into a common bin path and registers a Thunar custom action.

## What It Does

- Resizes images to a configurable maximum width while preserving aspect ratio.
- Encodes the resized image as WebP with configurable quality.
- Writes the `.webp` file beside the original file.
- Supports converting multiple selected files at once.
- Sends desktop notifications when dependencies are missing or after conversion completes.

## Requirements

- Linux desktop with Thunar
- `cwebp` from `libwebp`
- `convert` from ImageMagick
- `notify-send` for desktop notifications (optional but recommended)

Example package names on Arch Linux:

```bash
sudo pacman -S libwebp imagemagick libnotify
```

Example package names on Debian or Ubuntu:

```bash
sudo apt install webp imagemagick libnotify-bin
```

## Installation

Clone the repository and run the installer:

```bash
chmod +x install.sh
./install.sh
```

Default behavior:

- Installs the command as `convert-to-webp`
- Uses `~/.local/bin` for a user-local install
- Creates `~/.config/webp-convert/config.toml` if it does not already exist
- Registers a Thunar custom action in `~/.config/Thunar/uca.xml`

System-wide install:

```bash
sudo ./install.sh --system
```

Custom install directory:

```bash
./install.sh --bin-dir "$HOME/bin"
```

If Thunar is already open, restart it after installation so the new context menu action is reloaded.

## Usage

From Thunar:

1. Select one or more image files.
2. Right-click the selection.
3. Choose `Convert to WebP`.

From a terminal:

```bash
convert-to-webp path/to/image.png
convert-to-webp path/to/image1.jpg path/to/image2.png
```

The output file is written beside each source image using the same base filename and the `.webp` extension.

## Configuration

Settings are read from:

```bash
~/.config/webp-convert/config.toml
```

Supported keys:

- `target_width`
- `quality`
- `output_suffix`

Example:

```toml
target_width = 800
quality = 85
output_suffix = ""
```

Notes:

- `target_width` must be a positive integer.
- `quality` must be an integer from 1 to 100.
- `output_suffix` must be a quoted string, for example `"-new"`.
- Use an empty suffix (`""`) to output `photo.webp`.

Current defaults:

- Width: `800`
- Quality: `85`
- Output suffix: empty

## Troubleshooting

If the menu item does not appear:

- Restart Thunar.
- Confirm the action was written to `~/.config/Thunar/uca.xml`.
- Make sure the script was installed into a directory that still exists.

If the command fails immediately:

- Verify `cwebp` is installed.
- Verify ImageMagick's `convert` command is installed.
- Run `convert-to-webp /path/to/file` from a terminal to see direct output.

## Development

This repository includes a GitHub Actions workflow that runs ShellCheck against the Bash scripts on pushes and pull requests.

Local syntax check:

```bash
bash -n convert-to-webp.sh install.sh
```

If ShellCheck is installed locally:

```bash
shellcheck convert-to-webp.sh install.sh
```