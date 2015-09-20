#!/usr/bin/env ruby
require 'optparse'
require 'find'

class String
  def join(path)
    File.join(self, path)
  end
end

def error(message, num)
  warn "error: #{message}"
  exit(num)
end

def goodbye(message)
  puts message
  exit(0)
end

ERROR_MESSAGE = {
  enough:  'Not enough arguments.',
  many:    'Too many arguments.',
  onlyone: 'Can be specified rename-option is only one.',
  type: 'Invalid type, You can use file, dir and all. The default is file.',
}

HELP_MESSAGE = {
  replace: 'replace before to after. The default value of after is empty string.',
  type: 'The kind of the targets. You ca use file, dir and all.',
  dir: 'Replace target directory',
}


module RenameUtils# {{{
  class RenameRoutineError  < StandardError; end      #code bug
  class RenameStandardError < RenameRoutineError; end #catch this exception

  #you can use regexp ^,$,?,* in before-string # {{{
  #エスケープしたくない文字もある
  def simple_escape!(str)
    '(){}[]+.'.each_char {|c| str.gsub!(c, '\\'+c) }
    str.gsub!('?', '.')
    str.gsub!('*', '.*?')
    return str
  end

  def simple_escape(str)
    simple_escape!(str.dup)
  end
  # }}}

  # Parse directly arguments.
  def argv_parse(arguments)# {{{
    argv = arguments.dup
    opt = { mode: nil, before: nil, after: '', type: :file, dir: './', } #default values
    parser = OptionParser.new
    parser.banner = 'Usage: rbrn <mode [args..]> [-t type] [-d dir]'

    parser.on('-r BEFORE [AFTER]', HELP_MESSAGE[:replace]) do |before|
      opt[:mode] = :replace
      opt[:before] = before
    end

    parser.on('-t TYPE', HELP_MESSAGE[:type]) do |type|
      if /^(file|dir|all)$/ =~ type
        opt[:type] = type.to_sym
      else
        error(ERROR_MESSAGE[:type], 12)
      end
    end

    parser.on('-d DIR', HELP_MESSAGE[:dir]) do |dir|
      opt[:dir] = dir
    end

    parser.parse!(argv)

    # Get after string of the replace mode
    if opt[:mode] == :replace && !argv.empty?
      opt[:after] = argv.shift
    end

    return opt
  rescue OptionParser::MissingArgument, OptionParser::InvalidOption=> ex
    error(ex.message, 13)
  end# }}}

  def get_pathes(opt)# {{{
    error("#{opt[:dir]} is not exist.", 30) unless Dir.exist?(opt[:dir])

    pathes = Dir.glob(opt[:dir].join("*"))
    case opt[:type]
    when :file
      pathes.select!{ |path| File.file?(path) }
    when :dir
      pathes.select!{ |path| File.directory?(path) }
    end
    exit(0) if pathes.empty?

    return pathes.sort_by! { |path| File.basename(path) }
  end# }}}

  def get_before_after(opt, pathes)# {{{
    regexp = Regexp.new(simple_escape(opt[:before]))

    path_pairs = pathes.map do |path|
      before_name = File.basename(path)
      after_name  = before_name.gsub(regexp, opt[:after])
      next nil if before_name == after_name

      puts "'%-32s' => '%s'" % [before_name, after_name]
      next [path, opt[:dir].join(after_name)]
    end

    return path_pairs.compact
  end# }}}

  #if elements is not deleted return nil.
  def safe_rename_pairs!(path_pairs) # {{{
    return path_pairs.reject! do |old, new|
      next !File.exist?(new) && File.rename(old, new)
    end
  end # }}}

  # execute safe_rename_pairs! while can rename.
  def recursive_rename!(path_pairs)# {{{
    return true if path_pairs.empty?

    unless safe_rename_pairs!(path_pairs)
      warn "Overlap: The following files did not rename, because already exist"
      path_pairs.each {|old, new| puts "#{old} => #{new}" }
      return false
    end

    return recursive_rename!(path_pairs)
  end# }}}
end# }}}

#main-routine
if __FILE__ == $0
  Version = 2.2
  include RenameUtils

  #preprocessing parse arguments.
  ARGV[0] = '--help' if ARGV.empty?
  error('Invalid arguments. need <mode>', 0) unless ARGV.any? {|s| s[0] == '-' }

  #get options
  opt = argv_parse(ARGV)

  #emnurate_targets
  pathes = get_pathes(opt)

  # show rename candidate and get it.
  bf_pairs = get_before_after(opt, pathes)
  puts "\nrename #{bf_pairs.size}/#{pathes.size}"

  exit if bf_pairs.size == 0

  print 'Rename these? (y/N) '
  if /^(Y|YES)$/i =~ STDIN.gets.to_s.chomp
    recursive_rename!(bf_pairs)
  end
end