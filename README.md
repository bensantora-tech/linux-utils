# linux-utils

A collection of Bash utility scripts for Linux desktops — file management, media tools, and system monitoring. Includes both CLI and YAD GUI versions where applicable.

---

## Scripts

| Script | Description | GUI | Dependencies |
|---|---|---|---|
| `sort_ext_cli.sh` | Sort files into subfolders by extension (CLI) | No | none |
| `sort_ext_yad.sh` | Sort files into subfolders by extension (GUI) | Yes | `yad` |
| `png_mp3_to_mp4_yad.sh` | Combine a PNG image + MP3 audio into an MP4 video | Yes | `ffmpeg`, `yad` |
| `screen-recorder_yad.sh` | Record your screen to an MP4 file (X11 only) | Yes | `ffmpeg`, `yad`, `xdpyinfo` |
| `system_dashboard_yad.sh` | System health monitor with quick-action tools | Yes | `yad` |
| `video_trimmer_yad.sh` | Trim a video clip by start/end time | Yes | `ffmpeg`, `ffprobe`, `yad`, `bc` |

---

## Dependencies

### Install YAD and FFmpeg (Debian/Ubuntu)
```bash
sudo apt install yad ffmpeg bc x11-utils
```

### Install YAD and FFmpeg (Fedora/RHEL)
```bash
sudo dnf install yad ffmpeg bc xorg-x11-utils
```

> **Note:** `screen-recorder_yad.sh` requires an **X11 session** (not Wayland).

---

## Usage

Make a script executable, then run it:

```bash
chmod +x script.sh
./script.sh
```

Or install to your local bin so you can run it from anywhere:

```bash
chmod +x script.sh
cp script.sh ~/.local/bin/script   # drop the .sh extension if you prefer
```

---

## Script Details

### `sort_ext_cli.sh`
Recursively scans a directory and **copies** files into `sorted_files/<extension>/` subfolders. Hidden files and already-sorted files are skipped. Existing files in the destination are never overwritten.

```bash
./sort_ext_cli.sh /path/to/folder
# Omit the path to sort the current directory
./sort_ext_cli.sh
```

---

### `sort_ext_yad.sh`
Same behaviour as the CLI version, but shows a YAD summary dialog on completion instead of terminal output.

```bash
./sort_ext_yad.sh /path/to/folder
```

---

### `png_mp3_to_mp4_yad.sh`
GUI workflow to combine a static PNG image and an MP3 audio file into an MP4 video. Video length matches the audio duration. Output is encoded with H.264 + AAC.

```bash
./png_mp3_to_mp4_yad.sh
```

Steps:
1. Select a PNG image
2. Select an MP3 audio file
3. Choose the output path
4. Confirm and render

---

### `screen-recorder_yad.sh`
Records the full screen using FFmpeg's `x11grab`. Output files are saved to `~/Videos/ScreenRecordings/`. A persistent control window lets you START, STOP, or QUIT. If you quit while recording, it prompts you to save first.

```bash
./screen-recorder_yad.sh
```

> Requires an X11 session. Will not work under Wayland.

---

### `system_dashboard_yad.sh`
Displays live CPU, memory, disk, uptime, and load average. Includes a quick-action menu with:

- **Clear Cache** — runs `apt clean` / `dnf clean all`
- **Check Updates** — reports available package updates
- **Restart Service** — pick from a safe list or enter a custom service name
- **View Logs** — tail common log files or browse to a custom one
- **Disk Check** — shows `df -h` output in a dialog
- **Refresh** — reloads stats

Supports `apt`, `dnf`, and `yum` based systems.

```bash
./system_dashboard_yad.sh
```

---

### `video_trimmer_yad.sh`
Trim any video file to a specified start and end time. Accepts time as `HH:MM:SS` or plain seconds. Output is re-encoded with H.264 + AAC and optimized for streaming (`faststart`).

```bash
./video_trimmer_yad.sh
```

Steps:
1. Select an input video (MP4, MKV, AVI, MOV)
2. Set start time, end time, and output path
3. Confirm and trim

---

## Notes

- Scripts that copy or write files never overwrite existing files without confirmation.
- Original files are never modified or deleted by any script.
- `system_dashboard_yad.sh` requires `sudo` for cache clearing and service restarts — you will be prompted by your system.

---

## License

MIT
