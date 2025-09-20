#!/bin/bash

set -e  # Exit on any error

echo "🎵 Setting up Apple Music CLI Player..."

# Get the absolute path of the repo directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to backup existing files
backup_file() {
    local file="$1"
    if [ -f "$file" ] || [ -L "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "Backing up existing $file to $backup"
        mv "$file" "$backup"
    fi
}

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This Apple Music CLI is designed for macOS only"
    exit 1
fi

# Check if Music.app exists (either location)
if [ ! -d "/Applications/Music.app" ] && [ ! -d "/System/Applications/Music.app" ]; then
    print_error "Music.app not found. This tool requires Apple Music app to be installed."
    exit 1
fi

print_status "Checking dependencies..."

# Check and install viu
if ! command -v viu &> /dev/null; then
    print_warning "viu not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install viu
        print_success "viu installed"
    else
        print_error "Homebrew not found. Please install Homebrew first or install viu manually."
        print_error "Visit: https://brew.sh/"
        exit 1
    fi
else
    print_success "viu already installed"
fi

# Check and install fzf
if ! command -v fzf &> /dev/null; then
    print_warning "fzf not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install fzf
        print_success "fzf installed"
    else
        print_error "Homebrew not found. Please install Homebrew first or install fzf manually."
        print_error "Visit: https://brew.sh/"
        exit 1
    fi
else
    print_success "fzf already installed"
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p ~/.local/bin
mkdir -p ~/Library/Scripts

# Install the Apple Music CLI script
print_status "Installing Apple Music CLI script..."
backup_file ~/.local/bin/am
cp "$REPO_DIR/src/am.sh" ~/.local/bin/am
chmod +x ~/.local/bin/am
print_success "Apple Music CLI script installed to ~/.local/bin/am"

# Install the AppleScript
print_status "Installing album art AppleScript..."
backup_file ~/Library/Scripts/album-art.applescript
cp "$REPO_DIR/src/album-art.applescript" ~/Library/Scripts/album-art.applescript
print_success "AppleScript installed to ~/Library/Scripts/album-art.applescript"

# Check if ~/.local/bin is in PATH
print_status "Checking PATH configuration..."
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    print_warning "~/.local/bin is not in your PATH"

    # Detect shell and update configuration
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
        SHELL_NAME="zsh"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
        SHELL_NAME="bash"
    else
        print_warning "Unknown shell. Please manually add ~/.local/bin to your PATH"
        SHELL_CONFIG=""
    fi

    if [ -n "$SHELL_CONFIG" ]; then
        print_status "Adding ~/.local/bin to PATH in $SHELL_CONFIG..."

        # Check if PATH export already exists
        if grep -q "export PATH.*HOME/.local/bin" "$SHELL_CONFIG" 2>/dev/null; then
            print_warning "PATH export already exists in $SHELL_CONFIG"
        else
            echo "" >> "$SHELL_CONFIG"
            echo "# Added by Apple Music CLI setup" >> "$SHELL_CONFIG"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
            print_success "Updated $SHELL_CONFIG"
        fi
    fi
else
    print_success "~/.local/bin is already in PATH"
fi

# Add convenient aliases
print_status "Setting up convenient aliases..."
if [ -n "$SHELL_CONFIG" ] && [ -f "$SHELL_CONFIG" ]; then
    if ! grep -q "alias amp=" "$SHELL_CONFIG" 2>/dev/null; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Apple Music CLI aliases" >> "$SHELL_CONFIG"
        echo 'alias amp="am play"' >> "$SHELL_CONFIG"
        echo 'alias aml="am list"' >> "$SHELL_CONFIG"
        echo 'alias amn="am np"' >> "$SHELL_CONFIG"
        echo 'alias amnt="am np -t"' >> "$SHELL_CONFIG"
        echo 'alias amq="am np -s square"' >> "$SHELL_CONFIG"
        echo 'alias music="am"' >> "$SHELL_CONFIG"
        print_success "Aliases added to $SHELL_CONFIG"
    else
        print_warning "Apple Music aliases already exist in $SHELL_CONFIG"
    fi
fi

# Test the installation
print_status "Testing installation..."
if [ -x ~/.local/bin/am ] && [ -f ~/Library/Scripts/album-art.applescript ]; then
    print_success "Installation test passed"
else
    print_error "Installation test failed"
    exit 1
fi

print_success "🎉 Apple Music CLI setup complete!"

echo
print_status "🎨 New Features:"
echo "  • Multiple album art sizes: small, large, xl, square"
echo "  • Smart text positioning (no more overlap!)"
echo "  • Perfect square mode for terminal widgets"
echo "  • Convenient aliases for quick access"
echo
print_status "Usage Examples:"
echo "  am np                    # Standard now playing"
echo "  am np -s square         # Square layout (35x18)"
echo "  am np -s large          # Large album art (45x20)"
echo "  am np -s xl             # Extra large (60x28)"
echo "  am play -a              # Browse artists with fzf"
echo "  am list -p              # List playlists"
echo
print_status "Quick Aliases:"
echo "  amn    # am np (now playing)"
echo "  amq    # am np -s square (square mode)"
echo "  amnt   # am np -t (text mode)"
echo "  amp    # am play"
echo "  aml    # am list"
echo "  music  # am"
echo
print_status "Terminal Integration:"
echo "  • Square mode perfect for tiling window managers"
echo "  • Works great with tmux, i3, yabai, etc."
echo "  • No text overflow in any size mode"
echo
if [ -n "$SHELL_CONFIG" ]; then
    print_status "Restart your terminal or run 'source $SHELL_CONFIG' to use the new commands!"
else
    print_status "Add ~/.local/bin to your PATH to use the commands globally"
fi

# Show what was installed
echo
print_status "Summary of installation:"
echo "  • ~/.local/bin/am <- $REPO_DIR/src/am.sh"
echo "  • ~/Library/Scripts/album-art.applescript <- $REPO_DIR/src/album-art.applescript"
if [ -n "$SHELL_CONFIG" ]; then
    echo "  • $SHELL_CONFIG updated with PATH and aliases"
fi
echo "  • Dependencies: viu, fzf (via Homebrew)"
echo
print_status "🌟 If you enjoy this version, please star the repo!"
echo "https://github.com/chetanyb/Apple-Music-CLI-Player"