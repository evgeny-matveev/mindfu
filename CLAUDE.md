# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Principles

- **TDD Approach**: Always write tests first, then implement functionality. Ensure all tests pass before considering a feature complete.
- **Documentation**: Update YARD documentation and README.md after making changes to any module or method.
- **KISS/YAGNI**: Follow Keep It Simple, Stupid and You Ain't Gonna Need It principles. Avoid over-engineering.
- **Minimal Code**: Strive for ultra-minimal solutions. The less code, the better. Remove any unnecessary complexity.
- **Resource Management**: In tests, ensure all started processes or playing audio files are properly stopped/cleaned up to prevent resource leaks.

## Commands

### Running the Application
```bash
# Install dependencies
bundle install

# Run the main application
bin/mindfu

# Run with specific audio files in audio_files/ directory
```

### Testing
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

# Run tests with test helper
ruby -Ilib tests/test_helper.rb
```

### Code Quality
```bash
# Run Rubocop linting
bundle exec rubocop

# Run Rubocop with auto-correction
bundle exec rubocop -A
```

### Documentation
```bash
# Generate YARD documentation
bundle exec yard
```

## Architecture

The meditation player follows a modular architecture with clear separation of concerns:

### Core Components

1. **MPVPlayer** (`lib/mpv_player.rb`): Handles mpv process management
   - Uses JSON IPC for accurate progress tracking and control
   - Manages process groups for proper cleanup
   - Redirects output to `/dev/null` for background operation
   - Supports proper pause/resume through mpv commands

2. **PlayerState** (`lib/player_state.rb`): State machine using `state_machines` gem
   - Manages transitions between :stopped, :playing, :paused states
   - Handles file navigation (next/previous track)
   - Triggers appropriate MPVPlayer methods during state transitions

3. **TUI** (`lib/tui.rb`): Terminal user interface using curses
   - Minimal interface showing current file and playback state
   - Handles keyboard input for controls
   - No progress bar (removed for simplicity)

4. **RandomFileSelector** (`lib/random_file_selector.rb`): Random file selection with session history
   - Implements 90% rule for excluding recently played files
   - Maintains persistent recently played history in `tmp/recently_played.json`
   - Handles session-based navigation (next/previous)

### Key Design Patterns

- **State Machine**: Central to controlling playback behavior
- **Dependency Injection**: Components are loosely coupled through constructor injection
- **Process Management**: Proper Unix signal handling for audio playback
- **Error Handling**: Graceful degradation when mpv processes fail
- **IPC Communication**: JSON-based Inter-Process Communication for accurate progress tracking

### Audio File Handling

- Audio files must be placed in `audio_files/` directory
- Supports formats: mp3, mp4, wav, ogg
- Files are automatically discovered and sorted alphabetically

### Keyboard Controls

#### English Layout
- `SPACE`: Play/Pause toggle
- `S`: Stop playback
- `N`: Next track
- `P`: Previous track
- `Q`: Quit application

#### Russian Layout
- `SPACE`: Play/Pause toggle
- `Ы`: Stop playback
- `Т`: Next track
- `З`: Previous track
- `Й`: Quit application

### State Machine Events

The player responds to these events:
- `play`: Start playback from stopped state or resume from paused
- `pause`: Pause currently playing audio
- `resume`: Resume from paused state
- `stop`: Stop playback and return to stopped state
- `next`/`previous`: Navigate between tracks

### Process Management

mpv runs in background process groups with:
- `--no-video`: No video display
- `--autoexit`: Process terminates when playback completes
- `--loglevel=quiet`: Suppress console output
- `--input-ipc-server=SOCKET`: JSON IPC communication socket
- Output redirected to `/dev/null`
- Proper cleanup on application exit

### Testing Strategy

Tests focus on:
- State machine transitions and event handling
- Process management (mocked for test safety)
- State persistence and restoration
- Component integration

All tests use Minitest and follow a functional approach with minimal mocking.