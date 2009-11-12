require File.join(File.dirname(__FILE__), '..', '..', 'spec', 'spec_helper')
require 'audit_formatter'
require 'right_link_log'
require 'auditor_proxy'

describe RightScale::AuditorProxy do

  before(:each) do
    @proxy = RightScale::AuditorProxy.new(1)
    @instance = flexmock('instance')
    flexmock(Nanite::MapperProxy).should_receive(:instance).and_return(@instance)
  end

  it 'should log and audit errors' do
    flexmock(RightScale::RightLinkLog).should_receive(:error).once.with("AUDIT *ERROR> ERROR")
    @instance.should_receive(:push).once.and_return { |*_| EM.stop }
    EM.run { @proxy.append_error('ERROR') }
  end

  it 'should log statuses' do
    flexmock(RightScale::RightLinkLog).should_receive(:info).once.with("AUDIT *RS> STATUS")
    @instance.should_receive(:push).once.and_return { |*_| EM.stop }
    EM.run { @proxy.update_status('STATUS') }
  end

it 'should log outputs' do
    flexmock(RightScale::RightLinkLog).should_receive(:info).once.with("AUDIT OUTPUT").and_return { |*_| EM.stop }
    @instance.should_receive(:push).once
    EM.run do
      EM.add_timer(RightScale::AuditorProxy::MAX_AUDIT_DELAY + 1) { EM.stop }
      @proxy.append_output('OUTPUT')
    end
  end

  it 'should log sections' do
    flexmock(RightScale::RightLinkLog).should_receive(:info).once.with("AUDIT #{ '****' * 20 }\n*RS>#{ 'SECTION'.center(72) }****")
    @instance.should_receive(:push).once.and_return { |*_| EM.stop }
    EM.run { @proxy.create_new_section('SECTION') }
  end

  it 'should log information' do
    flexmock(RightScale::RightLinkLog).should_receive(:info).once.with("AUDIT *RS> INFO")
    @instance.should_receive(:push).once.and_return { |*_| EM.stop }
    EM.run { @proxy.append_info('INFO') }
  end

end
