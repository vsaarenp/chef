#
# Author:: Tyler Cloke (tyler@chef.io)
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

require 'chef/json_compat'
require 'chef/mixin/params_validate'

class Chef
  class Key

    include Chef::Mixin::ParamsValidate

    attr_reader :actor_field_name

    def initialize(actor, actor_field_name)
      # Actor that the key is for, either a client or a user.
      @actor = actor

      unless actor_field_name == "user" || actor_field_name == "client"
        raise ArgumentError.new("the second argument to initialize must be either 'user' or 'client'")
      end

      @actor_field_name = actor_field_name

      @name = nil
      @public_key = nil
      @expiration_date = nil
    end

    def actor(arg=nil)
      set_or_return(:actor, arg,
                    :regex => /^[a-z0-9\-_]+$/)
    end

    def name(arg=nil)
      set_or_return(:name, arg,
                    :regex => /^[a-z0-9\-_]+$/)
    end

    def public_key(arg=nil)
      set_or_return(:public_key, arg,
                    :kind_of => String)
    end

    def expiration_date(arg=nil)
      set_or_return(:expiration_date, arg,
                    :regex => /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z|infinity)$/)
    end

    def to_hash
      result = {
        @actor_field_name => @actor,
      }
      result["name"] = @name if @name
      result["public_key"] = @public_key if @public_key
      result["expiration_date"] = @expiration_date if @expiration_date
      result
    end

    def to_json(*a)
      Chef::JSONCompat.to_json(to_hash, *a)
    end

    def create
      if @public_key.nil? || @expiration_date.nil?
        raise ArgumentError.new("public_key and expiration_date fields must be populated when create is called")
      end

      # defaults the key name to the fingerprint of the key
      if @name == nil
        # TODO: is it safe to assume we aren't dealing with certs here?
        openssl_key_object = OpenSSL::PKey::RSA.new(@public_key)
        data_string = OpenSSL::ASN1::Sequence([
                                                OpenSSL::ASN1::Integer.new(openssl_key_object.public_key.n),
                                                OpenSSL::ASN1::Integer.new(openssl_key_object.public_key.e)
                                              ])
        @name = OpenSSL::Digest::SHA1.hexdigest(data_string.to_der).scan(/../).join(':')
      end

      payload = {"name" => @name, "public_key" => @public_key, "expiration_date" => @expiration_date}
      if @actor_field_name == "user"
        new_key = Chef::REST.new(Chef::Config[:chef_server_root]).post_rest("users/#{@actor}/keys", payload)
      else
        new_key = Chef::REST.new(Chef::Config[:chef_server_url]).post_rest("clients/#{@actor}/keys", payload)
      end
      Chef::Key.from_hash(new_key)
    end

    def update
      if @name.nil?
        raise ArgumentError.new("the name field must be populated when update is called")
      end

      if @actor_field_name == "user"
        new_key = Chef::REST.new(Chef::Config[:chef_server_root]).put_rest("users/#{@actor}/keys/#{@name}", to_hash)
      else
        new_key = Chef::REST.new(Chef::Config[:chef_server_url]).put_rest("clients/#{@actor}/keys/#{@name}", to_hash)
      end
      Chef::Key.from_hash(self.to_hash.merge(new_key))
    end

    def save
      begin
        create
      rescue Net::HTTPServerException => e
        if e.response.code == "409"
          update
        else
          raise e
        end
      end
    end

    def destroy
      if @name.nil?
        raise ArgumentError.new("the name field must be populated when delete is called")
      end

      if @actor_field_name == "user"
        Chef::REST.new(Chef::Config[:chef_server_root]).delete_rest("users/#{@actor}/keys/#{@name}")
      else
        Chef::REST.new(Chef::Config[:chef_server_url]).delete_rest("clients/#{@actor}/keys/#{@name}")
      end
    end

    # Class methods
    def self.from_hash(key_hash)
      if key_hash.has_key?("user")
        key = Chef::Key.new(key_hash["user"], "user")
      else
        key = Chef::Key.new(key_hash["client"], "client")
      end
      key.name key_hash['name'] if key_hash.key?('name')
      key.public_key key_hash['public_key'] if key_hash.key?('public_key')
      key.expiration_date key_hash['expiration_date'] if key_hash.key?('expiration_date')
      key
    end

    def self.from_json(json)
      Chef::Key.from_hash(Chef::JSONCompat.from_json(json))
    end

    class <<self
      alias_method :json_create, :from_json
    end

    def self.list_by_user(actor, inflate=false)
      keys = Chef::REST.new(Chef::Config[:chef_server_root]).get_rest("users/#{actor}/keys")
      self.list(keys, actor, :load_by_user, inflate)
    end

    def self.list_by_client(actor, inflate=false)
      keys = Chef::REST.new(Chef::Config[:chef_server_url]).get_rest("clients/#{actor}/keys")
      self.list(keys, actor, :load_by_client, inflate)
    end

    def self.load_by_user(actor, key_name)
      response = Chef::REST.new(Chef::Config[:chef_server_root]).get_rest("users/#{actor}/keys/#{key_name}")
      Chef::Key.from_hash(response)
    end

    def self.load_by_client(actor, key_name)
      response = Chef::REST.new(Chef::Config[:chef_server_url]).get_rest("clients/#{actor}/keys/#{key_name}")
      Chef::Key.from_hash(response)
    end

    private

    def self.list(keys, actor, load_method_symbol, inflate)
      if inflate
        keys.inject({}) do |key_map, result|
          name = result["name"]
          key_map[name] = Chef::Key.send(load_method_symbol, actor, name)
          key_map
        end
      else
        keys
      end
    end
  end
end
