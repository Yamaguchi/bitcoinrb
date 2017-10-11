module Bitcoin
  module Network

    # remote peer class.
    class Peer

      attr_reader :logger
      # remote peer info
      attr_reader :host
      attr_reader :port
      # remote peer connection
      attr_accessor :conn
      attr_accessor :connected
      attr_accessor :primary
      # parent pool
      attr_reader :pool
      attr_reader :chain
      attr_accessor :fee_rate

      def initialize(host, port, pool)
        @host = host
        @port = port
        @pool = pool
        @chain = pool.chain
        @connected = false
        @primary = false
        @logger = Bitcoin::Logger.create(:debug)
      end

      def connect
        self.conn ||= EM.connect(host, port, Bitcoin::Network::Connection, self)
      end

      def connected?
        @connected
      end

      def addr
        "#{host}:#{port}"
      end

      def post_handshake
        @connected = true
        pool.handle_new_peer(self)
        # require remote peer to use headers message instead fo inv message.
        conn.send_message(Bitcoin::Message::SendHeaders.new)
      end

      # start block header download
      def start_block_header_download
        logger.debug "[#{addr}] start block header download."
        get_headers = Bitcoin::Message::GetHeaders.new(
            Bitcoin.chain_params.protocol_version, [chain.latest_block_header.hash])
        conn.send_message(get_headers)
      end

      # broadcast tx.
      def broadcast_tx(tx)
        conn.send_message(Bitcoin::Message::Tx.new(tx, support_segwit?))
      end

      # check the remote peer support segwit.
      def support_segwit?
        return false unless version_msg
        version_msg.services & Bitcoin::Message::SERVICE_FLAGS[:witness] > 0
      end

      # get remote peer's version message.
      # @return [Bitcoin::Message::Version]
      def version_msg
        conn.version
      end

      # Whether to try and download blocks and transactions from this peer.
      def primary?
        primary
      end

      # handle headers message
      # @params [Bitcoin::Message::Headers]
      def handle_headers(headers)
        headers.headers.each do |header|
          break unless header.valid?
          chain.add_block_header(header)
        end
        start_block_header_download # next header download
      end

    end

  end
end