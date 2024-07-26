#!/usr/bin/env zsh

SYS_USERNAME=""
DEVICE_OWNER="WBOR 91.1 FM"
DEVICE_OWNER_EMAIL="wbor@bowdoin.edu"

# Directory where iTerm2 will look for preferences
ITERM_PREFS_LOCATION="/Users/$SYS_USERNAME/wbor-comp-env/"

# Prevent sleeping during script execution, as long as the machine is on AC power
caffeinate -s -w $$ &

# Attempt to list the contents of a directory that requires full disk access
check_full_disk_access() {
  if ls /Library/Application\ Support/com.apple.TCC &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Check for full disk access
if check_full_disk_access; then
  echo "Full disk access is granted - installation will proceed..."
else
  echo "Full disk access is not granted. Please grant full disk access to the terminal and try again! To do so: System Settings -> Privacy & Security -> Full Disk Access -> Enable/add Terminal.app"
  exit 1
fi

# Ask for the administrator password upfront
sudo -v

# Update existing `sudo` timestamp until script has finished
while -bool true; do sudo -n -bool true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "Closing any open System Settings windows so settings are not overwritten..."
osascript -e 'tell application "System Preferences" to quit'

echo "Closing any open services that we're about to change..."
killall Dock
killall SystemUIServer

echo "Closing any open apps that we're about to change..."
apps=("Finder" "Safari" "TextEdit" "Music" "Messages" "Photos" "VLC" "iTerm2")

for app in $apps; do
    if pgrep -x $app > /dev/null; then
        killall $app 2>/dev/null
        echo "$app closed."
    else
        echo "$app is not running, not closing."
    fi
done

echo "Wait for the xcode-select GUI installer and press enter. XCode command-line tools are required"
xcode-select --install
sudo xcodebuild -license accept

# Loop until the tools are successfully installed and the license is accepted
while :
do
    # Check if Xcode command-line tools are installed
    if ! xcode-select -p &> /dev/null; then
        echo "Xcode command-line tools not installed yet. Waiting..."
        sleep 5  # Wait for 5 seconds before checking again
    else
        echo "Xcode command-line tools installed!"

        # Check if the license has been accepted
        if sudo xcodebuild -license status | grep -q "not accepted"; then
            echo "Xcode license not accepted. Please accept the license..."
            sudo xcodebuild -license accept
        else
            echo "Xcode license accepted!"
            break  # Exit the loop since tools are installed and license accepted
        fi
    fi
done

echo "Set up .nanorc..."
echo 'set linenumbers' >> "/Users/$SYS_USERNAME/.nanorc"
echo 'include "'"$(brew --cellar nano)"'/*/share/nano/*.nanorc"' >> "/Users/$SYS_USERNAME/.nanorc"

echo "Installing Homebrew..."
/bin/bash -c "$(curl -fSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "Disabling Homebrew telemetry..."
brew analytics off

echo "Install Homebrew packages/casks/etc."
brew bundle install -v --file=../Homebrew/Brewfile

echo "Make Homebrew's version of zsh the default shell"
# Append brew's zsh install to the list of acceptable shells for chpass(1)
if ! fgrep -q '/opt/homebrew/bin/zsh' /etc/shells; then
  echo '/opt/homebrew/bin/zsh' | sudo tee -a /etc/shells
fi
# Change default shell to brew's zsh
chsh -s /opt/homebrew/bin/zsh

ZDOTDIR=~/.config/zsh
git clone https://github.com/mdrxy/zdotdir $ZDOTDIR

# symlink .zshenv
[[ -f ~/.zshenv ]] && mv -f ~/.zshenv ~/.zshenv.bak
ln -s $ZDOTDIR/.zshenv ~/.zshenv

# install omz
wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
ZSH="$ZDOTDIR/omz" install.sh

# Terminal needs to be restarted to launch from new zsh, but not necessary for the remainder of this script

sleep 1
echo "Part 1 of setup complete, beginning part 2 in 3 seconds..."
sleep 1
echo "3..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1

################################################################################
# Privacy
################################################################################

echo "Disable Apple ad telemetry"
defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
defaults write com.apple.AdLib forceLimitAdTracking -bool true

echo "Disable Firefox telemetry"
# Enable Firefox policies so the telemetry can be configured.
sudo defaults write /Library/Preferences/org.mozilla.firefox EnterprisePoliciesEnabled -bool true
# Disable sending usage data
sudo defaults write /Library/Preferences/org.mozilla.firefox DisableTelemetry -bool true

echo "Disable Microsoft Office diagnostics data sending"
defaults write com.microsoft.office DiagnosticDataTypePreference -string ZeroDiagnosticData

################################################################################
# Time and date
################################################################################

echo "Use 24 Hour Time system-wide"
defaults write -g AppleICUForce24HourTime -bool true
defaults write com.apple.menuextra.clock Show24Hour -bool true

echo "Turn on seconds in the menu bar clock"
defaults write com.apple.menuextra.clock ShowSeconds -bool true

echo "Flash separators between HH:MM:SS"
defaults write com.apple.menuextra.clock FlashDateSeparators -bool true

echo "Set the first day of the week to Monday"
defaults write -g AppleFirstWeekday -dict gregorian -int 2

echo "Set date format to ISO-8601"
defaults write -g AppleICUDateFormatStrings -dict-add 1 "y-MM-dd"

echo "Always show the date in the menu bar"
defaults write com.apple.menuextra.clock ShowDate -int 1

################################################################################
# Accessibility
################################################################################

echo "Enable Reduce Motion"
defaults write com.apple.Accessibility ReduceMotionEnabled -int 1
defaults write com.apple.universalaccess reduceMotion -bool true

################################################################################
# Sound
################################################################################

echo "Turn off system start chime"
defaults write -g com.apple.sound.beep.volume -float 0

echo "Turn off user inferface sound effects"
defaults write -g com.apple.sound.uiaudio.enabled -int 0

################################################################################
# Misc
################################################################################

echo "Expand the save pane by default"
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true

echo "Expand the print pane by default"
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write -g PMPrintingExpandedStateForPrint2 -bool true

echo "Disable action when double clicking on a window's title bar"
defaults write -g AppleActionOnDoubleClick -string "None"

echo "Automatically quit printer app once the print jobs complete"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

echo "Never prefer tabs when opening documents"
defaults write -g AppleWindowTabbingMode -string "manual"

echo "Set recent items to 0"
for category in 'applications' 'documents' 'servers'; do
  /usr/bin/osascript -e "tell application \"System Events\" to tell appearance preferences to set recent $category limit to 0"
done

# Untested
echo "Disable Xcode welcome window"
defaults write com.apple.dt.Xcode XCShowWelcomeWindow 0

echo "Turn off widgets banner"
defaults write com.apple.widgets ShowAddSheetOnboardingBanner -bool false

################################################################################
# Appearance
################################################################################

echo "Set system appearance to Dark Mode in case it isn't already"
defaults write -g AppleInterfaceStyle -string "Dark"

echo "Disable the focus ring animation (in search fields)"
defaults write -g NSUseAnimatedFocusRing -bool false

echo "Click in the scrollbar to jump to the spot that's clicked" 
defaults write -g AppleScrollerPagingBehavior -bool true

echo "Always show scroll bars when they're available"
# Possible values: `WhenScrolling`, `Automatic` and `Always`
defaults write -g AppleShowScrollBars -string "Always"

echo "Disable the crash reporter"
defaults write com.apple.CrashReporter DialogType -string "none"

################################################################################
# Menu bar / Control Center
################################################################################

echo "Show Display in menu bar when active"
defaults -currentHost write com.apple.controlcenter Display -int 2

echo "Sound: Don't show in menu bar"
defaults -currentHost write com.apple.controlcenter Sound -int 8

echo "Now Playing: Don't show in menu bar"
defaults -currentHost write com.apple.controlcenter NowPlaying -int 8

echo "WiFi: Don't show in menu bar"
defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false
defaults -currentHost write com.apple.controlcenter "WiFi" -int 8

echo "Hide Spotlight in the menu bar"
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

echo "Show sound recognition in the control center"
defaults -currentHost write com.apple.controlcenter MusicRecognition -int 9

################################################################################
# Dock
################################################################################

echo "Hide recent apps in dock"
defaults write com.apple.dock show-recents -bool false

echo "Minimize windows using: Scale effect"
defaults write com.apple.dock mineffect -string "scale"

echo "Minimize windows into application icon"
defaults write com.apple.dock minimize-to-application -bool true

echo "Click Wallpaper to reveal Desktop > Only in Stage Manager"
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

echo "Disable automatically rearranging Spaces based on most recent use"
defaults write com.apple.dock mru-spaces -bool false

echo "Turn off launch animations in Dock"
defaults write com.apple.dock launchanim -bool false

################################################################################
# Screenshots
################################################################################

echo "Disable date in screenshot filenames"
defaults write com.apple.screencapture include-date -bool false

################################################################################
# Finder / files
################################################################################

echo "Explicitly show the ~/Library directory"
chflags nohidden "${HOME}/Library"

echo "Remove macOS's default /Public/Drop Box"
sudo rm -rf "${HOME}/Public/Drop Box"

echo "Display all file extensions in Finder"
defaults write -g AppleShowAllExtensions -bool true

echo "Display status bar in Finder" 
defaults write com.apple.finder ShowStatusBar -bool true

echo "Display path bar above status bar in Finder" 
defaults write com.apple.finder ShowPathbar -bool true

echo "Sort folders on top of other files"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

echo "Automatically empty bin after 30 days"
defaults write com.apple.finder FXRemoveOldTrashItems -bool true

echo "Disable the trash emptying warning"
defaults write com.apple.finder WarnOnEmptyTrash -bool false

echo "Disable warning popup when changing file extensions"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

echo "Disable warning popup when deleting from iCloud Drive"
defaults write com.apple.finder FXEnableRemoveFromICloudDriveWarning -bool false

echo "Disable Finder window & Get Info pane animations"
defaults write com.apple.finder DisableAllAnimations -bool true

echo "Disable .DS_Store file writing on network volumes and removable media"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

echo "Save to disk instead of iCloud by default (in save/download menus)"
defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false

echo "Don't prompt to use new disks for TimeMachine backups"
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

echo "Delete default Finder tags"
defaults delete com.apple.finder FavoriteTagNames

echo "Set default Finder window to home directory"
defaults write com.apple.finder NewWindowTarget -string "PfHm"

echo "Don't show recent tags in Finder"
defaults write com.apple.finder ShowRecentTags -bool false

echo "Disable opening new tab behavior by Finder"
defaults write com.apple.finder FinderSpawnTab -bool false

################################################################################
# Keyboard
################################################################################

echo "Set a fast keyboard repeat rate"
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

echo "Turn off auto capitalization" 
defaults write -g NSAutomaticCapitalizationEnabled -bool true

echo "Disable smart dashes"
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false

echo "Disable automatic period substitution"
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false

echo "Disable smart quotes"
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false

echo "Repeats pressed key as long as it is held down"
defaults write -g ApplePressAndHoldEnabled -bool false

echo "Turn on Keyboard navigation"
defaults write -g AppleKeyboardUIMode -int 2

################################################################################
# Mouse / Trackpad
################################################################################

echo "Disable Look up & data detectors in trackpad"
defaults write -g com.apple.trackpad.forceClick -bool false
defaults write -g ContextMenuGesture -int 1

echo "Set trackpad speed"
defaults write -g com.apple.trackpad.scaling -float 1

echo "Set secondary click to 'Click in bottom right corner'"
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool false
defaults -currentHost write -g com.apple.trackpad.enableSecondaryClick -bool true

echo "Disable mouse acceleration"
defaults write -g com.apple.mouse.linear -bool true

echo "Enable trackpad tap to click"
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleBluetoothMultitouchTrackpad Clicking -bool true

echo "Make trackpad click sensitivity the lowest setting"
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0

echo "Disable trackpad rotating"
defaults write com.apple.AppleMultitouchTrackpad TrackpadRotate -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRotate -bool false
defaults -currentHost write -g com.apple.trackpad.rotateGesture -bool false

echo "Disable smart zoom in trackpad"
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerDoubleTapGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerDoubleTapGesture -int 0
defaults -currentHost write -g com.apple.trackpad.rotateGesture -int 0

echo "Disable pinching with thumb and three fingers to show Launchpad"
echo "Disable spreading thumb and three fingers to show Desktop"
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 0
defaults write com.apple.AppleBluetoothMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 0
defaults -currentHost write -g com.apple.trackpad.fiveFingerPinchSwipeGesture -int 0
defaults write com.apple.dock showDesktopGestureEnabled -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackPadFourFingerPinchGesture -int 0
defaults write com.apple.AppleBluetoothMultitouchTrackpad TrackpadFourFingerPinchGesture -int 0
defaults -currentHost write -g com.apple.trackpad.fourFingerPinchSwipeGesture -int 0
defaults write com.apple.dock showLaunchpadGestureEnabled -int 0


################################################################################
# TextEdit
################################################################################

echo "Disable RichText in TextEdit by default"
defaults write com.apple.TextEdit RichText -bool false

echo "Open and save files as UTF-8 in TextEdit"
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

################################################################################
# App Store
################################################################################

echo "Download newly available updates in background of App Store"
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

echo "Turn off prompting to leave reviews/rate apps"
defaults write com.apple.AppStore InAppReviewEnabled -bool false

################################################################################
# Safari
################################################################################

echo "Show full URL in Safari menu bar"
defaults write com.apple.safari ShowFullURLInSmartSearchField -bool true

echo "Set DuckDuckGo as the default search engine in Safari"
defaults write -g NSPreferredWebServices -dict-add NSWebServicesProviderWebSearch '{ NSDefaultDisplayName = DuckDuckGo; NSProviderIdentifier = "com.duckduckgo"; }'
defaults write com.apple.Safari SearchProviderShortName -string "DuckDuckGo"

echo "Disable top hit preloading in Safari"
defaults write com.apple.Safari PreloadTopHit -bool false

echo "Turn off Autofill in Safari / don't remember passwords"
defaults write com.apple.Safari AutoFillFromAddressBook -bool false
defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false
defaults write com.apple.Safari AutoFillPasswords -bool false

echo "Turn off opening downloads automatically in Safari"
defaults write com.apple.Safari AutoFillFromAddressBook -bool false

echo "Delete downloads from the list in Safari after successful download"
defaults write com.apple.Safari DownloadsClearingPolicy -int 2

echo "Clear history after 30 days"
defaults write com.apple.Safari HistoryAgeInDaysLimit -int 30

echo "Make the Safari homepage blank"
defaults write com.apple.Safari HomePage -string "about:blank"

echo "Don't show favorites in Safari"
defaults write com.apple.Safari ShowFavorites -bool false

echo "Don't show search suggestions in Safari"
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

echo "Don't let websites ask if they can send push notifications in Safari"
defaults write com.apple.Safari CanPromptForPushNotifications -bool false

echo "Tell sites to not track in Safari"
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

echo "Disable Safari's thumbnail cache for History and Top Sites"
defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

echo " Don't open downloaded files automatically"
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

################################################################################
# Photos
################################################################################

echo "Turn off memories notifications"
defaults write com.apple.photoanalysisd notificationDisabled -bool true

echo "Exclude location when sharing photos"
defaults write com.apple.photos.shareddefaults ExcludeLocationWhenSharing -bool true

echo "Prevent Photos from opening when a new device is plugged in"
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

################################################################################
# Calendar
################################################################################

echo "Show week numbers in Calendar"
defaults write com.apple.iCal "Show Week Numbers" -bool true

echo "Turn on timezone support in Calendar"
defaults write com.apple.iCal "TimeZone support enabled" -bool true

defaults write com.apple.iCal privacyPaneHasBeenAcknowledgedVersion -int 4

################################################################################
# Music
################################################################################

echo "Disable song change notifications in Music.app"
defaults write com.apple.Music userWantsPlaybackNotifications -bool false

echo "Turn off Sound Check in Music.app"
defaults write com.apple.Music optimizeSongVolume -bool false

echo "Turn off Sound Enhancer in Music.app"
defaults write com.apple.Music soundEnhancerEnabled -bool false

# Not 100% confident on this, seems fishy
echo "Turn off Dolby Atmos (under Playback tab) in Music.app"
defaults write com.apple.Music preferredDolbyAtmosPlaySetting -int 30

echo "Turn off popup warnings in Music.app"
defaults write com.apple.Music dontAskForPlaylistItemRemoval -bool true
defaults write com.apple.Music dontAskForPlaylistRemoval -bool true
defaults write com.apple.Music dontWarnWhenEditingMultiple -bool true
defaults write com.apple.Music dontWarnAboutRequiringExternalHardware -bool true

################################################################################
# Archive Utility
################################################################################

echo "Move archives to trash after extraction"
defaults write com.apple.archiveutility "dearchive-into" -string "."
defaults write com.apple.archiveutility "dearchive-move-after" -string "~/.Trash"
defaults write com.apple.archiveutility "dearchive-recursively" -bool true

################################################################################
# Activity Monitor
#
# More @ https://github.com/hjuutilainen/dotfiles/blob/master/bin/macos-user-defaults.sh
################################################################################

echo "Show all processes in Activity Monitor"
defaults write com.apple.ActivityMonitor ShowCategory -int 100

echp "Sort by CPU usage in Activity Monitor"
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

################################################################################
# Notes
################################################################################

echo "Skip initial welcome screen"
defaults write com.apple.Notes hasShownWelcomeScreen -bool true

echo "Don't show auto rearranging note checklist warning"
defaults write com.apple.Notes AutoSortChecklistAlertShown -bool true

################################################################################
# Terminal / iTerm2
################################################################################

echo "Only use UTF-8 in Terminal.app"
defaults write com.apple.terminal StringEncodings -array 4

echo "Don't display the annoying prompt when quitting iTerm"
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

echo "Configure iTerm2 to read preferences from iCloud"
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM_PREFS_LOCATION"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

echo "Don't send profile info to iTerm2 devs"
defaults write com.googlecode.iterm2 SUSendProfileInfo -bool false

################################################################################
# Updates
################################################################################

echo "Enable automatic update check in App Store"
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

echo "Check for software updates daily in App Store, not just once per week"
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

echo "Turn on app auto-update in App Store"
defaults write com.apple.commerce AutoUpdate -bool true

echo "Update extensions automatically in Safari"
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

echo "Tell VLC and iTerm2 to check for updates automatically"
defaults write org.videolan.vlc SUEnableAutomaticChecks -bool true
defaults write com.googlecode.iterm2 SUEnableAutomaticChecks -bool true

echo "Turn on auto-update in VLC and iTerm2"
defaults write org.videolan.vlc SUAutomaticallyUpdate -bool true
defaults write com.googlecode.iterm2 SUAutomaticallyUpdate -bool true

################################################################################
# Guest Accounts
################################################################################

echo "Disable guest sign-in from login screen"
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

echo "Disable guest access to file shares over AF"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool false

echo "Disable guest access to file shares over SMB"
sudo defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool false

################################################################################
# Siri
################################################################################

echo "Disable "Ask Siri""
defaults write com.apple.assistant.support 'Assistant Enabled' -bool false

echo "Disable Siri voice feedback"
defaults write com.apple.assistant.backedup 'Use device speaker for TTS' -int 3

echo "Disable "Do you want to enable Siri" pop-up"
defaults write com.apple.SetupAssistant 'DidSeeSiriSetup' -bool true

echo "Remove Siri from menu bar"
defaults write com.apple.systemuiserver 'NSStatusItem Visible Siri' 0

echo "Remove Siri from status menu"
defaults write com.apple.Siri 'StatusMenuVisible' -bool false
defaults write com.apple.Siri 'UserHasDeclinedEnable' -bool true

echo "Disable participation in Siri data collection"
defaults write com.apple.assistant.support 'Siri Data Sharing Opt-In Status' -int 2

################################################################################
# Finalize
################################################################################

# Restart QuickLook
qlmanage -r

# Restart affected services
killall Dock SystemUIServer Finder Safari TextEdit Music Messages Photos