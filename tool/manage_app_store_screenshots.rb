#!/usr/bin/env ruby

require "digest/md5"
require "fastimage"
require "optparse"
require "spaceship"

APP_ID = "6761879857"
BUNDLE_ID = "jp.sunrise.signalpath"
VERSION_STRING = "5.0.0"
LOCALE = "zh-Hans"
DISPLAY_TYPE = "APP_IPHONE_67"
EXPECTED_SIZE = [1320, 2868].freeze
DEFAULT_SOURCE_DIR = File.expand_path(
  "../release_assets/app_store/2026-08-03/final/iphone-6.9/zh-Hans",
  __dir__,
)

def abort_with(message)
  warn(message)
  exit(1)
end

def screenshot_files(source_dir)
  files = Dir.glob(File.join(source_dir, "*.png")).sort
  abort_with("Expected 1-10 PNG screenshots; found #{files.length}") unless (1..10).cover?(files.length)

  files.each do |path|
    size = FastImage.size(path)
    abort_with("#{File.basename(path)} is #{size.inspect}; expected #{EXPECTED_SIZE.inspect}") unless size == EXPECTED_SIZE
  end
  files
end

def connect!
  token = Spaceship::ConnectAPI::Token.create(
    key_id: ENV.fetch("ASC_KEY_ID"),
    issuer_id: ENV.fetch("ASC_ISSUER_ID"),
    filepath: ENV.fetch("ASC_KEY_PATH"),
    duration: 1_000,
    in_house: false,
  )
  Spaceship::ConnectAPI.token = token
end

def screenshot_state(set)
  screenshots = set.app_screenshots || []
  {
    display_type: set.screenshot_display_type,
    count: screenshots.length,
    files: screenshots.map(&:file_name),
    states: screenshots.map { |item| item.asset_delivery_state&.fetch("state", nil) },
  }
end

source_dir = DEFAULT_SOURCE_DIR
apply = false
OptionParser.new do |options|
  options.banner = "Usage: manage_app_store_screenshots.rb [--source DIR] [--apply]"
  options.on("--source DIR", "Directory containing ordered PNG screenshots") { |value| source_dir = File.expand_path(value) }
  options.on("--apply", "Replace only the target locale/device screenshot set") { apply = true }
end.parse!

files = screenshot_files(source_dir)
connect!

app = Spaceship::ConnectAPI::App.find(BUNDLE_ID)
abort_with("App #{BUNDLE_ID} was not found") unless app
abort_with("Unexpected App Store app id #{app.id}") unless app.id == APP_ID

version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
abort_with("No editable iOS App Store version was found") unless version
abort_with("Expected version #{VERSION_STRING}; found #{version.version_string}") unless version.version_string == VERSION_STRING
abort_with("Version is not PREPARE_FOR_SUBMISSION") unless version.app_version_state == "PREPARE_FOR_SUBMISSION"

localization = version.get_app_store_version_localizations.find { |item| item.locale == LOCALE }
abort_with("Localization #{LOCALE} was not found") unless localization

sets = localization.get_app_screenshot_sets
expected_checksums = files.map { |path| Digest::MD5.file(path).hexdigest }
puts("Version #{version.version_string}: #{version.app_version_state}")
puts("Existing #{LOCALE} screenshot sets:")
sets.each { |set| puts(screenshot_state(set).inspect) }
puts("Local screenshots: #{files.map { |path| File.basename(path) }.inspect}")
target_sets = sets.select { |set| set.screenshot_display_type == DISPLAY_TYPE }
if target_sets.length == 1
  current_checksums = (target_sets.first.app_screenshots || []).map(&:source_file_checksum)
  puts("Target set already matches local files: #{current_checksums == expected_checksums}")
end

unless apply
  puts("Read-only check complete. Re-run with --apply to replace only #{LOCALE} #{DISPLAY_TYPE} screenshots.")
  exit(0)
end

target_sets.each do |set|
  puts("Deleting existing #{LOCALE} #{DISPLAY_TYPE} screenshot set #{set.id}")
  set.delete!
end

target_set = localization.create_app_screenshot_set(
  attributes: { screenshotDisplayType: DISPLAY_TYPE },
)

uploaded = files.map do |path|
  puts("Uploading #{File.basename(path)}")
  target_set.upload_screenshot(path: path, wait_for_processing: true)
end
target_set.reorder_screenshots(app_screenshot_ids: uploaded.map(&:id))

verified = Spaceship::ConnectAPI::AppScreenshotSet.get(
  app_screenshot_set_id: target_set.id,
)
actual_checksums = verified.app_screenshots.map(&:source_file_checksum)
abort_with("Uploaded screenshot order/checksums do not match local files") unless actual_checksums == expected_checksums
abort_with("Not every screenshot finished processing") unless verified.app_screenshots.all?(&:complete?)

puts("Uploaded and verified #{verified.app_screenshots.length} #{LOCALE} #{DISPLAY_TYPE} screenshots in filename order.")
puts("Version remains #{version.app_version_state}; no review submission endpoint was called.")
