require 'base64'
require 'digest'
require 'json'
require 'net/http'
require 'securerandom'
require 'time'
require 'uri'
require 'zlib'

status_file = ARGV.fetch(0)
env = File.readlines(status_file, chomp: true).each_with_object({}) do |line, values|
  next unless line.include?('=')

  key, value = line.split('=', 2)
  values[key] = value.to_s.sub(/\A"/, '').sub(/"\z/, '')
end

api_url = env.fetch('API_URL')
api_key = env['ANON_KEY'].to_s.empty? ? env.fetch('PUBLISHABLE_KEY') : env['ANON_KEY']
service_key =
  env['SERVICE_ROLE_KEY'].to_s.empty? ? env.fetch('SECRET_KEY') : env['SERVICE_ROLE_KEY']
function_url = "#{api_url}/functions/v1/media-assets"

def request(method, url, headers: {}, json: nil, body: nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  klass = {
    get: Net::HTTP::Get,
    patch: Net::HTTP::Patch,
    post: Net::HTTP::Post,
    put: Net::HTTP::Put,
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

def create_user(api_url, service_key, email, password)
  response = request(
    :post,
    "#{api_url}/auth/v1/admin/users",
    headers: {
      'apikey' => service_key,
      'Authorization' => "Bearer #{service_key}",
    },
    json: {
      email: email,
      password: password,
      email_confirm: true,
    },
  )
  assert!(response.code.to_i == 200, "Local admin user creation failed: #{response.code}")
  json_body(response)
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

def service_write(api_url, service_key, method, path, body)
  request(
    method,
    "#{api_url}/rest/v1/#{path}",
    headers: {
      'apikey' => service_key,
      'Authorization' => "Bearer #{service_key}",
      'Prefer' => 'return=minimal',
    },
    json: body,
  )
end

def edge(function_url, api_key, body, session:)
  request(
    :post,
    function_url,
    headers: auth_headers(api_key, session),
    json: body,
  )
end

def public_url(raw_url, api_url)
  raw = URI(raw_url)
  public_origin = URI(api_url)
  raw.scheme = public_origin.scheme
  raw.host = public_origin.host
  raw.port = public_origin.port
  raw.to_s
end

def signed_upload(upload, api_url, api_key, session, bytes, mime_type)
  response = request(
    :put,
    public_url(upload.fetch('signed_upload_url'), api_url),
    headers: auth_headers(api_key, session).merge('Content-Type' => mime_type),
    body: bytes,
  )
  assert!(
    response.code.to_i.between?(200, 299),
    "Signed upload failed: #{response.code} #{response.body}",
  )
end

def assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  session,
  horse_id,
  filename,
  mime_type,
  bytes
)
  created = edge(
    function_url,
    api_key,
    {
      action: 'create',
      horse_id: horse_id,
      schedule_execution_id: nil,
      original_filename: filename,
      mime_type: mime_type,
      request_id: SecureRandom.uuid,
    },
    session: session,
  )
  assert!(created.code.to_i == 200, "Invalid-structure fixture create failed: #{mime_type}")
  data = json_body(created)
  data.fetch('uploads').each do |upload|
    signed_upload(upload, api_url, api_key, session, bytes, mime_type)
  end
  finalized = edge(
    function_url,
    api_key,
    {
      action: 'finalize',
      media_asset_id: data.fetch('media_asset_id'),
      expected_row_version: data.fetch('row_version'),
      request_id: SecureRandom.uuid,
    },
    session: session,
  )
  assert!(
    finalized.code.to_i == 409,
    "Structurally invalid #{mime_type} finalized",
  )
  unavailable = edge(
    function_url,
    api_key,
    {
      action: 'download',
      media_asset_id: data.fetch('media_asset_id'),
      variant: 'original',
    },
    session: session,
  )
  assert!(unavailable.code.to_i == 404, "Rejected #{mime_type} became readable")
end

def assert_valid_media(
  function_url,
  api_url,
  api_key,
  session,
  horse_id,
  filename,
  mime_type,
  bytes
)
  created = edge(
    function_url,
    api_key,
    {
      action: 'create',
      horse_id: horse_id,
      schedule_execution_id: nil,
      original_filename: filename,
      mime_type: mime_type,
      request_id: SecureRandom.uuid,
    },
    session: session,
  )
  assert!(created.code.to_i == 200, "Valid fixture create failed: #{mime_type}")
  data = json_body(created)
  data.fetch('uploads').each do |upload|
    signed_upload(upload, api_url, api_key, session, bytes, mime_type)
  end
  finalized = edge(
    function_url,
    api_key,
    {
      action: 'finalize',
      media_asset_id: data.fetch('media_asset_id'),
      expected_row_version: data.fetch('row_version'),
      request_id: SecureRandom.uuid,
    },
    session: session,
  )
  assert!(
    finalized.code.to_i == 200,
    "Structurally valid #{mime_type} was rejected: #{finalized.body}",
  )
end

def minimal_pdf
  parts = ["%PDF-1.4\n"]
  offsets = []
  [
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 1 1] >>\nendobj\n",
  ].each do |object|
    offsets << parts.join.bytesize
    parts << object
  end
  xref_offset = parts.join.bytesize
  parts << "xref\n0 4\n"
  parts << "0000000000 65535 f \n"
  offsets.each { |offset| parts << format('%010d 00000 n ', offset) << "\n" }
  parts << "trailer\n<< /Size 4 /Root 1 0 R >>\n"
  parts << "startxref\n#{xref_offset}\n%%EOF\n"
  parts.join.b
