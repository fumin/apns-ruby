require 'openssl'
require 'socket'
require 'timeout'

module APNS
class Connection
  attr_accessor :error_handler

  def initialize(pem: ,
                 pass: nil,
                 host: 'gateway.sandbox.push.apple.com',
                 port: 2195,
                 notification_buffer_size: 512_000)
    @notifications = []
    @pem =  pem
    @pass = pass
    @host = host
    @port = port
    @notification_buffer_size = notification_buffer_size

    @sock, @ssl = open_connection
    ObjectSpace.define_finalizer(self, self.class.finalize(@sock, @ssl))
  end
  def self.finalize sock, ssl
    proc {
      ssl.close
      sock.close
    }
  end

  def write ns
    if @notifications.size > @notification_buffer_size
      ns = detect_failed_notifications(timeout: 0.5) + ns
      @notifications = []
    end

    packed = pack_notifications(ns)
    @ssl.write(packed)
  rescue Errno::EPIPE, Errno::ECONNRESET, OpenSSL::SSL::SSLError
    failed_notifications = detect_failed_notifications timeout: 3
    @notifications = []
    @ssl.close
    @sock.close
    @sock, @ssl = open_connection

    ns = failed_notifications
    retry
  end

  def pack_notifications notifications
    bytes = ''

    notifications.each do |n|
      n.message_identifier = [@notifications.size].pack('N')
      @notifications << n

      # Each notification frame consists of
      # 1. (e.g. protocol version) 2 (unsigned char [1 byte]) 
      # 2. size of the full frame (unsigend int [4 byte], big endian)
      pn = n.packaged_notification
      bytes << ([2, pn.bytesize].pack('CN') + pn)
    end

    bytes
  end

  def detect_failed_notifications(timeout:)
    begin
      tuple = Timeout::timeout(timeout){ @ssl.read(6) }
      _, code, failed_id = tuple.unpack("ccN")
    rescue Timeout::Error
    end
    failed_id ||= @notifications.size

    # Report error to user
    failed_notification = @notifications[failed_id]
    if @error_handler && failed_notification
      @error_handler.call(code, failed_notification)
    end

    @notifications[failed_id+1..-1] || []
  end

  def open_connection
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(@pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(@pem), @pass)

    sock         = TCPSocket.new(@host, @port)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock,context)
    ssl.connect

    return sock, ssl
  end

  # Override inspect since we do not want to print out the entire @notifications,
  # whose size might be over a hundred thousand
  def inspect
    puts "#<#{self.class}:#{'0x%014x' % object_id} @pem=#{@pem} @pass=#{@pass} @host=#{@host} @port=#{@port} @notifications.size=#{@notifications.size} @error_handler=#{@error_handler}>"
  end

end
end
