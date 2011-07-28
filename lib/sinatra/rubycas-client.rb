require 'sinatra/base'

#TODO: comment
module Sinatra
  module CAS
    module Client
      module Helpers
        def authenticated?
          if session[:cas_username]
            puts "User is already identified as #{session[:cas_username]}" if options.console_debugging
            return true
          end

          puts "Running CAS filter for request #{request.fullpath}..." if options.console_debugging
          client = CASClient::Client.new(
            cas_base_url:           options.cas_base_url,
            force_ssl_verification: options.verify_ssl
          )
          ticket = params[:ticket]

          cas_login_url = client.add_service_to_login_url(options.service_url)

          if ticket
            if ticket =~ /^PT-/
              st = CASClient::ProxyTicket.new(ticket, options.service_url, false)
              puts "User has a ticket (proxy ticket)! #{st.inspect}" if options.console_debugging
            else
              st = CASClient::ServiceTicket.new(ticket, options.service_url, false)
              puts "User has a ticket (service ticket)! #{st.inspect}" if options.console_debugging
            end

            client.validate_service_ticket(st) unless st.has_been_validated?

            if st.is_valid?
              puts 'ticket is valid' if options.console_debugging if options.console_debugging
              session[:cas_username] = st.response.user
              puts "user logged as #{session[:cas_username]}" if options.console_debugging
              redirect options.service_url
            else
              puts 'ticket is not valid' if options.console_debugging
              session[:cas_username] = nil
              redirect cas_login_url
            end
          else
            puts 'No ticket, redirecting to loging server' if options.console_debugging
            session[:cas_username]
            redirect cas_login_url
          end
        end
      end

      def self.registered(app)
        app.helpers CAS::Client::Helpers

        #TODO: setup defaults options
        app.set :cas_base_url, 'https://localhost:9494'
        app.set :service_url, 'http://localhost:3000'
        app.set :verify_ssl, false
        app.set :console_debugging, false

        app.enable :sessions
      end
    end
  end

  register CAS::Client
end
