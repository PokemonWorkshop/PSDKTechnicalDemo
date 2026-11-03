# Project-side entry point of the PSDK Android exporter: copy this file into
# a project's plugins/. It runs the exporter of the latest PSDK-android
# release (see exporter/README.md), downloaded and kept up to date in
# ~/.psdk/android-exporter/, with the same arguments: callers (Pokemon
# Studio, makers) run it as they ran export_android.rb.
#
# An APK export without --apk also gets the base APK of that release, for
# the Ruby running this file (3.0, 3.2 or 3.3): the exporter and the APK it
# edits always come from the same release.
#
# Offline, or when GitHub doesn't answer, it runs the newest exporter
# already downloaded.
#
# Environment:
#   PSDK_ANDROID_RELEASE   a release tag (v1.2.11...) instead of the latest
#   PSDK_ANDROID_EXPORTER  a local exporter/ directory to run instead (a
#                          PSDK-android checkout, for its development)

require 'fileutils'
require 'json'
require 'net/http'
require 'rbconfig'
require 'uri'

module AndroidExporterPlugin
  module_function

  REPOSITORY    = 'Scorbutics/PSDK-android'
  RELEASES_URL  = "https://github.com/#{REPOSITORY}/releases"
  CACHE_DIR     = File.join(Dir.home, '.psdk', 'android-exporter')
  EXPORTER_DIR  = 'psdk-android-exporter'
  CHECK_TIMEOUT = 10
  MAX_REDIRECTS = 5

  def run(argv)
    local = ENV['PSDK_ANDROID_EXPORTER']
    return [File.join(local, 'export_android.rb'), argv] if local && !local.empty?

    release = fetch_release(ENV['PSDK_ANDROID_RELEASE'])
    problem = "#{RELEASES_URL} can't be reached" unless release
    # Releases before the exporter's (v1.2.11) don't carry it.
    if release && !exporter_asset(release)
      problem = "#{release['tag_name']} has no exporter (#{exporter_asset_name(release)})"
      release = nil
    end
    tag = release ? release['tag_name'] : newest_cached_tag
    abort "No PSDK Android exporter downloaded yet, and #{problem}: check the connection, or download " \
          "psdk-android-exporter-<version>.zip from #{RELEASES_URL} and set PSDK_ANDROID_EXPORTER " \
          "to its #{EXPORTER_DIR} folder" unless tag
    warn "  #{problem}: using the downloaded exporter #{tag}" unless release

    version_dir = File.join(CACHE_DIR, tag)
    exporter = File.join(version_dir, EXPORTER_DIR, 'export_android.rb')
    unless File.file?(exporter)
      install_exporter(release, version_dir)
      remove_other_versions(tag) unless ENV['PSDK_ANDROID_RELEASE']
    end

    argv += ['--apk', base_apk(release, version_dir)] if apk_export_without_base?(argv)
    [exporter, argv]
  end

  # The release `tag` (the latest one without), as the GitHub API describes
  # it, or nil when it can't be fetched.
  def fetch_release(tag)
    path = tag ? "tags/#{tag}" : 'latest'
    JSON.parse(http_get("https://api.github.com/repos/#{REPOSITORY}/releases/#{path}"))
  rescue StandardError
    nil
  end

  def newest_cached_tag
    Dir.glob('v*', base: CACHE_DIR)
       .select { |tag| File.file?(File.join(CACHE_DIR, tag, EXPORTER_DIR, 'export_android.rb')) }
       .max_by { |tag| Gem::Version.new(tag.delete_prefix('v')) rescue Gem::Version.new('0') }
  end

  def exporter_asset_name(release)
    "psdk-android-exporter-#{release['tag_name']}.zip"
  end

  def exporter_asset(release)
    release['assets'].find { |asset| asset['name'] == exporter_asset_name(release) }
  end

  def install_exporter(release, version_dir)
    puts "  Downloading the PSDK Android exporter #{release['tag_name']}..."
    zip_path = download(exporter_asset(release), version_dir)
    # rubyzip: the exporter needs it anyway.
    require 'zip'
    staging = "#{version_dir}/#{EXPORTER_DIR}.part"
    FileUtils.rm_rf(staging)
    Zip::File.open(zip_path) do |zip|
      zip.each do |entry|
        next unless entry.file? && entry.name.start_with?("#{EXPORTER_DIR}/")

        target = File.join(staging, entry.name.delete_prefix("#{EXPORTER_DIR}/"))
        FileUtils.mkdir_p(File.dirname(target))
        File.binwrite(target, entry.get_input_stream.read)
      end
    end
    File.rename(staging, File.join(version_dir, EXPORTER_DIR))
    File.delete(zip_path)
  end

  # The base APK of the release for this Ruby, downloaded once.
  def base_apk(release, version_dir)
    ruby = RbConfig::CONFIG.values_at('MAJOR', 'MINOR').join('.')
    name = "PSDK-android-ruby#{ruby}-release.apk"
    path = File.join(version_dir, name)
    return path if File.file?(path)

    abort "No #{name} downloaded, and #{RELEASES_URL} can't be reached: pass --apk <base APK>" unless release
    asset = release['assets'].find { |candidate| candidate['name'] == name }
    unless asset
      rubies = release['assets'].map { |candidate| candidate['name'][/\APSDK-android-ruby(.+)-release\.apk\z/, 1] }
      abort "PSDK-android #{release['tag_name']} has no APK for Ruby #{ruby} (#{rubies.compact.join(', ')} only): " \
            'pass --apk <base APK>, or run the export with one of these Rubies'
    end
    puts "  Downloading the base APK #{name} (#{release['tag_name']})..."
    download(asset, version_dir)
  end

  def remove_other_versions(tag)
    Dir.glob('v*', base: CACHE_DIR).each { |other| FileUtils.rm_rf(File.join(CACHE_DIR, other)) unless other == tag }
  end

  # An APK export (the default output, or -o *.apk) without --apk.
  def apk_export_without_base?(argv)
    return false if argv.any? { |arg| arg == '--apk' || arg.start_with?('--apk=') }
    return false if argv.include?('-h') || argv.include?('--help')

    output = nil
    argv.each_with_index do |arg, index|
      case arg
      when '-o', '--output' then output = argv[index + 1]
      when /\A--output=(.*)\z/m, /\A-o(.+)\z/m then output = Regexp.last_match(1)
      end
    end
    output.nil? || File.extname(output).casecmp?('.apk')
  end

  # Downloads `asset` into `dir`, through a .part file. Returns its path.
  def download(asset, dir)
    FileUtils.mkdir_p(dir)
    path = File.join(dir, asset['name'])
    File.open("#{path}.part", 'wb') { |file| http_get(asset['browser_download_url'], file) }
    File.rename("#{path}.part", path)
    path
  rescue StandardError => e
    FileUtils.rm_f("#{path}.part") if path
    abort "Can't download #{asset['browser_download_url']}: #{e.message}"
  end

  # GETs `url`, following redirects (GitHub serves assets from another
  # host): into `output` when given, else returns the body.
  def http_get(url, output = nil, redirects = MAX_REDIRECTS)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                        open_timeout: CHECK_TIMEOUT, read_timeout: CHECK_TIMEOUT * 6) do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'psdk-android-exporter-plugin'
      http.request(request) do |response|
        case response
        when Net::HTTPRedirection
          raise 'Too many redirects' if redirects.zero?

          return http_get(URI.join(url, response['location']).to_s, output, redirects - 1)
        when Net::HTTPSuccess
          return response.body unless output

          response.read_body { |chunk| output.write(chunk) }
          return
        else raise "HTTP #{response.code} for #{url}"
        end
      end
    end
  end
end

exporter, arguments = AndroidExporterPlugin.run(ARGV.dup)
ARGV.replace(arguments)
load exporter
