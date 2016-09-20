module Parser
  module Transport
    class Local < Parser::Transport::Base
      def dir(mask)
        Dir[mask]
      end
      def file
        File
      end
      def remove(path_to_file)
        File.delete(path_to_file)
      end
    end
  end
end