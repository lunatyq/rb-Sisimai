module Sisimai
  class Data
    # Sisimai::Data::JSON dumps parsed data object as a JSON format. This class
    # and method should be called from the parent object "Sisimai::Data".
    module JSON
      # Imported from p5-Sisimail/lib/Sisimai/Data/JSON.pm
      class << self
        require 'json'

        # Data dumper(JSON)
        # @param    [Sisimai::Data] argvs   Object
        # @return   [String, Nil]           Dumped data or Undef if the argument
        #                                   is missing
        def dump(argvs)
          return nil unless argvs
          return nil unless argvs.is_a? Sisimai::Data

          damneddata = argvs.damn
          jsonstring = nil

          begin
            jsonstring = ::JSON.generate(damneddata)
          rescue
            warn '***warning: Failed to JSON.generate' + damneddata
          end

          return jsonstring
        end

      end
    end
  end
end