end

def catalog_only_pdf
  parts = ["%PDF-1.4\n"]
  object = "1 0 obj\n<< /Type /Catalog >>\nendobj\n"
  object_offset = parts.join.bytesize
  parts << object
  xref_offset = parts.join.bytesize
  parts << "xref\n0 2\n"
  parts << "0000000000 65535 f \n"
  parts << format('%010d 00000 n ', object_offset) << "\n"
  parts << "trailer\n<< /Size 2 /Root 1 0 R >>\n"
  parts << "startxref\n#{xref_offset}\n%%EOF\n"
  parts.join.b
end

def oversized_dimension_jpeg(bytes)
  result = bytes.dup
  frame_markers =
    (0xC0..0xC3).to_a +
    (0xC5..0xC7).to_a +
    (0xC9..0xCB).to_a +
    (0xCD..0xCF).to_a
  marker_offset = (0...(result.bytesize - 9)).find do |index|
    result.getbyte(index) == 0xFF &&
      frame_markers.include?(result.getbyte(index + 1))
  end
  raise 'Valid JPEG fixture has no frame marker' unless marker_offset

  dimension = 5000
  result.setbyte(marker_offset + 5, dimension >> 8)
  result.setbyte(marker_offset + 6, dimension & 0xFF)
  result.setbyte(marker_offset + 7, dimension >> 8)
  result.setbyte(marker_offset + 8, dimension & 0xFF)
  result
end

def invalid_scan_table_jpeg(bytes)
  scan_offset = (0...(bytes.bytesize - 4)).find do |index|
    bytes.getbyte(index) == 0xFF && bytes.getbyte(index + 1) == 0xDA
  end
  raise 'Valid JPEG fixture has no scan marker' unless scan_offset

  result = bytes.dup
  result.setbyte(scan_offset + 6, 0x33)
  result
end

def png_chunk(type, data)
  [data.bytesize].pack('N') +
    type +
    data +
    [Zlib.crc32(type + data)].pack('N')
end

def oversized_decoded_png
  width = 6000
  height = 6000
  compressor = Zlib::Deflate.new(Zlib::BEST_COMPRESSION)
  compressed = String.new.b
  row = "\x00".b * (width + 1)
  height.times { compressed << compressor.deflate(row, Zlib::NO_FLUSH) }
  compressed << compressor.finish
  compressor.close
  ihdr = [width, height, 8, 0, 0, 0, 0].pack('NNCCCCC')
  "\x89PNG\r\n\x1A\n".b +
    png_chunk('IHDR'.b, ihdr) +
    png_chunk('IDAT'.b, compressed) +
    png_chunk('IEND'.b, ''.b)
end

