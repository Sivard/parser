module Parser
  module Transport
    class Base
      def dir(mask)
        raise "Incorrect usage! See comments in lib/import_data.rb for more info."
      end
      def file
        raise "Incorrect usage! See comments in lib/import_data.rb for more info."
      end
      def remove(path_to_file)
        raise "Incorrect usage! See comments in lib/import_data.rb for more info."
      end
    end
  end
end