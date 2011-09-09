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
#

module RightScale

  class CommandConstants

    # Ports used for command protocol
    BASE_INSTANCE_AGENT_SOCKET_PORT         = 60000
    BASE_INSTANCE_AGENT_CHECKER_SOCKET_PORT = 61000

    BASE_CORE_AGENT_SOCKET_PORT             = 70000
    BASE_LABORER_AGENT_SOCKET_PORT          = 71000
    BASE_REPLICANT_AGENT_SOCKET_PORT        = 72000
    BASE_PROXY_AGENT_SOCKET_PORT            = 73000
    BASE_LIBRARY_AGENT_SOCKET_PORT          = 74000
    BASE_WASABI_AGENT_SOCKET_PORT           = 75000

    BASE_MAPPER_SOCKET_PORT                 = 79000

  end
end