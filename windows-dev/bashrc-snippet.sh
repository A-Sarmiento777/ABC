# >>> windows-dev >>>
# Added by windows-dev/setup.ps1. Git Bash profile for the Herd setup.

export PATH="$HOME/bin:$PATH"

HERD_BIN="$HOME/.config/herd/bin"
# php and composer come from ~/bin (they call Herd's php.exe / composer.bat).
command -v herd >/dev/null 2>&1 || herd() { cmd.exe //c "$(cygpath -w "$HERD_BIN/herd.bat")" "$@"; }

# Valet muscle memory
alias valet=herd
alias ll='ls -la'
alias phplog='tail -f "$HOME/.config/herd/Log/php-errors.log"'
# <<< windows-dev <<<
