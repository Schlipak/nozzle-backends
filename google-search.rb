#!/usr/bin/env ruby
#
# Returns a Google search for the input term
# Reacts to inputs as `g:<search terms>`
#
# Config usage:
# => exec=ruby
# => params=path/to/google-search.rb
# => name="Google Search"
#

require 'json'
require 'uri'

class GoogleSearchBackend
  def run
    $stderr.print '> '
    while input = $stdin.gets
      input = input.chomp.downcase if input
      result = if /^g:(.+)$/ =~ input
        search = $1.strip
        [{
          :name => 'Google',
          :description => "Search for `#{search}'",
          :exec => "xdg-open https://www.google.com/search?q=#{URI::escape search}",
          :icon => File.join(File.expand_path(File.dirname(__FILE__)), 'icons/google-search.png')
        }]
      else
        []
      end
      puts serialize(result)
      STDOUT.flush
      $stderr.print '> '
    end
  end

  private

  def serialize(data)
    {
      :backend => 'application',
      :version => '1.0.0',
      :priority => 9,
      :results => data
    }.to_json
  end
end

GoogleSearchBackend.new.run if __FILE__ == $0
