module Sisimai::Bite::Email
  module KDDI
    # Sisimai::Bite::Email::KDDI parses a bounce email which created by au by KDDI.
    # Methods in the module are called from only Sisimai::Message.
    class << self
      # Imported from p5-Sisimail/lib/Sisimai/Bite/Email/KDDI.pm
      require 'sisimai/bite/email'

      Re0 = {
        :'from'       => %r/no-reply[@].+[.]dion[.]ne[.]jp/,
        :'reply-to'   => %r/\Afrom[ \t]+\w+[.]auone[-]net[.]jp[ \t]/,
        :'received'   => %r/\Afrom[ ](?:.+[.])?ezweb[.]ne[.]jp[ ]/,
        :'message-id' => %r/[@].+[.]ezweb[.]ne[.]jp[>]\z/,
      }
      Re1 = {
        :begin => %r/\AYour[ ]mail[ ](?:
             sent[ ]on:?[ ][A-Z][a-z]{2}[,]
            |attempted[ ]to[ ]be[ ]delivered[ ]on:?[ ][A-Z][a-z]{2}[,]
            )
        /x,
        :rfc822 => %r|\AContent-Type: message/rfc822\z|,
        :error  => %r/Could not be delivered to:? /,
        :endof  => %r/\A__END_OF_EMAIL_MESSAGE__\z/,
      }
      ReFailure = {
        mailboxfull: %r/As[ ]their[ ]mailbox[ ]is[ ]full/x,
        norelaying:  %r/Due[ ]to[ ]the[ ]following[ ]SMTP[ ]relay[ ]error/x,
        hostunknown: %r/As[ ]the[ ]remote[ ]domain[ ]doesnt[ ]exist/x,
      }
      Indicators = Sisimai::Bite::Email.INDICATORS

      def description; return 'au by KDDI: http://www.au.kddi.com'; end
      def smtpagent;   return Sisimai::Bite.smtpagent(self); end
      def headerlist;  return []; end
      def pattern;     return Re0; end

      # Parse bounce messages from au by KDDI
      # @param         [Hash] mhead       Message headers of a bounce email
      # @options mhead [String] from      From header
      # @options mhead [String] date      Date header
      # @options mhead [String] subject   Subject header
      # @options mhead [Array]  received  Received headers
      # @options mhead [String] others    Other required headers
      # @param         [String] mbody     Message body of a bounce email
      # @return        [Hash, Nil]        Bounce data list and message/rfc822
      #                                   part or nil if it failed to parse or
      #                                   the arguments are missing
      def scan(mhead, mbody)
        return nil unless mhead
        return nil unless mbody

        match  = 0
        match += 1 if mhead['from']    =~ Re0[:from]
        match += 1 if mhead['reply-to'] && mhead['reply-to'] =~ Re0[:'reply-to']
        match += 1 if mhead['received'].find { |a| a =~ Re0[:received] }
        return nil if match.zero?

        require 'sisimai/string'
        require 'sisimai/address'

        dscontents = [Sisimai::Bite.DELIVERYSTATUS]
        hasdivided = mbody.split("\n")
        rfc822list = []     # (Array) Each line in message/rfc822 part string
        blanklines = 0      # (Integer) The number of blank lines
        readcursor = 0      # (Integer) Points the current cursor position
        recipients = 0      # (Integer) The number of 'Final-Recipient' header
        v = nil

        hasdivided.each do |e|
          if readcursor.zero?
            # Beginning of the bounce message or delivery status part
            if e =~ Re1[:begin]
              readcursor |= Indicators[:deliverystatus]
              next
            end
          end

          if readcursor & Indicators[:'message-rfc822'] == 0
            # Beginning of the original message part
            if e =~ Re1[:rfc822]
              readcursor |= Indicators[:'message-rfc822']
              next
            end
          end

          if readcursor & Indicators[:'message-rfc822'] > 0
            # After "message/rfc822"
            if e.empty?
              blanklines += 1
              break if blanklines > 1
              next
            end
            rfc822list << e

          else
            # Before "message/rfc822"
            next if readcursor & Indicators[:deliverystatus] == 0
            next if e.empty?

            v = dscontents[-1]
            if cv = e.match(/\A[ \t]+Could not be delivered to: [<]([^ ]+[@][^ ]+)[>]/)
              # Your mail sent on: Thu, 29 Apr 2010 11:04:47 +0900
              #     Could not be delivered to: <******@**.***.**>
              #     As their mailbox is full.
              if v['recipient']
                # There are multiple recipient addresses in the message body.
                push dscontents << Sisimai::Bite.DELIVERYSTATUS
                v = dscontents[-1]
              end

              r = Sisimai::Address.s3s4(cv[1])
              if Sisimai::RFC5322.is_emailaddress(r)
                v['recipient'] = r
                recipients += 1
              end

            elsif cv = e.match(/Your mail sent on: (.+)\z/)
              # Your mail sent on: Thu, 29 Apr 2010 11:04:47 +0900
              v['date'] = cv[1]

            else
              #     As their mailbox is full.
              v['diagnosis'] ||= ''
              v['diagnosis']  += e + ' ' if e =~ /\A[ \t]+/
            end
          end
        end

        return nil if recipients.zero?
        require 'sisimai/smtp/status'

        dscontents.map do |e|
          e['agent']     = self.smtpagent
          e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'])

          if mhead['x-spasign'] && mhead['x-spasign'] == 'NG'
            # Content-Type: text/plain; ..., X-SPASIGN: NG (spamghetti, au by KDDI)
            # Filtered recipient returns message that include 'X-SPASIGN' header
            e['reason'] = 'filtered'

          else
            if e['command'] == 'RCPT'
              # set "userunknown" when the remote server rejected after RCPT
              # command.
              e['reason'] = 'userunknown'
            else
              # SMTP command is not RCPT
              ReFailure.each_key do |r|
                # Verify each regular expression of session errors
                next unless e['diagnosis'] =~ ReFailure[r]
                e['reason'] = r.to_s
                break
              end
            end
          end

        end

        rfc822part = Sisimai::RFC5322.weedout(rfc822list)
        return { 'ds' => dscontents, 'rfc822' => rfc822part }
      end

    end
  end
end

