# terminal-notify

A macOS command-line tool for sending native notifications, similar to [terminal-notifier](https://github.com/julienXX/terminal-notifier). Built with Swift and targets macOS 15+ (Sequoia).

## Features

- Send native macOS notifications from the command line
- Custom title, subtitle, message, and sound
- Click actions: open URLs, execute commands, activate apps
- Notification grouping and replacement
- macOS 15+ interruption levels (passive, active, time-sensitive, critical)
- Relevance score for Apple Intelligence notification summaries

## Installation

### Build from source

```bash
# Clone the repository
git clone https://github.com/yourusername/terminal-notify.git
cd terminal-notify

# Build and install (to ~/bin and ~/Applications)
make user-install

# Or install system-wide (requires sudo)
make install
```

### Add to PATH

Add this to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/bin:$PATH"
```

### Start the Helper App

The helper app must be running to send notifications:

```bash
open ~/Applications/terminal-notify-helper.app
```

**Tip:** Add the helper app to Login Items (System Settings → General → Login Items) to start automatically at login.

## Usage

### Basic Notification

```bash
# Simple message
terminal-notify --message "Hello, World!"

# With title
terminal-notify --title "Greeting" --message "Hello, World!"

# With title and subtitle
terminal-notify --title "Greeting" --subtitle "From terminal-notify" --message "Hello, World!"
```

### Sound

```bash
# Default system sound
terminal-notify --message "Alert!" --sound default

# Named sound (from /System/Library/Sounds/)
terminal-notify --message "Alert!" --sound Glass
terminal-notify --message "Alert!" --sound Basso
terminal-notify --message "Alert!" --sound Funk
terminal-notify --message "Alert!" --sound Hero
terminal-notify --message "Alert!" --sound Ping
terminal-notify --message "Alert!" --sound Pop
terminal-notify --message "Alert!" --sound Purr
terminal-notify --message "Alert!" --sound Submarine
```

### Click Actions

```bash
# Open a URL when clicked
terminal-notify --message "Click to open Google" --open "https://google.com"

# Open a file
terminal-notify --message "Click to open document" --open "file:///Users/you/Documents/file.pdf"

# Execute a shell command when clicked
terminal-notify --message "Click to run script" --execute "echo 'Clicked!' >> /tmp/notify.log"

# Activate an app by bundle ID
terminal-notify --message "Click to open Safari" --activate "com.apple.Safari"

# Wait for user interaction (blocks until clicked/dismissed)
terminal-notify --message "Click me!" --open "https://google.com" --wait
```

### Notification Grouping

```bash
# Group notifications (same group ID replaces previous notification)
terminal-notify --message "Download: 25%" --group "download-progress"
terminal-notify --message "Download: 50%" --group "download-progress"
terminal-notify --message "Download: 100%" --group "download-progress"

# Remove a notification by group ID
terminal-notify remove "download-progress"

# Remove all notifications
terminal-notify remove ALL

# List delivered notifications
terminal-notify list
terminal-notify list "download-progress"
```

### Image Attachments

```bash
# Attach an image to the notification
terminal-notify --message "Check out this image" --contentImage "/path/to/image.png"
```

### Interruption Levels (macOS 15+)

Control how notifications interact with Focus modes:

```bash
# Passive - no sound, doesn't wake screen (lowest priority)
terminal-notify --message "FYI" --interruptionLevel passive

# Active - default behavior (sound + banner)
terminal-notify --message "Update available" --interruptionLevel active

# Time-sensitive - breaks through Focus modes
terminal-notify --message "Meeting starting now!" --interruptionLevel timeSensitive --sound default

# Critical - always shows (requires special entitlement)
terminal-notify --message "EMERGENCY!" --interruptionLevel critical
```

### Relevance Score (macOS 15+)

Set priority for Apple Intelligence notification summaries:

```bash
# Low relevance (may be summarized/hidden)
terminal-notify --message "Weekly report ready" --relevanceScore 0.2

# High relevance (more likely to be shown prominently)
terminal-notify --message "Payment received!" --relevanceScore 0.9
```

### Reading from stdin

```bash
# Pipe message from another command
echo "Build completed successfully" | terminal-notify --title "Build Status"

# Use with other tools
curl -s "https://api.example.com/status" | terminal-notify --title "API Status"
```

### Combining Options

```bash
# Full-featured notification
terminal-notify \
  --title "Deployment Complete" \
  --subtitle "Production Server" \
  --message "Version 2.0.0 deployed successfully" \
  --sound default \
  --open "https://myapp.com" \
  --group "deployment" \
  --interruptionLevel timeSensitive \
  --relevanceScore 0.8
```

## Real-World Examples

### Long-running task completion

```bash
# Notify when a build finishes
make build && terminal-notify --title "Build" --message "Success!" --sound default || terminal-notify --title "Build" --message "Failed!" --sound Basso

# Notify when download completes
curl -O https://example.com/large-file.zip && terminal-notify --message "Download complete"
```

### Scheduled reminders

```bash
# Remind to take a break (using sleep)
(sleep 1800 && terminal-notify --title "Break Time" --message "You've been working for 30 minutes" --sound default) &

# With cron (add to crontab -e)
# 0 * * * * ~/bin/terminal-notify --message "Hourly check-in"
```

### Git hooks

```bash
# In .git/hooks/post-commit
#!/bin/bash
terminal-notify --title "Git" --message "Commit successful: $(git log -1 --pretty=%s)"
```

### CI/CD notifications

```bash
# Notify on deployment
terminal-notify \
  --title "Deploy: $APP_NAME" \
  --message "Version $VERSION deployed to $ENVIRONMENT" \
  --open "$DEPLOY_URL" \
  --interruptionLevel timeSensitive
```

### System monitoring

```bash
# Alert on high CPU usage
CPU=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%')
if (( $(echo "$CPU > 80" | bc -l) )); then
  terminal-notify --title "High CPU" --message "CPU usage: $CPU%" --interruptionLevel timeSensitive
fi
```

## Command Reference

### Send (default subcommand)

```
terminal-notify send [options]

Options:
  --message <text>           Notification body (required)
  --title <text>             Notification title
  --subtitle <text>          Notification subtitle
  --sound <name>             Sound name ("default" or system sound)
  --open <url>               URL to open when clicked
  --execute <command>        Shell command to run when clicked
  --activate <bundle-id>     App to activate when clicked
  --appIcon <path>           Custom app icon path
  --contentImage <path>      Image attachment path
  --group <id>               Group ID (replaces previous with same ID)
  --sender <bundle-id>       Fake sender bundle ID
  --interruptionLevel <lvl>  Priority: passive, active, timeSensitive, critical
  --relevanceScore <0-1>     Priority in notification summaries
  --wait                     Wait for user interaction
```

### Remove

```
terminal-notify remove <group-id>
terminal-notify remove ALL
```

### List

```
terminal-notify list [group-id]
terminal-notify list ALL
```

## Architecture

terminal-notify uses a two-component architecture:

1. **CLI** (`~/bin/terminal-notify`) - Parses arguments and sends requests
2. **Helper App** (`~/Applications/terminal-notify-helper.app`) - Background app that interfaces with macOS notification center

This is required because `UNUserNotificationCenter` only works within an app bundle.

## Requirements

- macOS 15.0+ (Sequoia)
- Xcode 16+ (for building)

## License

MIT License
