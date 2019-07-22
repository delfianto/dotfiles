#!/usr/bin/env ruby

require 'parseconfig'
require 'thor'

class MyCLI < Thor

  # exit with status code 1 if there's error
  def self.exit_on_failure?
    true
  end

  desc 'get', 'Show the current proxy config'
  def get
    puts "to be implemented"
  end

  desc 'set', 'Set the proxy configuration based on the parameters'
  method_option :type, :aliases => '-t', :type => :string, :default => 'http', :required => true
  method_option :host, :aliases => '-h', :type => :string, :required => true
  method_option :port, :aliases => '-p', :type => :numeric, :default => 8080,  :required => true
  def set
    type = options[:type].downcase; host = options[:host]; port = options[:port]
    raise Error, "ERROR: [#{type}] is not a valid proxy type"  if !['http', 'https', 'socks'].include?(type)
    raise Error, "ERROR: [#{port}] is not a valid port number" if !valid_port?(port)

    proxy = "#{type}://#{host}:#{port}"
    puts proxy

    parse('curlrc') { |file, config|
      config.add('proxy', proxy, true)
    }

    parse('wgetrc') { |file, config|
      config.add('use_proxy', 'on', true)

      ['ftp_proxy', 'http_proxy', 'https_proxy']
          .each { |it| config.add(it, proxy, true) }
    }
  end

  private
  def parse(name, &block)
    file = "#{Dir.home}/.#{name}"

    if !File.exist?(file)
      File.new(file, 'w+').close
    end

    config = ParseConfig.new(file)
    block&.call(file, config)

    target = File.open(file, 'w+')
    config.write(target, false)

    target.close
  end

  private
  def valid_port?(val)
    val.to_f.between?(1, 65535) if Float(val) rescue false
  end
end

MyCLI.start(ARGV)
