#
# Cookbook Name:: kibana
# Recipe:: default
#
# Copyright 2013, John E. Vincent
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

include_recipe "git"

unless Chef::Config[:solo]
  es_server_results = search(:node, "roles:#{node['kibana']['es_role']} AND chef_environment:#{node.chef_environment}")
  unless es_server_results.empty?
    node.set['kibana']['es_server'] = es_server_results[0]['ipaddress']
  end
end

if node['kibana']['user'].empty?
  webserver = node['kibana']['webserver']
  kibana_user = "#{node[webserver]['user']}"
else
  kibana_user = node['kibana']['user']
end

directory node['kibana']['installdir'] do
  owner kibana_user
  mode "0755"
end


if node['kibana']['install_from_source']
  git "#{node['kibana']['installdir']}/#{node['kibana']['branch']}" do
    repository node['kibana']['repo']
    reference node['kibana']['branch']
    action :sync
    user kibana_user
  end

  link "#{node['kibana']['installdir']}/current" do
    to "#{node['kibana']['installdir']}/#{node['kibana']['branch']}/src"
  end

  link "#{node['kibana']['installdir']}/current/app/dashboards/default.json" do
    to "logstash.json"
    only_if { !File::symlink?("#{node['kibana']['installdir']}/current/app/dashboards/default.json") }
  end

  template "#{node['kibana']['installdir']}/current/config.js" do
    source node['kibana']['config_template']
    cookbook node['kibana']['config_cookbook']
    mode "0750"
    user kibana_user
  end

else
  # download kibana latest
  tar_gz = "#{node['kibana']['installdir']}/kibana.tar.gz"
  kibana_latest = "#{node['kibana']['installdir']}/kibana-latest"

  remote_file tar_gz do
    owner kibana_user
    group kibana_user
    source node['kibana']['remote_file']
  end

  execute "extract #{tar_gz}" do
    command "tar xzf #{tar_gz}"
    creates kibana_latest
    cwd node['kibana']['installdir']
    action :run
  end

  link "#{node['kibana']['installdir']}/current" do
    to kibana_latest
    owner kibana_user
    group kibana_user
  end

  execute "remove #{tar_gz}" do
    command "rm #{tar_gz}"
    action :run
    only_if { File.exists?(tar_gz) }
  end

end



include_recipe "kibana::#{node['kibana']['webserver']}"
