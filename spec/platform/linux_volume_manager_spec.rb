#
# Copyright (c) 2009-2011 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
# Override the current environment, and load the linux platform
load File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'right_agent', 'platform', 'linux.rb'))


describe RightScale::Platform do
  before(:all) do
    @platform = RightScale::Platform
  end

  context :volume_manager do
    context :parse_volumes do
      it 'can parse volumes from blkid output' do
        blkid_resp = <<EOF
/dev/xvdh1: SEC_TYPE="msdos" LABEL="METADATA" UUID="681B-8C5D" TYPE="vfat"
/dev/xvdb1: LABEL="SWAP-xvdb1" UUID="d51fcca0-6b10-4934-a572-f3898dfd8840" TYPE="swap"
/dev/xvda1: UUID="f4746f9c-0557-4406-9267-5e918e87ca2e" TYPE="ext3"
/dev/xvda2: UUID="14d88b9e-9fe6-4974-a8d6-180acdae4016" TYPE="ext3"
EOF
        volume_hash_ary = [
          {:device => "/dev/xvdh1", :sec_type => "msdos", :label => "METADATA", :uuid => "681B-8C5D", :type => "vfat", :filesystem => "vfat"},
          {:device => "/dev/xvdb1", :label => "SWAP-xvdb1", :uuid => "d51fcca0-6b10-4934-a572-f3898dfd8840", :type => "swap", :filesystem => "swap"},
          {:device => "/dev/xvda1", :uuid => "f4746f9c-0557-4406-9267-5e918e87ca2e", :type => "ext3", :filesystem => "ext3"},
          {:device => "/dev/xvda2", :uuid => "14d88b9e-9fe6-4974-a8d6-180acdae4016", :type => "ext3", :filesystem => "ext3"}
        ]

        @platform.volume_manager.parse_volumes(blkid_resp).should == volume_hash_ary
      end

      it 'raises a parser error when blkid output is malformed' do
        blkid_resp = 'foobarbz'

        lambda { @platform.volume_manager.parse_volumes(blkid_resp) }.should raise_error(RightScale::Platform::VolumeManager::ParserError)
      end

      it 'returns an empty list of volumes when blkid output is empty' do
        blkid_resp = ''

        @platform.volume_manager.parse_volumes(blkid_resp).should == []
      end
    end

    context :mount_volume do
      it 'raises argument error when the volume parameter is not a hash' do
        lambda { @platform.volume_manager.mount_volume("", "") }.should raise_error(ArgumentError)
      end

      it 'raises argument error when the volume parameter is a hash but does not contain :device' do
        lambda { @platform.volume_manager.mount_volume({}, "") }.should raise_error(ArgumentError)
      end

    end
  end
end