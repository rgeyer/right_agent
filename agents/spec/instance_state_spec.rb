require File.join(File.dirname(__FILE__), '..', '..', 'spec', 'spec_helper')
require 'instance_state'
require 'right_link_log'

describe RightScale::InstanceState do

  include RightScale::SpecHelpers
 
  before(:all) do
    flexmock(RightScale::RightLinkLog).should_receive(:debug)
    setup_state
  end

  after(:all) do
    cleanup_state
  end

  it 'should initialize' do
    RightScale::InstanceState.value.should == 'booting'
    RightScale::InstanceState.identity.should == @identity
  end 

  it 'should handle image bundling' do
    flexmock(RightScale::RightLinkLog).should_receive(:debug)
    RightScale::InstanceState.init(@identity)
    flexmock(Nanite::MapperProxy.instance).should_receive(:request).
            with('/state_recorder/record', { :state => "operational", :agent_identity => "1" }, Proc).
            and_yield(@results_factory.success_results)
    RightScale::InstanceState.value = 'operational'
    flexmock(Nanite::MapperProxy.instance).should_receive(:request).
            with('/state_recorder/record', { :state => "booting", :agent_identity => "2" }, Proc).
            and_yield(@results_factory.success_results)
    RightScale::InstanceState.init('2')
    RightScale::InstanceState.value.should == 'booting'
  end

  it 'should record script execution' do
    RightScale::InstanceState.past_scripts.should be_empty
    RightScale::InstanceState.record_script_execution('test')
    RightScale::InstanceState.past_scripts.should == [ 'test' ]
  end
end