suffix = "#{Time.now.to_i}-#{SecureRandom.hex(3)}"
email = "phase4c5-owner-#{suffix}@example.test"
password = 'LocalOnly4C5!'
created_user = create_user(api_url, service_key, email, password)
owner_session = session(api_url, api_key, email, password)
owner_headers = auth_headers(api_key, owner_session)
assert!(
  created_user.fetch('id') == owner_session.dig('user', 'id'),
  'Authenticated user differs from locally created owner',
)
pass('isolated confirmed local media owner created')

stable = rpc(
  api_url,
  'create_stable',
  owner_headers,
  {
    p_name: '4C.5 lokale mediastal',
    p_timezone: 'Europe/Amsterdam',
    p_kind: 'organization',
    p_locale: 'nl',
    p_creation_request_id: SecureRandom.uuid,
    p_owner_display_name: '4C.5 media owner',
    p_owner_function_title: nil,
  },
)
assert!(stable.code.to_i == 200, "Stable creation failed: #{stable.code}")
stable_id = json_body(stable).fetch('stable_id')
horse = rpc(
  api_url,
  'create_horse',
  owner_headers,
  {
    p_stable_id: stable_id,
    p_display_name: 'Storage Byte',
    p_request_id: SecureRandom.uuid,
  },
)
assert!(horse.code.to_i == 200, "Horse creation failed: #{horse.code}")
horse_id = json_body(horse).fetch('horse_id')
pass('local stable and Horse created through authenticated RPCs')

png = Base64.decode64(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
)
executor_email = "phase4c5-executor-#{suffix}@example.test"
executor_user = create_user(api_url, service_key, executor_email, password)
executor_session = session(api_url, api_key, executor_email, password)
executor_member_id = SecureRandom.uuid
executor_membership_id = SecureRandom.uuid
member_insert = service_write(
  api_url,
  service_key,
  :post,
  'stable_members',
  {
    id: executor_member_id,
    stable_id: stable_id,
    display_name: '4C.5 execution uploader',
    status: 'active',
    source: 'manual',
  },
)
assert!(member_insert.code.to_i == 201, 'Execution member insert failed')
membership_insert = service_write(
  api_url,
  service_key,
  :post,
  'stable_memberships',
  {
    id: executor_membership_id,
    stable_id: stable_id,
    user_id: executor_user.fetch('id'),
    stable_member_id: executor_member_id,
    role: 'viewer',
    status: 'active',
    joined_at: Time.now.utc.iso8601,
  },
)
assert!(membership_insert.code.to_i == 201, 'Execution membership insert failed')

schedule_item_id = SecureRandom.uuid
execution_id = SecureRandom.uuid
now = Time.now.utc
item_insert = service_write(
  api_url,
  service_key,
  :post,
  'schedule_items',
  {
    id: schedule_item_id,
    stable_id: stable_id,
    horse_id: horse_id,
    item_kind: 'task',
    data_category: 'horse.schedule',
    title: 'Execution media proof',
    instruction: 'Attach only proof for this execution.',
    priority: 'normal',
    scheduled_start_at: (now - 1800).iso8601,
    scheduled_end_at: now.iso8601,
    source_timezone: 'Europe/Amsterdam',
    source_local_date: now.strftime('%Y-%m-%d'),
    source_local_time: now.strftime('%H:%M:%S'),
    state: 'completed',
    terminal_at: now.iso8601,
    created_by_user_id: created_user.fetch('id'),
    created_request_id: SecureRandom.uuid,
    last_mutated_by_user_id: created_user.fetch('id'),
    last_mutation_request_id: SecureRandom.uuid,
  },
)
assert!(item_insert.code.to_i == 201, "Schedule item insert failed: #{item_insert.body}")
execution_insert = service_write(
  api_url,
  service_key,
  :post,
  'schedule_executions',
  {
    id: execution_id,
    stable_id: stable_id,
    schedule_item_id: schedule_item_id,
    actor_user_id: executor_user.fetch('id'),
    actor_membership_id: executor_membership_id,
    actor_stable_member_id: executor_member_id,
    execution_status: 'completed',
    actual_started_at: (now - 1200).iso8601,
    actual_completed_at: now.iso8601,
    recorded_local_at: now.strftime('%Y-%m-%dT%H:%M:%S'),
    recorded_timezone: 'Europe/Amsterdam',
    source: 'online',
    request_id: SecureRandom.uuid,
  },
)
assert!(
  execution_insert.code.to_i == 201,
  "Schedule execution insert failed: #{execution_insert.body}",
)

execution_create_request = SecureRandom.uuid
execution_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    horse_id: horse_id,
    schedule_execution_id: execution_id,
    original_filename: 'execution-proof.png',
    mime_type: 'image/png',
    request_id: execution_create_request,
  },
  session: executor_session,
)
assert!(
  execution_created.code.to_i == 200,
  "Execution-scoped media create failed: #{execution_created.body}",
)
execution_data = json_body(execution_created)
execution_data.fetch('uploads').each do |upload|
  signed_upload(upload, api_url, api_key, executor_session, png, 'image/png')
end
execution_finalize_request = SecureRandom.uuid
execution_finalized = edge(
  function_url,
  api_key,
  {
    action: 'finalize',
    media_asset_id: execution_data.fetch('media_asset_id'),
    expected_row_version: execution_data.fetch('row_version'),
    request_id: execution_finalize_request,
  },
  session: executor_session,
)
assert!(
  execution_finalized.code.to_i == 200,
  "Execution-scoped finalize failed: #{execution_finalized.code} #{execution_finalized.body}",
)
execution_headers = auth_headers(api_key, executor_session)
execution_assets = json_body(
  request(
    :get,
    "#{api_url}/rest/v1/media_assets?id=eq.#{execution_data.fetch('media_asset_id')}&select=id",
    headers: execution_headers,
  ),
)
assert!(execution_assets.length == 1, 'Active execution actor cannot read linked asset')

horse_link = rpc(
  api_url,
  'link_media_asset',
  owner_headers,
  {
    p_media_asset_id: execution_data.fetch('media_asset_id'),
    p_horse_id: horse_id,
    p_schedule_execution_id: nil,
    p_request_id: SecureRandom.uuid,
  },
)
assert!(horse_link.code.to_i == 200, 'Owner could not add typed Horse link')
visible_links = json_body(
  request(
    :get,
    "#{api_url}/rest/v1/media_links?media_asset_id=eq.#{execution_data.fetch('media_asset_id')}&select=link_kind,schedule_execution_id,horse_id",
    headers: execution_headers,
  ),
)
assert!(
  visible_links.length == 1 &&
    visible_links.first.fetch('link_kind') == 'schedule_execution' &&
    visible_links.first.fetch('schedule_execution_id') == execution_id,
  'Minimal execution actor saw unrelated media links',
)
visible_events = json_body(
  request(
    :get,
    "#{api_url}/rest/v1/media_change_events?media_asset_id=eq.#{execution_data.fetch('media_asset_id')}&select=id",
    headers: execution_headers,
  ),
)
assert!(visible_events.empty?, 'Minimal execution actor saw media audit events')
pass('execution actor gets the asset but only its own typed link and no audit graph')

suspended = service_write(
  api_url,
  service_key,
  :patch,
  "stable_memberships?id=eq.#{executor_membership_id}",
  {
    status: 'suspended',
    ended_at: Time.now.utc.iso8601,
    ended_reason: '4C.5 revocation regression',
  },
)
assert!(suspended.code.to_i == 204, "Membership suspension failed: #{suspended.body}")
revoked_assets = json_body(
  request(
    :get,
    "#{api_url}/rest/v1/media_assets?id=eq.#{execution_data.fetch('media_asset_id')}&select=id",
    headers: execution_headers,
  ),
)
assert!(revoked_assets.empty?, 'Suspended execution actor retained table access')
revoked_execution_download = edge(
  function_url,
  api_key,
  {
    action: 'download',
    media_asset_id: execution_data.fetch('media_asset_id'),
    variant: 'original',
  },
  session: executor_session,
)
assert!(revoked_execution_download.code.to_i == 404, 'Suspended actor received signed URL')
revoked_retry = edge(
  function_url,
  api_key,
  {
    action: 'create',
    horse_id: horse_id,
    schedule_execution_id: execution_id,
    original_filename: 'execution-proof.png',
    mime_type: 'image/png',
    request_id: execution_create_request,
  },
  session: executor_session,
)
assert!(revoked_retry.code.to_i >= 400, 'Suspended actor reopened upload session')
assert!(
  !revoked_retry.body.include?('signed_') &&
    !revoked_retry.body.include?('upload_token') &&
    !revoked_retry.body.include?('object_path'),
  'Revoked create retry leaked transport credentials',
)
pass('membership suspension revokes RLS, signed download and exact create retry')

