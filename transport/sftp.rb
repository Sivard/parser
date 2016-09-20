module Parser
  module Transport
    class Sftp < Parser::Transport::Base
      def initialize(session)
        @session = session
      end
      def dir(mask)
        @session.dir['.', mask]
      end
      def file
        @session.file
      end
      def remove(path_to_file)
        @session.remove!(path_to_file)
      end
    end
  end
end
