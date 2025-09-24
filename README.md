# Mindfu - Meditation Audio Player

A minimal TUI meditation audio player built with Ruby.

## Features

- TUI interface with current file name and progress bar
- Audio playback using ffplay
- State machine for play/pause/next/prev controls
- JSON state persistence
- Minitest suite
- YARD documentation

## Requirements

- Ruby 3.0+
- ffplay (from FFmpeg)
- Audio files in `audio_files/` directory

## Installation

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Add meditation audio files to `audio_files/` directory (supports mp3, mp4, wav, ogg)

3. Run the application:
   ```bash
   ruby mindfu.rb
   ```

## Controls

- `SPACE` - Play/Pause
- `S` - Stop
- `N` - Next track
- `P` - Previous track
- `Q` - Quit

## Running Tests

```bash
# Run all tests (simplest)
ruby test_all.rb

# Alternative ways to run all tests
find tests -name "*_test.rb" -exec ruby -Ilib {} \;
ruby -Ilib tests/*_test.rb

# Run specific test file
ruby -Ilib tests/audio_player_test.rb
ruby -Ilib tests/player_state_test.rb
ruby -Ilib tests/state_persistence_test.rb
```

## Documentation

Generate YARD documentation:

```bash
bundle exec yard
```

## Project Structure

```
├── lib/
│   ├── meditation_player.rb  # Main app controller
│   ├── audio_player.rb       # Audio playback with ffplay
│   ├── player_state.rb       # State machine
│   ├── tui.rb                # Terminal UI
│   └── state_persistence.rb  # JSON state save/load
├── tests/                    # Minitest suite
├── audio_files/              # Place audio files here
└── mindfu.rb                 # Entry point
```