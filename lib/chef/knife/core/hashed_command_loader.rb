# Author:: Steven Danna (<steve@chef.io>)
# Copyright:: Copyright (c) 2015 Chef Software, Inc
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
class Chef
  class Knife
    class SubcommandLoader

      #
      # Load a subcommand from a pre-computed path
      # for the given command.
      #
      #
      class HashedCommandLoader
        attr_accessor :manifest
        def initialize(chef_config_dir, plugin_manifest)
          @manifest = plugin_manifest
        end

        def subcommand_files
          manifest.values.flatten
        end

        def load_command(args)
          command_info = manifest[subcommand_for_args(args)]
          if command_info.nil?
            ui.fatal("Cannot find sub command for: #{args.join('')}")
            ui.fatal("If you recently installed this command, try running: knife rehash -r")
            exit 10
          elsif command_info['paths'].nil? || command_info['path'].empty?
            ui.fatal("Cached information for this subcommand appears to be improperly formatted.")
            ui.fatal("Try running knife rehash -r or removing #{plugin_manifest_path}")
          else
            command_info['paths'].each do |sc|
              Kernel.load sc
            end
          end
        end

        def subcommand_for_args(args)
          Chef::Knife::SubcommandLoader.find_longest_key(manifest, positional_args(args), "_")
        end
      end
    end
  end
end
