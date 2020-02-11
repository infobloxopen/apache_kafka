# encoding: UTF-8
# Cookbook Name:: apache_kafka
# Recipe:: service
#
# based on the work by Simple Finance Technology Corp.
# https://github.com/SimpleFinance/chef-zookeeper/blob/master/recipes/service.rb
#
# Copyright 2013, Simple Finance Technology Corp.
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

version_tag = "kafka_#{node['apache_kafka']['scala_version']}-#{node['apache_kafka']['version']}"

vars = {
    :kafka_home => ::File.join(node["apache_kafka"]["install_dir"], version_tag),
    :kafka_config => node["apache_kafka"]["config_dir"],
    :kafka_bin => node["apache_kafka"]["bin_dir"],
    :kafka_user => node["apache_kafka"]["user"],
    :scala_version => node["apache_kafka"]["scala_version"],
    :kafka_heap_opts => node["apache_kafka"]["kafka_heap_opts"],
    :kafka_jvm_performance_opts => node["apache_kafka"]["kafka_jvm_performance_opts"],
    :kafka_opts => node["apache_kafka"]["kafka_opts"],
    :jmx_port => node["apache_kafka"]["jmx"]["port"],
    :jmx_opts => node["apache_kafka"]["jmx"]["opts"],
    :kafka_log_dir => node["apache_kafka"]["log_dir"],
    :kafka_nfiles => node["apache_kafka"]["nfiles"],
}

template "/etc/default/kafka" do
  source "kafka_env.erb"
  owner "kafka"
  action :create
  mode "0644"
  variables vars
  notifies :restart, "service[kafka]", :delayed
end

%w{kafka-server-service.sh}.each do |bin|
  template ::File.join(node["apache_kafka"]["bin_dir"], bin) do
    source "bin/#{bin}.erb"
    owner "kafka"
    action :create
    mode "0755"
    variables vars
    notifies :restart, "service[kafka]", :delayed
  end
end


case node["apache_kafka"]["service_style"]
when "upstart"
  template "/etc/init/kafka.conf" do
    source "kafka.init.erb"
    owner "root"
    group "root"
    action :create
    mode "0644"
    variables(
      :kafka_umask => sprintf("%#03o", node["apache_kafka"]["umask"])
    )
    notifies :restart, "service[kafka]", :delayed
  end
  service "kafka" do
    provider Chef::Provider::Service::Upstart
    supports :status => true, :restart => true, :reload => true
    action [:start, :enable]
  end
when "init.d"
  template "/etc/init.d/kafka" do
    source "kafka.initd.erb"
    owner "root"
    group "root"
    action :create
    mode "0744"
    notifies :restart, "service[kafka]", :delayed
  end
  service "kafka" do
    provider Chef::Provider::Service::Init
    supports :status => true, :restart => true, :reload => true
    action [:start]
  end
when "runit"
  include_recipe "runit"

  runit_service "kafka" do
    default_logger true
    action [:enable, :start]
  end
when "systemd"
  src_fn = '/lib/systemd/system/kafka.service'
  template "#{src_fn}" do
    source "kafka_service.erb"
    variables vars
    owner "root"
    group "root"
    mode "0755"
    notifies :restart, "service[kafka]", :delayed
  end
  execute 'systemctl-daemon-reload' do
    command '/bin/systemctl --system daemon-reload'
    subscribes :run, "template[#{src_fn}]"
    action :nothing
  end
  service 'kafka' do
    supports :status => true, :restart => true
    action [:enable, :start]
  end
else
  Chef::Log.error("You specified an invalid service style for Kafka, but I am continuing.")
end
