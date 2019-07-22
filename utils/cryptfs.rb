#!/usr/bin/env ruby
#
# File cryptfs; ruby script for mounting encrypted volume
# based on the config on '${HOME}/.config/cryptfs.conf'
# only supports encfs and gocryptfs for now.
#
# Sample config content:
#
# [global]
# # pre-init reserved for macOS
# fuse_bin = /Library/Filesystems/osxfuse.fs/Contents/Resources/load_osxfuse
#
# [entry_name]
# app_type = 1 # '0' is encfs, '1' is gocryptfs
# src_path = encrypted_volume_path
# mnt_path = volume_mount_path
# vol_name = optional_volume_name
# password = optional_volume_password
#
# If you have an entry named myvol then mount it with 'cryptfs mnt myvol'

require 'parseconfig'
require 'pathname'
require 'ptools'
require 'thor'

class MyCLI < Thor

  desc 'mount [CRYPT_DIR]', 'Mount an encrypted volume.'
  def mount(conf_key, pass = nil)
    key_file = ENV['LOCKER_SECRET_KEY'] || "#{Dir.home}/.config/cryptfs.conf"
    basename = Pathname.new(conf_key).absolute? ? (File.basename conf_key) : conf_key

    reserved = 'global'
    raise Error, "ERROR: #{reserved} is a reserved config key." if basename == reserved

    read_file(key_file) { |file, config|
      fuse_bin = config[reserved]['fuse_bin']

      conf_map = config[conf_key]
      raise Error, "ERROR: invalid config key #{conf_key}." if !conf_map

      src_path = conf_map['src_path'].gsub('$HOME', Dir.home)
      mnt_path = conf_map['mnt_path'].gsub('$HOME', Dir.home)

      check_path src_path
      check_path mnt_path

      password = conf_map['password'] || pass
      app_type = conf_map['app_type']
      fuse_opt = conf_map['fuse_opt']
      vol_name = conf_map['vol_name']

      raise Error, "ERROR: cannot read volume password for #{conf_key}" if !password
      raise Error, "ERROR: cannot read volume type config for #{conf_key}" if
        !app_type || (app_type.to_i < 0 || app_type.to_i > 1)

      case app_type.to_i
        when 0
          bin = File.which('encfs')
          opt = "-o #{fuse_opt} volname=#{vol_name} -S"
          raise Error, "ERROR: #{conf_key} is not a #{bin} directory" if
            !File.exist?("#{src_path}/.encfs6.xml")
        when 1
          bin = File.which('gocryptfs')
          opt = "-ko #{fuse_opt} -o allow_other"
          raise Error, "ERROR: #{conf_key} is not a #{bin} directory" if
            !File.exist?("#{src_path}/gocryptfs.diriv")
      end

      raise Error, "ERROR: #{bin} executable is not available in PATH" if !bin
      raise Error, "ERROR: #{mnt_path} is already mounted" if !Dir.empty?(mnt_path)

      password != nil ? cmd = "echo \'#{password}\' | " : cmd = ''
      cmd += "#{bin} #{opt} #{src_path} #{mnt_path}".strip

      system fuse_bin
      Process.detach(spawn(cmd))
    }
  end

  private
  def read_file(file, &block)
    if !File.exist?(file)
      File.new(file, 'w+').close
    end

    config = ParseConfig.new(file)
    block&.call(file, config)
  end

  private
  def check_path(path)
    raise Error, "ERROR: Path #{path} is not an absoluta path." if !Pathname.new(path).absolute?
    raise Error, "ERROR: Path #{path} does not exist." if !File.exist?(path)
  end

  map 'mnt' => 'mount'
end

MyCLI.start(ARGV)
