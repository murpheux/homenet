!/bin/bash
# cleanup


# clean-mac
rm -rf ~/Library/Caches/* # clean system cache
rm -rf ~/Library/Logs/* # clean system logs
rm -rf ~/Library/Containers/* # clean app containers
rm -rf ~/Library/Preferences/* # clean app preferences
rm -rf ~/Library/Application\ Support/* # clean app support files
rm -rf ~/Library/Cookies/* # clean cookies
rm -rf ~/Library/Saved\ Application\ State/* # clean saved application states
rm -rf ~/Library/Developer/* # clean Xcode and other developer files
rm -rf ~/Library/Keychains/* # clean keychains
rm -rf ~/Library/LaunchAgents/* # clean launch agents
rm -rf ~/Library/LaunchDaemons/* # clean launch daemons
rm -rf ~/Library/Logs/* # clean logs
rm -rf ~/Library/Preferences/* # clean preferences
rm -rf ~/Library/Saved\ Application\ State/* # clean saved application states
rm -rf ~/Library/WebKit/* # clean WebKit data
rm -rf ~/Library/Containers/com.apple.Safari/* # clean Safari data
rm -rf ~/Library/Containers/com.apple.mail/* # clean Mail data
rm -rf ~/Library/Containers/com.apple.TextEdit/* # clean TextEdit data
rm -rf ~/Library/Containers/com.apple.Preview/* # clean Preview data
rm -rf ~/Library/Containers/com.apple.Notes/* # clean Notes data
rm -rf ~/Library/Containers/com.apple.Calendar/* # clean Calendar data
rm -rf ~/Library/Containers/com.apple.Reminders/* # clean Reminders data
rm -rf ~/Library/Containers/com.apple.Maps/* # clean Maps data
rm -rf ~/Library/Containers/com.apple.Photos/* # clean Photos data
rm -rf ~/Library/Containers/com.apple.iTunes/* # clean iTunes data
rm -rf ~/Library/Containers/com.apple.AppStore/* # clean App Store data
rm -rf ~/Library/Containers/com.apple.Siri/* # clean Siri data
rm -rf ~/Library/Containers/com.apple.iCloud/* # clean iCloud data
rm -rf ~/Library/Containers/com.apple.FaceTime/* # clean FaceTime data
rm -rf ~/Library/Containers/com.apple.Music/* # clean Music data
rm -rf ~/Library/Containers/com.apple.TV/* # clean TV data
rm -rf ~/Library/Containers/com.apple.Podcasts/* # clean Podcasts data
rm -rf ~/Library/Containers/com.apple.Books/* # clean Books data
rm -rf ~/Library/Containers/com.apple.AppleIDAuthAgent/* # clean Apple ID data

sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder # flush DNS cache

find . -name "node_modules" -type d -mtime +120 | xargs rm -rf # remove node_modules folders older than 120 days

sudo purge # free up inactive memory

brew cleanup
mac-cleanup
mo clean

# clean-arch
sudo pacman -Scc


# clean-ubuntu
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove