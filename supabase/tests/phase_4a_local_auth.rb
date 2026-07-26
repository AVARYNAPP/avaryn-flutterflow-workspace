require 'base64'
require 'cgi'
require 'json'
require 'net/http'
require 'securerandom'
require 'uri'

status_file = ARGV.fetch(0)
env = File.readlines(status_file, chomp: true).each_with_object({}) do |line, values|
  next unless line.include?('=')

  key, value = line.split('=', 2)
  values[key] = value.to_s.sub(/\A"/, '').sub(/"\z/, '')
end

api_url = env.fetch('API_URL')
mailpit_url = env.fetch('MAILPIT_URL')
api_key = env['ANON_KEY'].to_s.empty? ? env.fetch('PUBLISHABLE_KEY') : env['ANON_KEY']
service_key =
  env['SERVICE_ROLE_KEY'].to_s.empty? ? env.fetch('SECRET_KEY') : env['SERVICE_ROLE_KEY']

def request(method, url, headers: {}, json: nil, body: nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  klass = {
    get: Net::HTTP::Get,
    post: Net::HTTP::Post,
    patch: Net::HTTP::Patch,
    delete: Net::HTTP::Delete,
  }.fetch(method)
  req = klass.new(uri)
  headers.each { |key, value| req[key] = value }
  if json
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(json)
  elsif body
    req.body = body
  end
  http.request(req)
end

def json_body(response)
  JSON.parse(response.body.to_s.empty? ? '{}' : response.body)
end

def assert!(condition, message)
  raise message unless condition
end

def pass(label)
  puts "PASS: #{label}"
end

def wait_for_message(mailpit_url, email, excluded_ids: [])
  40.times do
    list = json_body(request(:get, "#{mailpit_url}/api/v1/messages"))
    match = Array(list['messages']).find do |message|
      recipients = Array(message['To']).map { |recipient| recipient['Address'].to_s.downcase }
      recipients.include?(email.downcase) && !excluded_ids.include?(message['ID'])
    end
    return match if match

    sleep 0.5
  end
  raise "No Mailpit message arrived for #{email}"
end

def message_link(mailpit_url, message, expected_type)
  detail = json_body(
    request(:get, "#{mailpit_url}/api/v1/message/#{CGI.escape(message.fetch('ID'))}"),
  )
  content = [detail['Text'], detail['HTML']].compact.join("\n")
  links = content.scan(%r{http://127\.0\.0\.1:54321/auth/v1/verify\?[^"'<>\s]+})
  decoded = links.map { |link| CGI.unescapeHTML(link) }
  decoded.find { |link| link.include?("type=#{expected_type}") } ||
    raise("No #{expected_type} verification link in Mailpit message")
end

def register_and_confirm(api_url, mailpit_url, api_key, email, password)
  redirect = 'http://127.0.0.1:3000/auth/callback'
  response = request(
    :post,
    "#{api_url}/auth/v1/signup?redirect_to=#{CGI.escape(redirect)}",
    headers: { 'apikey' => api_key },
    json: { email: email, password: password },
  )
  assert!(response.code.to_i == 200, "Signup failed with HTTP #{response.code}")
  signup = json_body(response)
  # GoTrue versions differ here: some wrap the user in `user`, while others
  # return the user object directly when confirmation is required.
  signup_user = signup['user'].is_a?(Hash) ? signup['user'] : signup
  assert!(!signup_user['id'].to_s.empty?, 'Signup returned no user UUID')
  assert!(signup['access_token'].to_s.empty?, 'Unconfirmed signup unexpectedly returned a session')

  message = wait_for_message(mailpit_url, email)
  link = message_link(mailpit_url, message, 'signup')
  confirm = request(:get, link, headers: { 'apikey' => api_key })
  assert!([302, 303].include?(confirm.code.to_i), "Email confirmation returned HTTP #{confirm.code}")
  assert!(
    confirm['location'].to_s.start_with?(redirect),
    'Email confirmation did not return to the exact callback route',
  )
  [signup_user.fetch('id'), message.fetch('ID')]
end

def password_session(api_url, api_key, email, password)
  response = request(
    :post,
    "#{api_url}/auth/v1/token?grant_type=password",
    headers: { 'apikey' => api_key },
    json: { email: email, password: password },
  )
  assert!(response.code.to_i == 200, "Password login failed with HTTP #{response.code}")
  session = json_body(response)
  assert!(!session['access_token'].to_s.empty?, 'Login returned no access token')
  assert!(!session['refresh_token'].to_s.empty?, 'Login returned no refresh token')
  session
end

suffix = "#{Time.now.to_i}-#{SecureRandom.hex(3)}"
email_a = "phase4a-a-#{suffix}@example.test"
email_b = "phase4a-b-#{suffix}@example.test"
password = 'LocalOnly4A1'

user_a, signup_message_a = register_and_confirm(
  api_url,
  mailpit_url,
  api_key,
  email_a,
  password,
)
pass('account registration A requires and accepts the real local confirmation email')

user_b, = register_and_confirm(api_url, mailpit_url, api_key, email_b, password)
pass('account registration B creates a separate confirmed auth UUID')

session_a = password_session(api_url, api_key, email_a, password)
pass('confirmed account can sign in with email and password')

auth_headers_a = {
  'apikey' => api_key,
  'Authorization' => "Bearer #{session_a.fetch('access_token')}",
}

own = request(
  :get,
  "#{api_url}/rest/v1/profiles?id=eq.#{user_a}&select=id,display_name",
  headers: auth_headers_a,
)
assert!(own.code.to_i == 200, "Own profile read returned HTTP #{own.code}")
assert!(json_body(own).length == 1, 'User A could not read exactly one own profile')
pass('user A can read own profile through REST')

own_update = request(
  :patch,
  "#{api_url}/rest/v1/profiles?id=eq.#{user_a}",
  headers: auth_headers_a.merge('Prefer' => 'return=representation'),
  json: { first_name: 'Eigen' },
)
assert!(own_update.code.to_i == 200, "Own profile update returned HTTP #{own_update.code}")
assert!(json_body(own_update).length == 1, 'User A own profile update changed no row')
pass('user A can update own profile through REST')

cross_read = request(
  :get,
  "#{api_url}/rest/v1/profiles?id=eq.#{user_b}&select=id",
  headers: auth_headers_a,
)
assert!(cross_read.code.to_i == 200, "Cross-profile read returned HTTP #{cross_read.code}")
assert!(json_body(cross_read).empty?, 'User A could read profile B')
pass('user A cannot read profile B')

cross_update = request(
  :patch,
  "#{api_url}/rest/v1/profiles?id=eq.#{user_b}",
  headers: auth_headers_a.merge('Prefer' => 'return=representation'),
  json: { first_name: 'Niet toegestaan' },
)
assert!(cross_update.code.to_i == 200, "Cross-profile update returned HTTP #{cross_update.code}")
assert!(json_body(cross_update).empty?, 'User A could update profile B')
pass('user A cannot update profile B')

arbitrary_insert = request(
  :post,
  "#{api_url}/rest/v1/profiles",
  headers: auth_headers_a,
  json: {
    id: '30000000-0000-0000-0000-000000000003',
    display_name: 'Niet toegestaan',
  },
)
assert!(
  [401, 403].include?(arbitrary_insert.code.to_i),
  "Cross-UUID profile insert unexpectedly returned HTTP #{arbitrary_insert.code}",
)
pass('user A cannot insert a profile for an arbitrary auth UUID')

anonymous = request(
  :get,
  "#{api_url}/rest/v1/profiles?select=id",
  headers: { 'apikey' => api_key },
)
assert!(
  [401, 403].include?(anonymous.code.to_i),
  "Anonymous profile read unexpectedly returned HTTP #{anonymous.code}",
)
pass('anonymous caller has no profile access')

duplicate = request(
  :post,
  "#{api_url}/rest/v1/profiles",
  headers: auth_headers_a,
  json: { id: user_a, display_name: 'Dubbel' },
)
assert!(duplicate.code.to_i == 409, "Duplicate profile insert returned HTTP #{duplicate.code}")
pass('profile remains unique per auth UUID')

refresh = request(
  :post,
  "#{api_url}/auth/v1/token?grant_type=refresh_token",
  headers: { 'apikey' => api_key },
  json: { refresh_token: session_a.fetch('refresh_token') },
)
assert!(refresh.code.to_i == 200, "Session refresh returned HTTP #{refresh.code}")
refreshed = json_body(refresh)
assert!(!refreshed['access_token'].to_s.empty?, 'Session refresh returned no access token')
pass('session can be restored with its refresh token')

existing_message_ids = [signup_message_a]
recovery_redirect = 'http://127.0.0.1:3000/auth/reset-password'
recover = request(
  :post,
  "#{api_url}/auth/v1/recover?redirect_to=#{CGI.escape(recovery_redirect)}",
  headers: { 'apikey' => api_key },
  json: { email: email_a },
)
assert!(recover.code.to_i == 200, "Password recovery request returned HTTP #{recover.code}")
recovery_message = wait_for_message(
  mailpit_url,
  email_a,
  excluded_ids: existing_message_ids,
)
recovery_link = message_link(mailpit_url, recovery_message, 'recovery')
recovery_verify = request(:get, recovery_link, headers: { 'apikey' => api_key })
assert!(
  [302, 303].include?(recovery_verify.code.to_i),
  "Recovery verification returned HTTP #{recovery_verify.code}",
)
assert!(
  recovery_verify['location'].to_s.start_with?(recovery_redirect),
  'Recovery email did not return to the exact reset-password route',
)
pass('password recovery email and exact reset callback are valid locally')

png = Base64.decode64(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nWQAAAAASUVORK5CYII=',
)
avatar_path_a = "#{user_a}/avatar.png"
upload_a = request(
  :post,
  "#{api_url}/storage/v1/object/avatars/#{avatar_path_a}",
  headers: auth_headers_a.merge('Content-Type' => 'image/png', 'x-upsert' => 'true'),
  body: png,
)
assert!([200, 201].include?(upload_a.code.to_i), "Own avatar upload returned HTTP #{upload_a.code}")

read_a = request(
  :get,
  "#{api_url}/storage/v1/object/authenticated/avatars/#{avatar_path_a}",
  headers: auth_headers_a,
)
assert!(read_a.code.to_i == 200, "Own avatar read returned HTTP #{read_a.code}")

cross_avatar = request(
  :post,
  "#{api_url}/storage/v1/object/avatars/#{user_b}/avatar.png",
  headers: auth_headers_a.merge('Content-Type' => 'image/png', 'x-upsert' => 'true'),
  body: png,
)
assert!(
  [400, 401, 403].include?(cross_avatar.code.to_i),
  "Cross-user avatar upload unexpectedly returned HTTP #{cross_avatar.code}",
)
pass('avatar storage permits own path and rejects another auth UUID path')

logout_token = refreshed.fetch('access_token')
logout = request(
  :post,
  "#{api_url}/auth/v1/logout",
  headers: {
    'apikey' => api_key,
    'Authorization' => "Bearer #{logout_token}",
  },
)
assert!([200, 204].include?(logout.code.to_i), "Logout returned HTTP #{logout.code}")

reuse_refresh = request(
  :post,
  "#{api_url}/auth/v1/token?grant_type=refresh_token",
  headers: { 'apikey' => api_key },
  json: { refresh_token: refreshed.fetch('refresh_token') },
)
assert!(
  [400, 401].include?(reuse_refresh.code.to_i),
  "Logged-out refresh token unexpectedly returned HTTP #{reuse_refresh.code}",
)
pass('logout revokes the active refresh session')

invalid_callback = request(
  :get,
  "#{api_url}/auth/v1/verify?token=invalid&type=signup&redirect_to=#{CGI.escape('http://127.0.0.1:3000/auth/callback')}",
  headers: { 'apikey' => api_key },
)
invalid_location = invalid_callback['location'].to_s
invalid_redirect = URI(invalid_location)
invalid_params = CGI.parse(
  [invalid_redirect.query, invalid_redirect.fragment].compact.join('&'),
)
assert!([302, 303].include?(invalid_callback.code.to_i), "Invalid callback returned HTTP #{invalid_callback.code}")
assert!(
  invalid_redirect.host == '127.0.0.1' &&
    invalid_redirect.port == 3000 &&
    invalid_redirect.path == '/auth/callback' &&
    invalid_params.key?('error'),
  'Invalid callback did not fail closed on the exact callback route',
)
pass('expired or invalid callback token fails closed')

bucket = request(
  :get,
  "#{api_url}/storage/v1/bucket/avatars",
  headers: {
    'apikey' => service_key,
    'Authorization' => "Bearer #{service_key}",
  },
)
assert!(bucket.code.to_i == 200, "Avatar bucket inspection returned HTTP #{bucket.code}")
bucket_data = json_body(bucket)
assert!(bucket_data['public'] == false, 'Avatar bucket is unexpectedly public')
assert!(bucket_data['file_size_limit'].to_i == 5 * 1024 * 1024, 'Avatar bucket limit is not 5 MiB')
pass('avatar bucket is private with the expected 5 MiB limit')
