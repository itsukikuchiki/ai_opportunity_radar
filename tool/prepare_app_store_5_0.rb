#!/usr/bin/env ruby

require "json"
require "jwt"
require "net/http"
require "openssl"
require "uri"

API_ROOT = "https://api.appstoreconnect.apple.com"
EDITABLE_STATES = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED METADATA_REJECTED].freeze

def abort_with(message)
  warn(message)
  exit(1)
end

def token
  @token ||= JWT.encode(
    {
      iss: ENV.fetch("ASC_ISSUER_ID"),
      exp: Time.now.to_i + 900,
      aud: "appstoreconnect-v1",
    },
    OpenSSL::PKey::EC.new(File.read(ENV.fetch("ASC_KEY_PATH"))),
    "ES256",
    { kid: ENV.fetch("ASC_KEY_ID") },
  )
end

def request(method, path, body: nil)
  uri = URI.join(API_ROOT, path)
  request_class = {
    get: Net::HTTP::Get,
    patch: Net::HTTP::Patch,
  }.fetch(method)
  req = request_class.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(req)
  end
  parsed = response.body.empty? ? {} : JSON.parse(response.body)
  unless response.is_a?(Net::HTTPSuccess)
    abort_with("#{method.to_s.upcase} #{path} failed (#{response.code}): #{JSON.generate(parsed)}")
  end
  puts("#{method.to_s.upcase} #{path} -> #{response.code}")
  parsed
end

def get_all(path)
  items = []
  next_path = path
  while next_path
    payload = request(:get, next_path)
    items.concat(payload.fetch("data", []))
    next_link = payload.dig("links", "next")
    next_path = next_link&.sub(API_ROOT, "")
  end
  items
end

def validate!(metadata)
  expected = %w[en-US ja zh-Hans zh-Hant]
  actual = metadata.fetch("localizations").keys.sort
  abort_with("Expected locales #{expected.sort.inspect}; got #{actual.inspect}") unless actual == expected.sort

  limits = {
    "name" => 30,
    "subtitle" => 30,
    "promotionalText" => 170,
    "keywords" => 100,
    "description" => 4_000,
    "whatsNew" => 4_000,
  }
  metadata.fetch("localizations").each do |locale, values|
    limits.each do |field, limit|
      length = values.fetch(field).each_char.count
      abort_with("#{locale} #{field} is #{length}/#{limit} characters") if length > limit
    end
  end
end

metadata_path = ARGV.find { |arg| !arg.start_with?("--") } ||
  File.expand_path("../release_assets/app_store/2026-08-03/app_store_metadata.json", __dir__)
apply = ARGV.include?("--apply")
metadata = JSON.parse(File.read(metadata_path))
validate!(metadata)

unless apply
  puts("Metadata is valid. Re-run with --apply to update App Store Connect without submitting.")
  exit(0)
end

app_id = metadata.fetch("appId")
version_string = metadata.fetch("version")
build_number = metadata.fetch("build")
build_id = metadata.fetch("buildId")

versions = get_all("/v1/apps/#{app_id}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=50")
version = versions.find { |item| item.dig("attributes", "versionString") == version_string } ||
  versions.find { |item| EDITABLE_STATES.include?(item.dig("attributes", "appStoreState")) }
abort_with("No editable iOS App Store version exists") unless version

build = request(:get, "/v1/builds/#{build_id}").fetch("data")
unless build.dig("attributes", "processingState") == "VALID" &&
       build.dig("attributes", "version") == build_number
  abort_with("Build #{build_id} is not VALID build number #{build_number}")
end

request(
  :patch,
  "/v1/appStoreVersions/#{version.fetch("id")}",
  body: {
    data: {
      type: "appStoreVersions",
      id: version.fetch("id"),
      attributes: { versionString: version_string },
      relationships: {
        build: { data: { type: "builds", id: build.fetch("id") } },
      },
    },
  },
)

version_localizations = get_all(
  "/v1/appStoreVersions/#{version.fetch("id")}/appStoreVersionLocalizations?limit=50",
)
version_localizations.each do |localization|
  locale = localization.dig("attributes", "locale")
  values = metadata.fetch("localizations").fetch(locale)
  request(
    :patch,
    "/v1/appStoreVersionLocalizations/#{localization.fetch("id")}",
    body: {
      data: {
        type: "appStoreVersionLocalizations",
        id: localization.fetch("id"),
        attributes: {
          description: values.fetch("description"),
          keywords: values.fetch("keywords"),
          marketingUrl: metadata.dig("urls", "marketing"),
          promotionalText: values.fetch("promotionalText"),
          supportUrl: metadata.dig("urls", "support"),
          whatsNew: values.fetch("whatsNew"),
        },
      },
    },
  )
end

app_infos = get_all("/v1/apps/#{app_id}/appInfos?limit=50")
app_info = app_infos.find { |item| EDITABLE_STATES.include?(item.dig("attributes", "appStoreState")) }
abort_with("No editable App Info exists") unless app_info

info_localizations = get_all(
  "/v1/appInfos/#{app_info.fetch("id")}/appInfoLocalizations?limit=50",
)
info_localizations.each do |localization|
  locale = localization.dig("attributes", "locale")
  values = metadata.fetch("localizations").fetch(locale)
  request(
    :patch,
    "/v1/appInfoLocalizations/#{localization.fetch("id")}",
    body: {
      data: {
        type: "appInfoLocalizations",
        id: localization.fetch("id"),
        attributes: {
          name: values.fetch("name"),
          subtitle: values.fetch("subtitle"),
          privacyPolicyUrl: metadata.dig("urls", "privacyPolicy"),
        },
      },
    },
  )
end

puts("Prepared App Store version #{version_string} (#{build_number}); no review submission endpoint was called.")
