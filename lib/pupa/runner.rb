require 'fileutils'
require 'optparse'

require 'moped'

module Pupa
  class Runner
    # @todo see ocd-division-ids scripts
    # arguments: module, actions, output_dir, cache_dir

    # @todo change base of expand_path
    output_dir = File.expand_path(File.join('.', 'scraped_data'), __dir__)
    cache_dir = File.expand_path(File.join('.', 'web_cache'), __dir__)

    FileUtils.mkdir_p(output_dir)
    FileUtils.mkdir_p(cache_dir)

    Dir[File.join(output_dir, '*.json')].each do |path|
      FileUtils.rm(path)
    end

    Pupa.session = Moped::Session.new([host_with_port], database: database)
  end
end