#!/usr/bin/env ruby
#
# Lists *.desktop application entries using fuzzy matching
# Searches in $HOME/.local/share/applications
#             /usr/share/applications
#             /usr/local/share/applications
#
# Needs fuzzystringmatch, install using `gem install fuzzy-string-match`
#
# Config usage:
# => exec=ruby
# => params=path/to/applications.rb
# => name="Applications"
#

require 'json'
require 'fuzzystringmatch'

class String
  def underscore
    gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      .gsub(/([a-z\d])([A-Z])/,'\1_\2')
      .tr('- ', '_')
      .downcase
  end
end

class ApplicationEntry
  def initialize(entry)
    @data = parse_entry entry
  end

  attr_accessor :distance

  def method_missing(method_sym)
    @data[method_sym]
  end

  def match_data=(md)
    @match_data = md
  end

  def compute_distance(jarow, input)
    @distance = 0.0

    name = @data[:name] if @data
    return unless name && input
    input = input.downcase

    @distance = jarow.getDistance input, name
  end

  def data
    clone = @data.clone
    clone[:description] = clone.delete :comment
    clone[:description] = clone.delete(:comment_i18n) if clone[:comment_i18n]
    clone[:description] = clone.delete(:generic_name) unless clone[:description]
    clone[:name] = highlight_fuzzy clone[:name]
    clone[:exec] = clean_exec clone[:exec]
    clone
  end

  private

  def clean_exec(exec)
    exec.gsub(/%[fFuUdDnNkv]/, '').strip
  end

  def highlight_fuzzy(name)
    matches = @match_data.to_a
    matches.shift
    highlight = ""
    offset = 0
    matches.each_with_index do |match, nth|
      chunk = name[offset...(offset + match.length)]
      highlight += if match == matches[0]
                     chunk
                   else
                     "<u>#{chunk[0]}</u>#{chunk[1..-1]}"
                   end
      offset += match.length
    end
    highlight + name[offset..-1]
  end

  def locale
    @locale ||= ENV['LANGUAGE']
  end

  def parse_entry(entry)
    entry_data = {}
    section = ''
    entry.lines.each do |line|
      if /^\[(.+)\]$/ =~ line
        section = $1
      end
      next unless section == 'Desktop Entry'
      next unless /^.*=.*$/ =~ line.chomp
      prop, value = line.chomp.split('=', 2)
      next if /^X-[^-]+/ =~ prop
      if /^(.+)\[(.+)\]$/ =~ prop
        i18n_prop = "#{$1.underscore}_i18n".to_sym
        if locale =~ %r{^#{$2}(?:_.+)?$}
          entry_data[i18n_prop] = cast_value(value)
        end
      else
        entry_data[prop.underscore.to_sym] = cast_value(value)
      end
    end
    entry_data
  end

  def cast_value(value)
    return unless value.respond_to? :downcase
    return false if value.downcase == "false"
    return true if value.downcase == "true"
    return value.to_f if /^\d+(?:[\.,]\d*)?$/ =~ value
    return value.split(';') if /^(?:[^;]+;)+$/ =~ value
    value
  end
end

class Backend
  MINIMUM_INPUT_LENGTH = 3

  def initialize
    @jarow = FuzzyStringMatch::JaroWinkler.create :pure
  end

  def start
    apps = find_apps
    $stderr.print '> '
    while input = $stdin.gets
      input = input.chomp.downcase if input
      filtered = if input.length >= MINIMUM_INPUT_LENGTH
        regex = fuzzy_find input
        apps.select do |app|
          app_name = app.name
          app_name = app_name.downcase if app_name
          md = regex.match app_name
          app.compute_distance @jarow, input if md
          app.match_data = md
        end.sort_by(&:distance).reverse
      else
        []
      end
      puts serialize(filtered)
      STDOUT.flush
      $stderr.print '> '
    end
  end

  private

  def fuzzy_find(search)
    start = search[0..-2]
    end_char = Regexp.escape search[-1]
    reg = start.split('').map { |s| "(#{Regexp.escape s}.*?)" }.join('')
    return Regexp.new "(.*)#{reg}(#{end_char})"
  end

  def find_apps
    apps = []
    files = [
      Dir["#{ENV['HOME']}/.local/share/applications/*.desktop"],
      Dir['/usr/share/applications/*.desktop'],
      Dir['/usr/local/share/applications/*.desktop']
    ].flatten
    files.each do |desktop|
      data = File.read(desktop)
      app = ApplicationEntry.new(data)
      apps << app unless app.no_display
    end
    apps.uniq { |app| [app.name, app.exec] }
  end

  def serialize(filtered)
    filtered = filtered.map &:data

    {
      :backend => 'application',
      :version => '1.0.0',
      :priority => 2,
      :results => filtered
    }.to_json
  end
end

Backend.new.start if __FILE__ == $0
