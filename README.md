apns-ruby
-----
This gem sends APNS notifications with proper error handling. Most importantly, it does this without all the nonsense other gems provide:
* Storing notifications in a database, and have a separate process consume them. Worse, only a single consumer is ever allowed.
* Opening a new SSL connection for every notification, which typically takes several hundred milliseconds. Imagine how long it would take to send a million notifications.

Beware though, that this gem has it's own nonsense in that by default, it sets the notification buffer size to 1 million, which could potentially take up 256MB of memory, given that Apple caps the size of a single notification's payload at 256 bytes. If you cannot afford to spare that amount of memory, configure it to a lesser number `conn = APNS::Connection.new(notification_buffer_size: 1024) # 1024 bytes`.

Example usage:
```
pem = path_to_your_pem_file
host = 'gateway.sandbox.push.apple.com' # or 'gateway.push.apple.com' on production
token = a_valid_apns_device_token
conn = APNS::Connection.new(pem: pem, host: host)
conn.error_handler = ->(code, notification) {
  case code
  when 8
    puts "Invalid token: #{notification.device_token}"
  else
    # Consult Apple's docs
  end
}
n1 = APNS::Notification.new(token, alert: 'hello')
ne = APNS::Notification.new('bogustoken', alert: 'error')
n2 = APNS::Notification.new(token, alert: 'world')
conn.write([n1, ne, n2])
# Should receive only a 'hello' notification on your device

# Wait for Apple to report an error and close the connection
sleep(7)
conn.write([APNS::Notification.new(token, alert: 'hello world 0')])
sleep(7)
conn.write([APNS::Notification.new(token, alert: 'hello world 1')])

# 'Invalid token: bogustoken' is printed out
# We should be receiving the 'world', 'hello world 0', and 'hello world 1' notifications
```

A great amount of code in this gem is copied from https://github.com/jpoz/APNS , many thanks to his pioneering work. This work itself is licensed under the MIT license.
