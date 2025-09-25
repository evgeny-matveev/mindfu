# Mindfu - Meditation Audio Player

A minimal TUI meditation audio player built with Ruby.

## Features

- TUI interface with current file name
- Audio playback using mpv
- State machine for play/pause/next/prev controls
- JSON state persistence
- Minitest suite
- YARD documentation
- Performance tests for CPU optimization

## Requirements

- Ruby 3.0+
- mpv (Media Player)
- Audio files in `audio_files/` directory

## Installation

1. Install mpv:

   **macOS:**
   ```bash
   brew install mpv
   ```

   **Ubuntu/Debian:**
   ```bash
   sudo apt-get install mpv
   ```

   **Fedora:**
   ```bash
   sudo dnf install mpv
   ```

2. Install Ruby dependencies:
   ```bash
   bundle install
   ```

3. Add meditation audio files to `audio_files/` directory (supports mp3, mp4, wav, ogg)

4. Run the application:
   ```bash
   bin/mindfu
   ```

## Controls

### English Keyboard Layout
- `SPACE` - Play/Pause
- `S` - Stop
- `N` - Next track
- `P` - Previous track
- `Q` - Quit

### Russian Keyboard Layout
- `SPACE` - Play/Pause
- `Ы` - Stop
- `Т` - Next track
- `З` - Previous track
- `Й` - Quit

## Running Tests

```bash
# Run all tests (simplest)
ruby tests/test_all.rb

# Alternative ways to run all tests
find tests -name "*_test.rb" -exec ruby -Ilib {} \;
ruby -Ilib tests/*_test.rb

# Run specific test file
ruby -Ilib tests/mpv_player_test.rb
ruby -Ilib tests/player_state_test.rb
ruby -Ilib tests/random_file_selector_test.rb

# Run performance tests
find tests/performance_tests -name "*.rb" -exec ruby -Ilib {} \;
ruby -Ilib tests/performance_tests/performance_test.rb
ruby -Ilib tests/performance_tests/tui_cpu_test.rb
ruby -Ilib tests/performance_tests/test_idle_specific.rb
ruby -Ilib tests/performance_tests/verify_fix.rb

# Run linting on performance tests
bundle exec rubocop tests/performance_tests/
```

## Documentation

Generate YARD documentation:

```bash
bundle exec yard
```

## Project Structure

```
├── bin/
│   └── mindfu                # Main entry point
├── lib/
│   ├── meditation_player.rb  # Main app controller
│   ├── mpv_player.rb        # Audio playback with mpv
│   ├── player_state.rb       # State machine
│   ├── tui.rb                # Terminal UI
│   └── random_file_selector.rb  # Random file selection with history
├── tests/                    # Minitest suite
│   ├── *_test.rb            # Unit tests
│   └── performance_tests/    # Performance and CPU tests
├── tmp/                      # Temporary files (recently_played.json)
└── audio_files/              # Place audio files here
```