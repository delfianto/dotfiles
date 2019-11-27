#!/usr/bin/env ruby
#
# File cryptfs; ruby script for mounting encrypted volume
# based on the config on "${HOME}/.config/cryptfs.conf"
# only supports encfs and gocryptfs for now.
#
# Sample config content:
#
# [entry_name]
# app_type = 1 # "0" is encfs, "1" is gocryptfs
# src_path = encrypted_volume_path
# mnt_path = volume_mount_path
# vol_name = optional_volume_name
#
# If you have an entry named myvol then mount it with "cryptfs mnt myvol"

require "parseconfig"
require "pathname"
require "ptools"
require "thor"
require "os"

class CryptoFS
  attr_reader :app_type, :dir_name, :mnt_name, :mod_opts, 
              :mnt_opts, :src_path, :mnt_path, :osx_fuse,
              :app_gcfs, :app_ecfs, :dbg_flag, :ext_pass

  attr_writer :src_path, :mnt_path

  def initialize(config)
    @osx_fuse = "/library/filesystems/osxfuse.fs/contents/resources/load_osxfuse"
    @app_gcfs = "gocryptfs"
    @app_ecfs = "encfs"

    @dbg_flag = config["dbg_flag"].to_s == "true" # flag for debug message
    @ext_pass = config["ext_pass"].to_s == "true" # flag for native external pass app

    @app_type = config["app_type"] # internal app type, 0 is encfs, 1 is gocryptfs
    @dir_name = config["dir_name"] # source and mount name if using default path
    @mnt_name = config["mnt_name"] # optional custom volume name
    @mod_opts = config["mod_opts"] # fuse module options
    @mnt_opts = config["mnt_opts"] # mount options

    @src_path = config["src_path"]&.gsub("$HOME", Dir.home)
    @mnt_path = config["mnt_path"]&.gsub("$HOME", Dir.home)
  end

  def mount
    init_all_path

    case self.app_type.to_i
    when 0
      cmd = build_ecfs_cmd
    when 1
      cmd = build_gcfs_cmd
    else
      raise Error, "ERROR: Unknown application id #{self.app_type}"
    end

    if self.dbg_flag
      puts "Object state: #{self.inspect}\n\n"
      puts "Mount command: #{cmd}\n\n"
    end

    Process.detach(spawn(cmd))
  end

  private

  def init_all_path
    if (!src_path || !mnt_path) && !dir_name
      raise Error, "ERROR: If src_path or mnt_path is nil, dir_name must be defined."
    end

    self.src_path = get_dir(self.src_path) || 
        get_dir("#{Dir.home}/Google Drive/Applications/#{self.dir_name}")

    self.mnt_path = get_dir(self.mnt_path) || 
        get_dir("#{Dir.home}/Applications/#{self.dir_name}")
  end

  def build_ecfs_cmd
    cmd = get_bin(self.app_ecfs, "#{self.src_path}/.encfs6.xml")
    cmd << "-S -o #{self.mnt_opts} " if self.mnt_opts
    cmd << "volname=#{self.mnt_name}" if self.mnt_name
    return cmd
  end

  def build_gcfs_cmd
    cmd = get_bin(self.app_gcfs, "#{self.src_path}/gocryptfs.diriv")
    cmd << (self.dbg_flag ? " -debug -noexec " : " -quiet -noexec ")
    cmd << build_gcfs_extra_args
    cmd << "-o #{self.mnt_opts} " if self.mnt_opts
    cmd << "\'#{self.src_path}\' \'#{self.mnt_path}\'"
    return cmd
  end

  def build_gcfs_extra_args
    cmd = ""

    if OS.mac?
      system self.osx_fuse
      cmd << "-allow_other "
      cmd << "-extpass \'#{macos_ext_pass(self.dir_name, self.app_gcfs)}\' " if self.ext_pass
      cmd << "-ko local,noappledouble "
    elsif OS.linux?
      # compose linux specific args here, volname doesn't work on gocryptfs on macos
      cmd << "-ko volname=#{self.mnt_name} " if self.mnt_name
    else
      raise Error, "ERROR: Unsupported operating system #{OS.host_os}."
    end

    return cmd
  end

  def macos_ext_pass(dir, app)
    "security find-generic-password -a #{dir} -s #{app} -w"
  end

  def linux_ext_pass(dir, app)
    "something-to-test-here"
  end

  def get_dir(path)
    return nil if !path
    raise Error, "ERROR: Path #{path} is not an absolute path." if !Pathname.new(path).absolute?
    raise Error, "ERROR: Path #{path} does not exist." if !File.exist?(path)
    return path
  end

  def get_bin(app, crypt_file)
    bin = File.which(app)
    raise Error, "Error: #{bin} is not installed or not available in PATH" if bin.nil?
    raise Error, "ERROR: Directory is not a #{app} directory" if !File.exist?(crypt_file)    
    return bin
  end
end

class MyCLI < Thor
  desc "mount [CRYPT_DIR]", "Mount an encrypted volume."
  def mount(conf_key, pass = nil)
    key_file = ENV["LOCKER_SECRET_KEY"] || "#{Dir.home}/.config/cryptfs.conf"
    raise Error, "Config file does not exist." if !File.exists?(key_file)

    read_file(key_file) { |file, config|
      conf_map = config[conf_key]
      conf_map ? CryptoFS.new(conf_map).mount : 
          (raise Error, "ERROR: invalid key #{conf_key}.")
    }
  end

  private

  def read_file(file, &block)
    if !File.exist?(file)
      File.new(file, "w+").close
    end

    config = ParseConfig.new(file)
    block&.call(file, config)
  end

  map "mnt" => "mount"
end

MyCLI.start(ARGV)
