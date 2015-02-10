# Author:: Christopher Brown (<cb@opscode.com>)
# Author:: Daniel DeLeo (<dan@opscode.com>)
# Copyright:: Copyright (c) 2009, 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/version'
require 'chef/util/path_helper'
class Chef
  class Knife
    #
    # Public Methods of a Subcommand Loader
    #
    # load_commands            - loads all available subcommands
    # load_command(args)       - loads subcommands for the given args
    # list_commands(args)      - lists all available subcommands, optionally filtering by category
    # subcommand_files         - returns an array of all subcommand files that could be loaded
    # commnad_class_from(args) - returns the subcommand class for the user-requested command
    #
    class SubcommandLoader

      attr_reader :chef_config_dir
      attr_reader :env

      def initialize(chef_config_dir, env=ENV)
        @chef_config_dir, @env = chef_config_dir, env
        @forced_activate = {}
      end

      # Load all the sub-commands
      def load_commands
        subcommand_files.each { |subcommand| Kernel.load subcommand }
        true
      end

      def load_command(command_name)
        load_commands
      end

      def list_commands(preferred_category=nil)
        load_commands
        if preferred_category && Chef::Knife.subcommands_by_category.key?(preferred_category)
          {preferred_category => Chef::Knife.subcommands_by_category[preferred_category]}
        else
          Chef::Knife.subcommands_by_category
        end
      end

      def command_class_from(args)
        cmd_words = positional_arguments(args)
        cmd_name = cmd_words.join('_')
        load_command(cmd_name)
        result = Chef::Knife.subcommands[find_longest_key(Chef::Knife.subcommands, cmd_words, "_")]
        result || Chef::Knife.subcommands[args.first.gsub('-', '_')]
      end

      def guess_category
        category_words = positional_arguments(args)
        category_words.map! {|w| w.split('-')}.flatten!
        find_longest_key(Chef::Knife.subcommands_by_category, category_words, " ")
      end

      def subcommand_files
        raise NotImplementedError
      end

      #
      # Utility function for finding an element in a hash given an array
      # of words and a separator.  We find the the longest key in the
      # hash composed of the given words joined by the separator.
      #
      def find_longest_key(hash, words, sep='_')
        match = nil
        while ! (match || words.empty?)
          candidate = words.join(sep)
          if hash.key?(candidate)
            match = candidate
          else
            words.pop
          end
        end
        match
      end

      #
      # The positional arguments from the argument list provided by the
      # users. Used to search for subcommands and categories.
      #
      # @return [Array<String>]
      #
      def positional_arguments(args)
        args.select {|arg| arg =~ /^(([[:alnum:]])[[:alnum:]\_\-]+)$/ }
      end


      # Returns an Array of paths to knife commands located in chef_config_dir/plugins/knife/
      # and ~/.chef/plugins/knife/
      def site_subcommands
        user_specific_files = []

        if chef_config_dir
          user_specific_files.concat Dir.glob(File.expand_path("plugins/knife/*.rb", Chef::Util::PathHelper.escape_glob(chef_config_dir)))
        end

        # finally search ~/.chef/plugins/knife/*.rb
        user_specific_files.concat Dir.glob(File.join(Chef::Util::PathHelper.escape_glob(env['HOME'], '.chef', 'plugins', 'knife'), '*.rb')) if env['HOME']

        user_specific_files
      end
    end
  end
end