editor_email = "phase4c5-editor-#{suffix}@example.test"
editor_user = create_user(api_url, service_key, editor_email, password)
editor_session = session(api_url, api_key, editor_email, password)
editor_member_id = SecureRandom.uuid
editor_membership_id = SecureRandom.uuid
editor_member_insert = service_write(
  api_url,
  service_key,
  :post,
  'stable_members',
  {
    id: editor_member_id,
    stable_id: stable_id,
    display_name: '4C.5 revoked media editor',
    status: 'active',
    source: 'manual',
  },
)
assert!(editor_member_insert.code.to_i == 201, 'Media editor member insert failed')
editor_membership_insert = service_write(
  api_url,
  service_key,
  :post,
  'stable_memberships',
  {
    id: editor_membership_id,
    stable_id: stable_id,
    user_id: editor_user.fetch('id'),
    stable_member_id: editor_member_id,
    role: 'member',
    status: 'active',
    joined_at: Time.now.utc.iso8601,
  },
)
assert!(
  editor_membership_insert.code.to_i == 201,
  'Media editor membership insert failed',
)
editor_grant = rpc(
  api_url,
  'grant_horse_access',
  owner_headers,
  {
    p_horse_id: horse_id,
    p_membership_id: editor_membership_id,
    p_category: 'horse.media',
    p_can_view: true,
    p_can_execute: false,
    p_can_edit: true,
    p_can_manage: false,
    p_valid_from: nil,
    p_valid_until: nil,
    p_grant_reason: 'Finalize-revocation regression',
    p_request_id: SecureRandom.uuid,
  },
)
assert!(editor_grant.code.to_i == 200, "Media editor grant failed: #{editor_grant.body}")
editor_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    horse_id: horse_id,
    schedule_execution_id: nil,
    original_filename: 'revoked-before-finalize.png',
    mime_type: 'image/png',
    request_id: SecureRandom.uuid,
  },
  session: editor_session,
)
assert!(
  editor_created.code.to_i == 200,
  "Media editor create failed: #{editor_created.body}",
)
editor_data = json_body(editor_created)
editor_revoke = rpc(
  api_url,
  'revoke_horse_access',
  owner_headers,
  {
    p_horse_id: horse_id,
    p_membership_id: editor_membership_id,
    p_category: 'horse.media',
    p_request_id: SecureRandom.uuid,
  },
)
assert!(editor_revoke.code.to_i == 200, "Media editor revoke failed: #{editor_revoke.body}")
editor_data.fetch('uploads').each do |upload|
  signed_upload(upload, api_url, api_key, editor_session, png, 'image/png')
end
editor_finalize = edge(
  function_url,
  api_key,
  {
    action: 'finalize',
    media_asset_id: editor_data.fetch('media_asset_id'),
    expected_row_version: editor_data.fetch('row_version'),
    request_id: SecureRandom.uuid,
  },
  session: editor_session,
)
assert!(editor_finalize.code.to_i >= 400, 'Revoked media editor finalized signed upload')
pending_editor_asset = json_body(
  request(
    :get,
    "#{api_url}/rest/v1/media_assets?id=eq.#{editor_data.fetch('media_asset_id')}&select=status",
    headers: {
      'apikey' => service_key,
      'Authorization' => "Bearer #{service_key}",
    },
  ),
)
assert!(
  pending_editor_asset.length == 1 &&
    pending_editor_asset.first.fetch('status') == 'pending',
  'Revoked media editor changed pending lifecycle state',
)
pass('grant revoke after signed upload issuance blocks finalize and preserves pending state')

