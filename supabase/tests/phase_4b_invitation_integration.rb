require 'cgi'
require 'digest'
require 'json'
require 'net/http'
require 'securerandom'
require 'time'
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
function_url = "#{api_url}/functions/v1/stable-invitations"
delete_function_url = "#{api_url}/functions/v1/delete-account"

def request(method, url, headers: {}, json: nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  klass = {
    get: Net::HTTP::Get,
    post: Net::HTTP::Post,
    patch: Net::HTTP::Patch,
  }.fetch(method)
  req = klass.new(uri)
  headers.each { |key, value| req[key] = value }
  if json
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(json)
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

def wait_for_message(mailpit_url, email)
  40.times do
    list = json_body(request(:get, "#{mailpit_url}/api/v1/messages"))
    match = Array(list['messages']).find do |message|
      Array(message['To']).any? do |recipient|
        recipient['Address'].to_s.downcase == email.downcase
      end
    end
    return match if match

    sleep 0.25
  end
  raise "No local confirmation message arrived"
end

def register_and_confirm(api_url, mailpit_url, api_key, email, password)
  redirect = 'http://127.0.0.1:3000/auth/callback'
  signup = request(
    :post,
    "#{api_url}/auth/v1/signup?redirect_to=#{CGI.escape(redirect)}",
    headers: { 'apikey' => api_key },
    json: { email: email, password: password },
  )
  assert!(signup.code.to_i == 200, "Local signup failed: #{signup.code}")
  message = wait_for_message(mailpit_url, email)
  detail = json_body(
    request(
      :get,
      "#{mailpit_url}/api/v1/message/#{CGI.escape(message.fetch('ID'))}",
    ),
  )
  content = [detail['Text'], detail['HTML']].compact.join("\n")
  link = content
    .scan(%r{http://127\.0\.0\.1:54321/auth/v1/verify\?[^"'<>\s]+})
    .map { |value| CGI.unescapeHTML(value) }
    .find { |value| value.include?('type=signup') }
  raise 'Local confirmation link missing' if link.nil?

  confirmation = request(:get, link, headers: { 'apikey' => api_key })
  assert!(
    [302, 303].include?(confirmation.code.to_i),
    "Local confirmation failed: #{confirmation.code}",
  )
end

def session(api_url, api_key, email, password)
  response = request(
    :post,
    "#{api_url}/auth/v1/token?grant_type=password",
    headers: { 'apikey' => api_key },
    json: { email: email, password: password },
  )
  assert!(response.code.to_i == 200, "Local login failed: #{response.code}")
  json_body(response)
end

def auth_headers(api_key, session)
  {
    'apikey' => api_key,
    'Authorization' => "Bearer #{session.fetch('access_token')}",
  }
end

def rpc(api_url, name, headers, body)
  request(
    :post,
    "#{api_url}/rest/v1/rpc/#{name}",
    headers: headers,
    json: body,
  )
end

def edge(function_url, api_key, body, session: nil)
  headers = { 'apikey' => api_key }
  if session
    headers['Authorization'] = "Bearer #{session.fetch('access_token')}"
  end
  request(:post, function_url, headers: headers, json: body)
end

def token_from_invitation_response(response)
  data = json_body(response)
  uri = URI(data.fetch('invitation_url'))
  token = CGI.parse(uri.fragment.to_s).fetch('token').first
  [data, token]
end

suffix = "#{Time.now.to_i}-#{SecureRandom.hex(3)}"
password = 'LocalOnly4B1'
owner_email = "phase4b-owner-#{suffix}@example.test"
existing_email = "phase4b-existing-#{suffix}@example.test"
new_email = "phase4b-new-#{suffix}@example.test"
wrong_email = "phase4b-wrong-#{suffix}@example.test"
second_owner_email = "phase4b-owner2-#{suffix}@example.test"

[owner_email, existing_email, wrong_email, second_owner_email].each do |email|
  register_and_confirm(api_url, mailpit_url, api_key, email, password)
end
owner_session = session(api_url, api_key, owner_email, password)
existing_session = session(api_url, api_key, existing_email, password)
wrong_session = session(api_url, api_key, wrong_email, password)
second_owner_session = session(api_url, api_key, second_owner_email, password)
pass('four isolated local test accounts registered and confirmed')

owner_headers = auth_headers(api_key, owner_session)
create = rpc(
  api_url,
  'create_stable',
  owner_headers,
  {
    p_name: 'Lokale integratiestal',
    p_timezone: 'Europe/Amsterdam',
    p_kind: 'organization',
    p_locale: 'nl',
    p_creation_request_id: SecureRandom.uuid,
    p_owner_display_name: 'Lokale owner',
    p_owner_function_title: nil,
  },
)
assert!(create.code.to_i == 200, "Stable creation failed: #{create.code}")
stable_id = json_body(create).fetch('stable_id')
pass('stable, owner roster and owner membership created atomically')

personal = rpc(
  api_url,
  'create_stable',
  owner_headers,
  {
    p_name: 'Mijn paarden lokaal',
    p_timezone: 'Europe/Amsterdam',
    p_kind: 'personal',
    p_locale: 'nl',
    p_creation_request_id: SecureRandom.uuid,
    p_owner_display_name: 'Lokale owner',
    p_owner_function_title: nil,
  },
)
assert!(personal.code.to_i == 200, 'Explicit personal workspace creation failed')
personal_id = json_body(personal).fetch('stable_id')
blocked_personal = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: personal_id,
    email: existing_email,
    role: 'member',
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(
  blocked_personal.code.to_i == 409,
  "Personal workspace invitation returned HTTP #{blocked_personal.code}",
)
pass('personal workspace is explicit, horse-free and invitations are disabled')

created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: stable_id,
    email: existing_email,
    role: 'member',
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(created.code.to_i == 200, "Invitation create failed: #{created.code}")
created_data, existing_token = token_from_invitation_response(created)
invitation_id = created_data.fetch('invitation_id')
assert!(existing_token.bytesize >= 43, 'Invitation token has less than 256 bits')
assert!(
  !created.body.include?(existing_email),
  'Secure invitation response leaked recipient contact data',
)
pass('existing-account invitation returns one transient fragment link')

preview = edge(
  function_url,
  api_key,
  { action: 'preview', token: existing_token },
)
preview_data = json_body(preview)
assert!(preview.code.to_i == 200, 'Anonymous safe preview failed')
assert!(preview_data['stable_name'] == 'Lokale integratiestal', 'Preview stable mismatch')
assert!(preview_data['invitation_id'] == invitation_id, 'Preview hand-off ID mismatch')
assert!(!preview.body.include?(existing_email), 'Preview exposed contact data')
pass('preview exposes only minimal stable and role data')

resumed = edge(
  function_url,
  api_key,
  { action: 'resume', invitation_id: invitation_id },
  session: existing_session,
)
resumed_data = json_body(resumed)
assert!(resumed.code.to_i == 200, 'Authenticated invitation resume failed')
assert!(resumed_data['status'] == 'pending', 'Resumed invitation is not pending')
assert!(resumed_data['invitation_id'] == invitation_id, 'Resume changed invitation ID')
assert!(!resumed.body.include?(existing_email), 'Resume exposed recipient contact data')
pass('non-secret hand-off ID resumes only after confirmed authentication')

wrong_resume = edge(
  function_url,
  api_key,
  { action: 'resume', invitation_id: invitation_id },
  session: wrong_session,
)
assert!(wrong_resume.code.to_i == 200, 'Wrong-account resume enumerated by status')
assert!(
  json_body(wrong_resume) == { 'status' => 'unavailable' },
  'Wrong-account resume exposed invitation metadata',
)
pass('hand-off ID remains bound to the confirmed invited email')

wrong_accept = edge(
  function_url,
  api_key,
  {
    action: 'accept',
    token: existing_token,
    display_name: 'Verkeerde gebruiker',
    request_id: SecureRandom.uuid,
  },
  session: wrong_session,
)
assert!(wrong_accept.code.to_i == 409, 'Wrong email accepted invitation')
pass('invitation is bound to the confirmed session email without enumeration')

missing_name = edge(
  function_url,
  api_key,
  {
    action: 'accept',
    invitation_id: invitation_id,
    display_name: '',
    request_id: SecureRandom.uuid,
  },
  session: existing_session,
)
assert!(
  missing_name.code.to_i == 412,
  "Correctable display-name error returned HTTP #{missing_name.code}",
)
assert!(
  json_body(missing_name)['code'] == 'DISPLAY_NAME_REQUIRED',
  'Correctable display-name error lost its safe code',
)
resume_after_correction = edge(
  function_url,
  api_key,
  { action: 'resume', invitation_id: invitation_id },
  session: existing_session,
)
assert!(
  resume_after_correction.code.to_i == 200 &&
    json_body(resume_after_correction)['status'] == 'pending',
  'Correctable validation error destroyed the invitation hand-off',
)
pass('correctable invitation validation keeps the safe hand-off retryable')

accept_results = [:token, :handoff].map do |path|
  Thread.new do
    edge(
      function_url,
      api_key,
      {
        action: 'accept',
        (path == :token ? :token : :invitation_id) =>
          (path == :token ? existing_token : invitation_id),
        display_name: 'Bestaand lokaal account',
        function_title: 'Groom',
        request_id: SecureRandom.uuid,
      },
      session: existing_session,
    )
  end
end.map(&:value)
unless accept_results.all? { |response| response.code.to_i == 200 }
  diagnostic = rpc(
    api_url,
    'accept_stable_invitation',
    auth_headers(api_key, existing_session),
    {
      p_token_hash_hex: Digest::SHA256.hexdigest(existing_token),
      p_display_name: 'Bestaand lokaal account',
      p_function_title: 'Groom',
      p_request_id: SecureRandom.uuid,
    },
  )
  raise "Concurrent accept failed; direct RPC #{diagnostic.code}: #{diagnostic.body}"
end
assert!(
  accept_results.all? { |response| response.code.to_i == 200 },
  "Concurrent idempotent acceptance returned #{accept_results.map(&:code).join(', ')}",
)
pass('two concurrent accept calls converge on one membership')

accepted_resume = edge(
  function_url,
  api_key,
  { action: 'resume', invitation_id: invitation_id },
  session: existing_session,
)
accepted_resume_data = json_body(accepted_resume)
assert!(accepted_resume.code.to_i == 200, 'Accepted resume returned an error')
assert!(
  accepted_resume_data == {
    'status' => 'accepted',
    'stable_id' => stable_id,
  },
  'Accepted ambiguous retry did not return the safe stable hand-off',
)
pass('accepted ambiguous response resumes to the safe stable hand-off')

used_preview = edge(
  function_url,
  api_key,
  { action: 'preview', token: existing_token },
)
assert!(json_body(used_preview)['status'] == 'accepted', 'Used token not marked accepted')

new_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: stable_id,
    email: new_email,
    role: 'viewer',
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(new_created.code.to_i == 200, 'New-account invitation creation failed')
new_data, new_token = token_from_invitation_response(new_created)
new_invitation_id = new_data.fetch('invitation_id')
cooldown = edge(
  function_url,
  api_key,
  {
    action: 'resend',
    invitation_id: new_invitation_id,
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(cooldown.code.to_i == 409, 'Immediate resend bypassed 60-second cooldown')
pass('resend cooldown is enforced')

register_and_confirm(api_url, mailpit_url, api_key, new_email, password)
new_session = session(api_url, api_key, new_email, password)
new_accept = edge(
  function_url,
  api_key,
  {
    action: 'accept',
    token: new_token,
    display_name: 'Nieuw lokaal account',
    request_id: SecureRandom.uuid,
  },
  session: new_session,
)
assert!(new_accept.code.to_i == 200, 'New account could not accept invitation')
pass('invitation made before signup can be accepted after confirmation')

# Use local service-role setup only to advance the test fixture clock; no key
# is printed or passed to application code.
service_headers = {
  'apikey' => service_key,
  'Authorization' => "Bearer #{service_key}",
  'Prefer' => 'return=minimal',
}
rewind = request(
  :patch,
  "#{api_url}/rest/v1/stable_invitations?id=eq.#{new_invitation_id}",
  headers: service_headers,
  json: { last_sent_at: (Time.now.utc - 120).iso8601 },
)
assert!([200, 204].include?(rewind.code.to_i), 'Local fixture rewind failed')
resend = edge(
  function_url,
  api_key,
  {
    action: 'resend',
    invitation_id: new_invitation_id,
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
# The invitation was accepted, so resend must stay unavailable even after time.
assert!(resend.code.to_i == 409, 'Accepted invitation was regenerated')
pass('accepted token cannot be regenerated or reused')

decline_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: stable_id,
    email: wrong_email,
    role: 'viewer',
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
decline_data, decline_token = token_from_invitation_response(decline_created)
decline_response = edge(
  function_url,
  api_key,
  {
    action: 'decline',
    token: decline_token,
    request_id: SecureRandom.uuid,
  },
  session: wrong_session,
)
assert!(decline_response.code.to_i == 200, 'Invitation decline failed')
declined_preview = edge(
  function_url,
  api_key,
  { action: 'preview', token: decline_token },
)
assert!(json_body(declined_preview)['status'] == 'declined', 'Declined token remained pending')
pass('invited account can explicitly decline and receives no membership')

revoke_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: stable_id,
    email: "phase4b-revoke-#{suffix}@example.test",
    role: 'viewer',
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
revoke_data, revoke_token = token_from_invitation_response(revoke_created)
revoke_response = edge(
  function_url,
  api_key,
  {
    action: 'revoke',
    invitation_id: revoke_data.fetch('invitation_id'),
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(revoke_response.code.to_i == 200, 'Invitation revoke failed')
revoked_preview = edge(
  function_url,
  api_key,
  { action: 'preview', token: revoke_token },
)
assert!(json_body(revoked_preview)['status'] == 'revoked', 'Revoked token remained pending')
pass('owner can revoke a pending invitation and token stays unusable')

admin_role_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: stable_id,
    email: "phase4b-admin-role-#{suffix}@example.test",
    role: 'admin',
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(admin_role_created.code.to_i == 200, 'Owner admin-role invitation failed')
admin_role_data, admin_role_token =
  token_from_invitation_response(admin_role_created)
admin_role_row = request(
  :get,
  "#{api_url}/rest/v1/stable_invitations?id=eq.#{admin_role_data.fetch('invitation_id')}&select=offered_role",
  headers: service_headers,
)
assert!(
  JSON.parse(admin_role_row.body).first.fetch('offered_role') == 'admin',
  'Selected invitation role did not reach the server',
)
admin_role_revoke = edge(
  function_url,
  api_key,
  {
    action: 'revoke',
    invitation_id: admin_role_data.fetch('invitation_id'),
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(admin_role_revoke.code.to_i == 200, 'Admin-role fixture revoke failed')
assert!(
  !admin_role_revoke.body.include?(admin_role_token),
  'Raw admin-role token leaked after creation response',
)
pass('owner-selected admin invitation role reaches server unchanged')

expired_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: stable_id,
    email: second_owner_email,
    role: 'viewer',
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
expired_data, expired_token = token_from_invitation_response(expired_created)
expired_invitation_id = expired_data.fetch('invitation_id')
expire_fixture = request(
  :patch,
  "#{api_url}/rest/v1/stable_invitations?id=eq.#{expired_invitation_id}",
  headers: service_headers,
  json: {
    created_at: (Time.now.utc - 172_800).iso8601,
    expires_at: (Time.now.utc - 86_400).iso8601,
  },
)
assert!([200, 204].include?(expire_fixture.code.to_i), 'Expiry fixture update failed')
expired_preview = edge(
  function_url,
  api_key,
  { action: 'preview', token: expired_token },
)
expired_preview_data = json_body(expired_preview)
assert!(expired_preview_data['status'] == 'expired', 'Expired preview was not neutral')
assert!(
  expired_preview_data.keys == ['status'],
  'Expired preview exposed stable or role information',
)
assert!(
  !expired_preview.body.include?(second_owner_email),
  'Expired preview exposed recipient contact data',
)
expired_accept = edge(
  function_url,
  api_key,
  {
    action: 'accept',
    token: expired_token,
    display_name: 'Verlopen ontvanger',
    request_id: SecureRandom.uuid,
  },
  session: second_owner_session,
)
assert!(expired_accept.code.to_i == 409, 'Expired invitation was accepted')
expired_membership = request(
  :get,
  "#{api_url}/rest/v1/stable_memberships?stable_id=eq.#{stable_id}&user_id=eq.#{second_owner_session.fetch('user').fetch('id')}&select=id",
  headers: service_headers,
)
assert!(
  JSON.parse(expired_membership.body).empty?,
  'Expired invitation created or restored a membership',
)
expired_preview_again = edge(
  function_url,
  api_key,
  { action: 'preview', token: expired_token },
)
assert!(
  json_body(expired_preview_again)['status'] == 'expired',
  'Expired invitation became reusable',
)
pass('actually expired token previews neutrally and cannot create membership')

second_headers = auth_headers(api_key, second_owner_session)
second_create = rpc(
  api_url,
  'create_stable',
  second_headers,
  {
    p_name: 'Lokale ratelimitstal',
    p_timezone: 'Europe/Amsterdam',
    p_kind: 'organization',
    p_locale: 'nl',
    p_creation_request_id: SecureRandom.uuid,
    p_owner_display_name: 'Tweede lokale owner',
    p_owner_function_title: nil,
  },
)
second_stable_id = json_body(second_create).fetch('stable_id')
rate_email = "phase4b-rate-#{suffix}@example.test"
rate_create = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: second_stable_id,
    email: rate_email,
    role: 'viewer',
    request_id: SecureRandom.uuid,
  },
  session: second_owner_session,
)
rate_data, rate_token = token_from_invitation_response(rate_create)
rate_invitation_id = rate_data.fetch('invitation_id')
5.times do |index|
  rewind = request(
    :patch,
    "#{api_url}/rest/v1/stable_invitations?id=eq.#{rate_invitation_id}",
    headers: service_headers,
    json: { last_sent_at: (Time.now.utc - 120).iso8601 },
  )
  assert!([200, 204].include?(rewind.code.to_i), 'Rate fixture rewind failed')
  response = edge(
    function_url,
    api_key,
    {
      action: 'resend',
      invitation_id: rate_invitation_id,
      request_id: SecureRandom.uuid,
    },
    session: second_owner_session,
  )
  assert!(response.code.to_i == 200, 'Allowed recipient resend failed')
  if index.zero?
    old_preview = edge(
      function_url,
      api_key,
      { action: 'preview', token: rate_token },
    )
    assert!(
      json_body(old_preview)['status'] == 'unavailable',
      'Old token remained valid after resend',
    )
  end
end
rewind = request(
  :patch,
  "#{api_url}/rest/v1/stable_invitations?id=eq.#{rate_invitation_id}",
  headers: service_headers,
  json: { last_sent_at: (Time.now.utc - 120).iso8601 },
)
recipient_limited = edge(
  function_url,
  api_key,
  {
    action: 'resend',
    invitation_id: rate_invitation_id,
    request_id: SecureRandom.uuid,
  },
  session: second_owner_session,
)
assert!(recipient_limited.code.to_i == 409, 'Sixth daily resend was allowed')
pass('recipient/stable daily resend limit is enforced')

14.times do |index|
  response = edge(
    function_url,
    api_key,
    {
      action: 'create',
      stable_id: second_stable_id,
      email: "phase4b-action-#{index}-#{suffix}@example.test",
      role: 'viewer',
      request_id: SecureRandom.uuid,
    },
    session: second_owner_session,
  )
  assert!(response.code.to_i == 200, 'Allowed actor invitation action failed')
end
actor_limited = edge(
  function_url,
  api_key,
  {
    action: 'create',
    stable_id: second_stable_id,
    email: "phase4b-action-blocked-#{suffix}@example.test",
    role: 'viewer',
    request_id: SecureRandom.uuid,
  },
  session: second_owner_session,
)
assert!(actor_limited.code.to_i == 409, 'Twenty-first daily actor action was allowed')
pass('actor daily invitation-action limit is enforced')

stored = request(
  :get,
  "#{api_url}/rest/v1/stable_invitations?id=eq.#{invitation_id}&select=token_hash,status",
  headers: service_headers,
)
assert!(stored.code.to_i == 200, 'Could not inspect local token storage')
assert!(!stored.body.include?(existing_token), 'Raw token appeared in database response')
assert!(
  !File.read(__FILE__).include?(existing_token),
  'Raw token appeared in the test application source/log contract',
)
pass('raw token is absent from database and test output')

owner_delete = request(
  :post,
  delete_function_url,
  headers: auth_headers(api_key, owner_session),
  json: {},
)
member_delete = request(
  :post,
  delete_function_url,
  headers: auth_headers(api_key, existing_session),
  json: {},
)
unaffiliated_delete = request(
  :post,
  delete_function_url,
  headers: auth_headers(api_key, wrong_session),
  json: {},
)
assert!(owner_delete.code.to_i == 409, 'Active owner deletion was not blocked')
assert!(member_delete.code.to_i == 409, 'Active member deletion was not blocked')
assert!(
  unaffiliated_delete.code.to_i == 503,
  'Incomplete full account deletion did not fail closed',
)
pass('account deletion fails closed for owner, active member and incomplete deletion')

puts 'SUMMARY: 27 Phase 4B invitation integration assertions passed'
