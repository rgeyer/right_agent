#
# Copyright (c) 2009 RightScale Inc
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

module RightScale

  # Helper methods for all agents
  module AgentHelpers
    include RightLinkLogHelpers
    include OperationResultHelpers

    # Retrieve database object
    # Audit and/or log error if given block returns nil or raises, return block result otherwise
    # Store any error message in @last_error
    #
    # === Parameters
    # description(String):: Description of object that is used in error messages
    # audit(AuditEntry):: Audit entry used to append error message if any, default to nil
    # log(Boolean):: Whether to log message when object does not exist, default to false
    #
    # === Block
    # Performs query to retrieve object, required
    #
    # === Return
    # item(Object):: Value returned by block, or nil if not found or failed
    def retrieve(description, audit = nil, log = false)
      begin
        unless item = yield
          @last_error = "Could not find #{description}"
          log_warning(@last_error) if log
        end
      rescue Exception => e
        description = "Failed to retrieve #{description}"
        log_error(description, e, :trace)
        @last_error = format_error(description, e)
        item = nil
      end
      audit.append(AuditFormatter.error(@last_error)) if audit && item.nil? && @last_error
      item
    end

    # Create database object
    # Audit and/or log error if given block returns nil or raises, return block result otherwise
    # Store any error message in @last_error
    #
    # === Parameters
    # description(String):: Description of object that is used in error messages
    # audit(AuditEntry):: Audit entry used to append error message if any, default to nil
    #
    # === Block
    # Creates object and returns it, required
    #
    # === Return
    # (Object):: Value returned by block, or nil if failed
    def create(description, audit = nil)
      begin
        yield
      rescue Exception => e
        description = "Failed to create #{description}"
        log_error(description, e, :trace)
        @last_error = format_error(description, e)
        audit.append(AuditFormatter.error(@last_error)) if audit
        nil
      end
    end

    # Query database using retry on failure and reconnect handling
    # Store any error message in @last_error
    #
    # === Parameters
    # description(String):: Description of query action that is used in error messages
    # audit(AuditEntry):: Audit entry used to append error message if any, default to nil
    # options(Hash):: Hash of additional options, default to empty.  Supported options are:
    #   :include_backtrace_in_last_error - passes the :trace option to format_error if there is an exception
    #   :email_errors
    #
    # === Block
    # Accesses MySQL and returns result, required
    #
    # === Return
    # (Object|nil):: Value returned by block, or nil if failed
    def query(description, audit = nil, options = {}, &blk)
      begin
        ModelsImporter.instance.run_query(&blk)
      rescue Exception => e
        description = "Failed to #{description}"
        log_error(description, e, :trace)
        if options[:include_backtrace_in_last_error]
          @last_error = format_error(description, e, :trace)
        else
          @last_error = format_error(description, e)
        end
        audit.append(AuditFormatter.error(@last_error)) if audit

        if(options[:email_errors])
          RightScale::ExceptionMailer.deliver_notification(description, e.message, e)
        end

        nil
      end
    end

    # Add a one-shot timer to the EM event loop and rescue any exception
    #
    # === Parameters
    # delay(Integer):: Seconds to delay before executing block
    #
    # === Block
    # Code to be executed after the delay; must be provided
    #
    # === Return
    # true:: Always return true
    def add_timer(delay)
      EM.add_timer(delay) do
        begin
          yield
        rescue Exception => e
          log_error("Failed time-delayed task", e, :trace)
        end
      end
      true
    end

  end # AgentHelpers

end # RightScale