create_request_id = SecureRandom.uuid
created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    horse_id: horse_id,
    schedule_execution_id: nil,
    original_filename: '../client/path/portrait.png',
    mime_type: 'image/png',
    request_id: create_request_id,
  },
  session: owner_session,
)
assert!(created.code.to_i == 200, "Media session create failed: #{created.code} #{created.body}")
created_data = json_body(created)
asset_id = created_data.fetch('media_asset_id')
uploads = created_data.fetch('uploads')
assert!(uploads.length == 2, 'Image session does not contain two variants')
uploads.each do |upload|
  expected = "#{stable_id}/#{horse_id}/#{asset_id}/#{upload.fetch('variant')}"
  assert!(upload.fetch('object_path') == expected, 'Object path was not server-derived')
  assert!(upload.fetch('signed_upload_url').start_with?('http'), 'Signed upload URL missing')
  assert!(!upload.fetch('upload_token').empty?, 'Upload token missing')
end
pass('server chose stable/Horse/asset paths and returned transient upload credentials')

pending_download = edge(
  function_url,
  api_key,
  { action: 'download', media_asset_id: asset_id, variant: 'original' },
  session: owner_session,
)
assert!(pending_download.code.to_i == 404, 'Pending media was downloadable')
direct_get = request(
  :get,
  "#{api_url}/storage/v1/object/horse-media/#{stable_id}/#{horse_id}/#{asset_id}/original",
  headers: owner_headers,
)
assert!(
  direct_get.code.to_i >= 400,
  'Private object was readable without a signed URL',
)
pass('pending metadata and private object are unreadable')

uploads.each do |upload|
  signed_upload(upload, api_url, api_key, owner_session, png, 'image/png')
end
pass('original and thumbnail uploaded through their bound signed URLs')

wrong_path = uploads.first.fetch('signed_upload_url').sub(
  "/#{asset_id}/original",
  "/#{SecureRandom.uuid}/original",
)
wrong_upload = request(
  :put,
  public_url(wrong_path, api_url),
  headers: owner_headers.merge('Content-Type' => 'image/png'),
  body: png,
)
assert!(wrong_upload.code.to_i >= 400, 'Upload token accepted a different object path')
pass('signed upload token is path-bound')

finalize_request_id = SecureRandom.uuid
finalized = edge(
  function_url,
  api_key,
  {
    action: 'finalize',
    media_asset_id: asset_id,
    expected_row_version: created_data.fetch('row_version'),
    horse_id: horse_id,
    schedule_execution_id: nil,
    original_filename: '../client/path/portrait.png',
    mime_type: 'image/png',
    create_request_id: create_request_id,
    request_id: finalize_request_id,
  },
  session: owner_session,
)
assert!(
  finalized.code.to_i == 200,
  "Media finalize failed: #{finalized.code} #{finalized.body}",
)
finalized_data = json_body(finalized)
assert!(finalized_data.fetch('status') == 'ready', 'Finalized asset is not ready')
assert!(finalized_data.fetch('row_version') == 2, 'Finalize did not advance row version')
pass('Edge downloaded, magic-checked, sized and atomically finalized both variants')

finalize_retry = edge(
  function_url,
  api_key,
  {
    action: 'finalize',
    media_asset_id: asset_id,
    expected_row_version: created_data.fetch('row_version'),
    request_id: finalize_request_id,
  },
  session: owner_session,
)
assert!(finalize_retry.code.to_i == 200, 'Finalize exact retry failed at Edge boundary')
assert!(
  json_body(finalize_retry).fetch('idempotent') == true,
  'Finalize exact retry was not marked idempotent',
)
closed_create = edge(
  function_url,
  api_key,
  {
    action: 'create',
    horse_id: horse_id,
    schedule_execution_id: nil,
    original_filename: '../client/path/portrait.png',
    mime_type: 'image/png',
    request_id: create_request_id,
  },
  session: owner_session,
)
assert!(closed_create.code.to_i == 409, 'Ready asset reissued upload credentials')
assert!(
  !closed_create.body.include?('signed_') &&
    !closed_create.body.include?('upload_token') &&
    !closed_create.body.include?('object_path'),
  'Closed upload session leaked transport credentials',
)
pass('finalize is idempotent and a ready asset cannot reissue upload credentials')

