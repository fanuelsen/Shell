# Check for Homebrew
# Install if we don't have it
# Scripts i stole from https://github.com/donnemartin/dev-setup/blob/master/brew.sh https://github.com/pathikrit/mac-setup-script/blob/master/defaults.sh https://gist.github.com/cassiocardoso/649cd015d7c2eff7bdfe02bdcd50dcdd https://gist.github.com/bradp/bea76b16d3325f5c47d4

if test ! $(which brew); then
  echo "Installing homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Update homebrew recipes
echo "Updating homebrew..."
brew update

# Clean up Brew
echo "Cleaning up brew"
brew cleanup

# Install homebrew recipes 
echo "Installing homebrew recipes"

recipes=(
cask
mas
wget
zsh
git
docker
asciinema
npm
)

brew install ${recipes[@]}

# Manually sign in to Appstore
open -a "/Applications/App Store.app"
echo "Sign in to App Store and press enter to continue"
read -n 1 

# App store apps for mas to install

appstore=(
407963104         # Pixelmator
557168941         # Tweetbot
784801555         # Microsoft OneNote
1295203466        # Microsoft Remote Desktop
462058435         # Microsoft Excel
462054704         # Microsoft Word
462062816         # Microsoft PowerPoint
)

mas install ${appstore[@]}

# DMGs to Download and Install
# Minecraft for Education
wget https://aka.ms/meeclientmacos
hdiutil mount meeclientmacos
cp -R "/Volumes/rw/minecraftpe.app" "/Applications/minecraftpe.app"
hdiutil unmount /Volumes/rw 
rm meeclientmacos

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Enabling subpixel font rendering on non-Apple LCDs
defaults write NSGlobalDomain AppleFontSmoothing -int 2

# Disabling OS X Gate Keeper
# (You'll be able to install any app you want from here on, not just Mac App Store apps)"
sudo spctl --master-disable
sudo defaults write /var/db/SystemPolicy-prefs.plist enabled -string no
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable AutoCorrect
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false  

# Set Desktop as the default location for new Finder windows
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

defaults write com.apple.finder AppleShowAllFiles -bool true                   # Finder: Show hidden files by default
defaults write NSGlobalDomain AppleShowAllExtensions -bool true                # Finder: Show all filename extensions
defaults write com.apple.finder ShowStatusBar -bool true                       # Finder: Show status bar
defaults write com.apple.finder ShowPathbar -bool true                         # Finder: Show path bar
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false     # Finder: Disable warning when changing filename extensions
defaults write com.apple.finder QLEnableTextSelection -bool TRUE               # Finder: Allow text selection in Quick Look        

#Disables Natural Scrolling
defaults write -g com.apple.swipescrolldirection -bool NO

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default (codes for the other view modes: `icnv`, `clmv`, `Flwv`)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

killall Finder

#Brew casks to Install

casks=(
github
visual-studio-code
firefox
opera
spotify
microsoft-teams
the-unarchiver
transmission
discord
battle-net
powershell
1password
opera
angry-ip-scanner
parallels
franz
twitch
balenaetcher
coconutbattery
camtasia
iterm2
minecraftpe
protonvpn
vmware-remote-console
)   

brew cask install --appdir="/Applications" ${casks[@]}

brew cleanup

#Install Oh-My-Zsh
# no need on catalina
#sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"