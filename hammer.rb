require 'rubygems'
require 'securerandom'
require 'time'
require 'fileutils'

DEST=File.expand_path("/Users/jonathan/Library/Application\ Support/iPhone\ Simulator/6.1/Applications/7368A09B-EC4F-49A5-B160-706E66ACED6D/Documents/Journal")

files = []

date_range = 10 * 25 * 60 * 60    # in seconds

(1..1000).each do |i|
  uuid = SecureRandom.hex
  fname = DEST + "/JournalEntry;#{uuid}.txt"
  File.open(fname, 'w') do |f|
    f.puts <<EOP % [(Time.now.utc - SecureRandom.random_number(date_range)).iso8601, "For #{i} - #{uuid}"]
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>timestamp</key>
  <date>%s</date>
  <key>content</key>
  <string>%s</string>
</dict>
</plist>
EOP
  end
  files << fname
end