asset_query = request(
  :get,
  "#{api_url}/rest/v1/media_assets?id=eq.#{asset_id}&select=id,status,sha256,original_filename",
  headers: owner_headers,
)
asset_rows = json_body(asset_query)
assert!(asset_rows.length == 1, 'Ready media not readable by Horse media owner')
assert!(
  asset_rows.first.fetch('sha256') == "\\x#{Digest::SHA256.hexdigest(png)}",
  'Persisted SHA-256 differs from actual uploaded bytes',
)
assert!(
  asset_rows.first.fetch('original_filename') == 'portrait.png',
  'Sanitized presentation filename incorrect',
)
pass('ready metadata stores actual hash and sanitized filename')

download = edge(
  function_url,
  api_key,
  { action: 'download', media_asset_id: asset_id, variant: 'original' },
  session: owner_session,
)
assert!(download.code.to_i == 200, "Signed download failed: #{download.code}")
download_data = json_body(download)
assert!(download_data.fetch('expires_in') == 60, 'Signed URL lifetime is not 60 seconds')
downloaded = request(
  :get,
  public_url(download_data.fetch('signed_download_url'), api_url),
)
assert!(downloaded.code.to_i == 200, 'Signed private object could not be downloaded')
assert!(downloaded.body.b == png.b, 'Signed download bytes differ from upload')
pass('authorized 60-second signed URL returns the exact private bytes')

spoof_create_request_id = SecureRandom.uuid
spoof_created = edge(
  function_url,
  api_key,
  {
    action: 'create',
    horse_id: horse_id,
    schedule_execution_id: nil,
    original_filename: 'spoofed.jpg',
    mime_type: 'image/jpeg',
    request_id: spoof_create_request_id,
  },
  session: owner_session,
)
assert!(spoof_created.code.to_i == 200, 'Spoof test session creation failed')
spoof_data = json_body(spoof_created)
spoof_data.fetch('uploads').each do |upload|
  signed_upload(upload, api_url, api_key, owner_session, png, 'image/jpeg')
end
spoof_finalize = edge(
  function_url,
  api_key,
  {
    action: 'finalize',
    media_asset_id: spoof_data.fetch('media_asset_id'),
    expected_row_version: spoof_data.fetch('row_version'),
    horse_id: horse_id,
    schedule_execution_id: nil,
    original_filename: 'spoofed.jpg',
    mime_type: 'image/jpeg',
    create_request_id: spoof_create_request_id,
    request_id: SecureRandom.uuid,
  },
  session: owner_session,
)
assert!(spoof_finalize.code.to_i == 409, 'MIME-spoofed PNG finalized as JPEG')
spoof_download = edge(
  function_url,
  api_key,
  {
    action: 'download',
    media_asset_id: spoof_data.fetch('media_asset_id'),
    variant: 'original',
  },
  session: owner_session,
)
assert!(spoof_download.code.to_i == 404, 'Rejected spoof became readable')
pass('actual magic bytes defeat Content-Type spoofing and rejected media stays pending')

assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'polyglot.png',
  'image/png',
  png + '<script>not-image</script>',
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'truncated.jpg',
  'image/jpeg',
  "\xFF\xD8\xFF\xE0\x00\x04AB\xFF\xD9".b,
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'fake.webp',
  'image/webp',
  "RIFF\x0C\x00\x00\x00WEBPVP8 \x00\x00\x00\x00".b,
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'fake.pdf',
  'application/pdf',
  "%PDF-1.7\n1 0 obj\n<<>>\nendobj\n%%EOF".b,
)
synthetic_jpeg =
  "\xFF\xD8".b +
  "\xFF\xC0\x00\x0B\x08\x00\x01\x00\x01\x01\x01\x11\x00".b +
  "\xFF\xDA\x00\x08\x01\x01\x00\x00\x3F\x00\x01\xFF\xD9".b
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'synthetic.jpg',
  'image/jpeg',
  synthetic_jpeg,
)
zero_quantization_jpeg =
  "\xFF\xD8".b +
  "\xFF\xDB\x00\x43\x00".b + ("\x00".b * 64) +
  "\xFF\xC4\x00\x26".b +
  "\x00\x01".b + ("\x00".b * 15) + "\x00".b +
  "\x10\x01".b + ("\x00".b * 15) + "\x00".b +
  "\xFF\xC0\x00\x0B\x08\x00\x01\x00\x01\x01\x01\x11\x00".b +
  "\xFF\xDA\x00\x08\x01\x01\x00\x00\x3F\x00\x01\xFF\xD9".b
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'zero-quantization.jpg',
  'image/jpeg',
  zero_quantization_jpeg,
)
synthetic_webp =
  "RIFF\x16\x00\x00\x00WEBP".b +
  "VP8 \x0A\x00\x00\x00\x20\x00\x00\x9D\x01\x2A\x01\x00\x01\x00".b
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'synthetic.webp',
  'image/webp',
  synthetic_webp,
)
single_byte_partition_webp =
  "RIFF\x18\x00\x00\x00WEBP".b +
  "VP8 \x0B\x00\x00\x00\x30\x00\x00\x9D\x01\x2A\x01\x00\x01\x00\x00\x00".b
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'single-byte-partition.webp',
  'image/webp',
  single_byte_partition_webp,
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'synthetic.pdf',
  'application/pdf',
  "%PDF-1.7\nxref-anything\nstartxref\n9\n%%EOF".b,
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'catalog-without-pages.pdf',
  'application/pdf',
  catalog_only_pdf,
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'decoded-over-limit.png',
  'image/png',
  oversized_decoded_png,
)
pass('truncated, synthetic, polyglot and decompression-bomb fixtures are rejected')

valid_jpeg = Base64.decode64(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AP//Z',
)
valid_webp = Base64.decode64(
  'UklGRi4AAABXRUJQVlA4ICIAAABwAQCdASoCAAIAAUAmJZQCdAFAAAD+/DC22xVxrse1wAAA',
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'invalid-scan-table.jpg',
  'image/jpeg',
  invalid_scan_table_jpeg(valid_jpeg),
)
assert_rejected_structure(
  function_url,
  api_url,
  api_key,
  owner_session,
  horse_id,
  'decoded-over-limit.jpg',
  'image/jpeg',
  oversized_dimension_jpeg(valid_jpeg),
)
assert_valid_media(
  function_url, api_url, api_key, owner_session, horse_id,
  'valid.jpg', 'image/jpeg', valid_jpeg,
)
assert_valid_media(
  function_url, api_url, api_key, owner_session, horse_id,
  'valid.webp', 'image/webp', valid_webp,
)
assert_valid_media(
  function_url, api_url, api_key, owner_session, horse_id,
  'valid.pdf', 'application/pdf', minimal_pdf,
)
pass('strict validators still accept valid JPEG, WebP and PDF fixtures')

archive = rpc(
  api_url,
  'archive_media_asset',
  owner_headers,
  {
    p_media_asset_id: asset_id,
    p_expected_row_version: 2,
    p_request_id: SecureRandom.uuid,
  },
)
assert!(archive.code.to_i == 200, "Media archive failed: #{archive.code}")
revoked_download = edge(
  function_url,
  api_key,
  { action: 'download', media_asset_id: asset_id, variant: 'original' },
  session: owner_session,
)
assert!(revoked_download.code.to_i == 404, 'Archived asset received a new signed URL')
archived_rows = json_body(
  request(
    :get,
    "#{api_url}/rest/v1/media_assets?id=eq.#{asset_id}&select=id",
    headers: owner_headers,
  ),
)
assert!(archived_rows.empty?, 'Archived asset remained visible through RLS')
pass('soft archive immediately blocks metadata and all new signed URLs')

events = request(
  :get,
  "#{api_url}/rest/v1/media_change_events?select=*&media_asset_id=eq.#{asset_id}",
  headers: owner_headers,
)
assert!(json_body(events).empty?, 'Archived media audit history leaked through RLS')
%w[signed_url signed_download_url signed_upload_url upload_token object_path sha256].each do |key|
  assert!(!events.body.include?(key), "Audit response contains forbidden key #{key}")
end
pass('no signed URL, token, object path or hash appears in readable audit payloads')
