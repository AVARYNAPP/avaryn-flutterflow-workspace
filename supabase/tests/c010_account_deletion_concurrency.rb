# Explicit owned local target only. New synthetic identities are preserved for
# diagnosis; no reset, unrelated cleanup, forged JWT or Storage metadata writes.
require 'json'
require 'open3'
require 'securerandom'
require 'net/http'
require 'uri'
require 'base64'
require 'timeout'

container, database, environment_path = ARGV
abort 'explicit container, postgres database and private environment.json required' unless container && database == 'postgres' && environment_path
cfg = JSON.parse(File.read(environment_path))
target = cfg.fetch('target')
raise 'wrong environment ownership' unless target.match?(/\Aavaryn-c010-[a-z0-9-]+\z/) && container == target + '-db' &&
  cfg['owner'] == 'avaryn-route-b-v1' && cfg['project_id'] == 'a-v-a-r-y-n-alpha-ynvyuq'
labels_out, _, status = Open3.capture3('docker','container','inspect',container,'--format','{{json .Config.Labels}}')
raise 'cannot verify own container' unless status.success?
labels = JSON.parse(labels_out)
raise 'container ownership mismatch' unless labels['io.avaryn.local.owner'] == cfg['owner'] &&
  labels['io.avaryn.local.target'] == target && labels['io.avaryn.local.project'] == cfg['project_id']
port = cfg.fetch('ports').fetch('api')
raise 'invalid loopback API port' unless port.is_a?(Integer) && port.between?(1024,65535)
base = "http://127.0.0.1:#{port}"
psql = ['docker','exec','-i',container,'psql','-X','-qAt','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1'].freeze

# No request headers, passwords, access tokens, paths or raw responses in output.
def http(base, method, path, key, bearer, body=nil, binary: false)
  uri=URI(base+path); req_class={'GET'=>Net::HTTP::Get,'POST'=>Net::HTTP::Post,'DELETE'=>Net::HTTP::Delete}.fetch(method)
  req=req_class.new(uri);req['apikey']=key;req['Authorization']='Bearer '+bearer
  req['Content-Type']=binary ? 'image/png' : 'application/json'
  req.body=binary ? body : JSON.generate(body) unless body.nil?
  connection=Net::HTTP.new(uri.host,uri.port,nil);connection.open_timeout=5;connection.read_timeout=15
  response=connection.request(req)
  parsed=JSON.parse(response.body) rescue {}
  [response.code.to_i,parsed]
end

def expect_status(pair, statuses, label)
  raise "#{label}: HTTP #{pair[0]}" unless statuses.include?(pair[0])
  pair[1]
end

def sql(psql, source)
  out, err, result=Open3.capture3(*psql,stdin_data:"set statement_timeout='12s';\n"+source)
  raise "owned SQL rejected (#{err[/ERROR:\s+([^\n]+)/,1] || 'no detail'})" unless result.success?
  out.lines.map(&:strip).reject(&:empty?)
end

def rpc(base,cfg,name,args,token=nil)
  key=token ? cfg.fetch('anon_key') : cfg.fetch('service_key')
  expect_status(http(base,'POST','/rest/v1/rpc/'+name,key,token || key,args),[200],'RPC '+name)
end

def auth_user(base,cfg)
  password=SecureRandom.hex(24); email='deletion-race-'+SecureRandom.uuid+'@'+cfg.fetch('target')+'.invalid'
  created=expect_status(http(base,'POST','/auth/v1/admin/users',cfg.fetch('service_key'),cfg.fetch('service_key'),
    {'email'=>email,'password'=>password,'email_confirm'=>true}),[200,201],'synthetic Auth create')
  session=expect_status(http(base,'POST','/auth/v1/token?grant_type=password',cfg.fetch('anon_key'),cfg.fetch('anon_key'),
    {'email'=>email,'password'=>password}),[200],'actual password login')
  {'id'=>created.fetch('id'),'token'=>session.fetch('access_token'),'email'=>email}
end

def profile(base,cfg,user)
  result=rpc(base,cfg,'get_current_account_profile',{},user.fetch('token'))
  result.is_a?(Array) ? result.fetch(0).fetch('profile_id') : result.fetch('profile_id')
end

def pause_preparation(psql,actor,request,tag)
  worker=Thread.new do
    sql(psql,"begin; set local application_name='#{tag}'; set local role service_role; select set_config('request.jwt.claim.role','service_role',true); select public.prepare_c010_account_deletion('#{actor}','#{request}'); select pg_sleep(1.8); commit;")
  end
  deadline=Process.clock_gettime(Process::CLOCK_MONOTONIC)+5
  loop do
    ready=sql(psql,"begin read only; select exists(select 1 from pg_stat_activity where application_name='#{tag}' and wait_event='PgSleep'); commit;").last=='t'
    break if ready
    raise 'preparation did not reach controlled lock barrier' if Process.clock_gettime(Process::CLOCK_MONOTONIC)>deadline
    sleep 0.02
  end
  worker
end

def hard_delete(base,cfg,user)
  expect_status(http(base,'DELETE','/auth/v1/admin/users/'+user.fetch('id'),cfg.fetch('service_key'),cfg.fetch('service_key'),
    {'should_soft_delete'=>false}),[200],'synthetic Auth hard-delete')
end

checks=[]
# Two separate HTTP sessions submit different request IDs for the same profile.
# The lock must choose one durable correlation, not two jobs/audits.
plain=auth_user(base,cfg)
requests=[SecureRandom.uuid,SecureRandom.uuid]
workers=requests.map { |id| Thread.new { rpc(base,cfg,'prepare_c010_account_deletion',{'p_auth_user_id'=>plain['id'],'p_request_id'=>id}) } }
results=workers.map(&:value)
raise 'double prepare diverged' unless results.all? { |v| v['status']=='auth_removal_pending' } && results.map { |v| v['correlation_id'] }.uniq.length==1
request=results[0].fetch('correlation_id')
checks << 'two genuine service HTTP preparations converge on one profile job'
hard_delete(base,cfg,plain)
finals=2.times.map { Thread.new { rpc(base,cfg,'finalize_c010_account_deletion',{'p_request_id'=>request}) } }.map(&:value)
raise 'double finalize diverged' unless finals.all? { |v| v['status']=='anonymized' }
count=sql(psql,"begin read only; select count(*) from public.audit_events where correlation_id='#{request}' and event_type='profile.anonymization_finalized'; commit;").last
raise 'terminal audit duplicated' unless count=='1'
checks << 'Auth already absent and two finalizers create exactly one terminal audit'

# Real authorized grant waits on the recipient preparation lock, then must fail.
owner=auth_user(base,cfg); recipient=auth_user(base,cfg)
recipient_profile=profile(base,cfg,recipient)
horse_result=rpc(base,cfg,'create_canonical_horse_profile',{
  'p_display_name'=>'Deletion concurrency horse','p_official_name'=>nil,'p_birth_date'=>nil,'p_sex'=>'unknown',
  'p_breed'=>nil,'p_discipline'=>nil,'p_level'=>nil,'p_color'=>nil,'p_notes'=>nil,
  'p_chip_number'=>nil,'p_passport_number'=>nil,'p_passport_valid_until'=>nil,'p_correlation_id'=>SecureRandom.uuid
},owner['token'])
horse_id=horse_result.is_a?(Array) ? horse_result[0].fetch('horse_id') : horse_result.fetch('horse_id')
grant_request=SecureRandom.uuid; recipient_request=SecureRandom.uuid
tag='avaryn_delete_grant_'+SecureRandom.hex(8)
worker=pause_preparation(psql,recipient['id'],recipient_request,tag)
grant=http(base,'POST','/rest/v1/rpc/grant_horse_profile_permission',cfg.fetch('anon_key'),owner['token'],{
  'p_horse_id'=>horse_id,'p_grantee_profile_id'=>recipient_profile,'p_permission_code'=>'horse.view',
  'p_relationship_id'=>nil,'p_valid_from'=>nil,'p_valid_until'=>nil,'p_reason_code'=>'MANUAL_GRANT','p_correlation_id'=>grant_request})
worker.value
raise 'grant raced through completed preparation' unless [400,403,409].include?(grant[0]) &&
  ['ACTIVE_TARGET_PROFILE_REQUIRED','ACTIVE_GRANTEE_PROFILE_REQUIRED'].include?(grant[1]['message'])
count=sql(psql,"begin read only; select count(*) from public.horse_profile_permission_grants where grantee_profile_id='#{recipient_profile}' and status='active'; commit;").last
raise 'active recipient grant survived preparation race' unless count=='0'
hard_delete(base,cfg,recipient)
raise 'recipient did not finalize' unless rpc(base,cfg,'finalize_c010_account_deletion',{'p_request_id'=>recipient_request})['status']=='anonymized'
checks << 'real authorized grant cannot commit after recipient preparation'

# A legacy invitation can contain only email, without an Auth FK. That
# target still must serialize with preparation; it cannot appear afterwards.
legacy=rpc(base,cfg,'create_stable',{'p_name'=>'Legacy deletion race','p_timezone'=>'UTC','p_kind'=>'organization',
  'p_locale'=>'nl','p_creation_request_id'=>SecureRandom.uuid,'p_owner_display_name'=>'Synthetic race owner','p_owner_function_title'=>nil},owner['token'])
legacy_recipient=auth_user(base,cfg); legacy_request=SecureRandom.uuid
tag='avaryn_delete_legacy_'+SecureRandom.hex(8)
worker=pause_preparation(psql,legacy_recipient['id'],legacy_request,tag)
invitation=http(base,'POST','/rest/v1/rpc/create_stable_invitation',cfg.fetch('anon_key'),owner['token'],{
  'p_stable_id'=>legacy.fetch('stable_id'),'p_invited_email'=>legacy_recipient['email'],'p_offered_role'=>'viewer',
  'p_token_hash_hex'=>SecureRandom.hex(32),'p_target_stable_member_id'=>nil,'p_request_id'=>SecureRandom.uuid})
worker.value
raise 'email-only legacy invitation crossed preparation' unless [400,403].include?(invitation[0]) &&
  invitation[1]['message']=='ACTIVE_LEGACY_TARGET_PROFILE_REQUIRED'
count=sql(psql,"begin read only; select count(*) from public.stable_invitations where invited_email='#{legacy_recipient['email']}'; commit;").last
raise 'legacy email footprint survived losing invitation race' unless count=='0'
hard_delete(base,cfg,legacy_recipient)
raise 'legacy race recipient did not finalize' unless rpc(base,cfg,'finalize_c010_account_deletion',{'p_request_id'=>legacy_request})['status']=='anonymized'
checks << 'real legacy email-only invitation cannot appear after preparation'

first_invited=auth_user(base,cfg)
rpc(base,cfg,'create_stable_invitation',{'p_stable_id'=>legacy.fetch('stable_id'),'p_invited_email'=>first_invited['email'],
  'p_offered_role'=>'viewer','p_token_hash_hex'=>SecureRandom.hex(32),'p_target_stable_member_id'=>nil,'p_request_id'=>SecureRandom.uuid},owner['token'])
blocked=rpc(base,cfg,'prepare_c010_account_deletion',{'p_auth_user_id'=>first_invited['id'],'p_request_id'=>SecureRandom.uuid})
raise 'earlier email-only invitation was not a retention blocker' unless blocked['status']=='blocked' && blocked['code']=='LEGACY_RETENTION_REQUIRED'
expect_status(http(base,'GET','/auth/v1/user',cfg.fetch('anon_key'),first_invited['token']),[200],'blocked Auth remains valid')
raise 'blocked profile lost active API access' if profile(base,cfg,first_invited).nil?
checks << 'earlier real email-only invitation refuses without Auth/profile side effects'

# Actual Auth token + Storage HTTP. The upload policy may initially see active;
# the BEFORE trigger must wait and recheck the committed inactive profile.
uploader=auth_user(base,cfg); upload_request=SecureRandom.uuid
tag='avaryn_delete_upload_'+SecureRandom.hex(8)
worker=pause_preparation(psql,uploader['id'],upload_request,tag)
png=Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==')
path=uploader['id']+'/race.png'
upload=http(base,'POST','/storage/v1/object/avatars/'+path,cfg.fetch('anon_key'),uploader['token'],png,binary:true)
worker.value
raise 'avatar upload survived preparation' unless [400,403].include?(upload[0])
count=sql(psql,"begin read only; select count(*) from storage.objects where bucket_id='avatars' and name='#{path}'; commit;").last
raise 'avatar metadata survived rejected upload' unless count=='0'
hard_delete(base,cfg,uploader)
raise 'uploader did not finalize' unless rpc(base,cfg,'finalize_c010_account_deletion',{'p_request_id'=>upload_request})['status']=='anonymized'
checks << 'actual avatar upload blocked after waiting on preparation lock'

# Reverse order: a completed personal upload is inventoried, and finalization
# stays pending until API bytes removal and actual Auth removal both succeed.
early=auth_user(base,cfg); early_request=SecureRandom.uuid; early_path=early['id']+'/before.png'
expect_status(http(base,'POST','/storage/v1/object/avatars/'+early_path,cfg.fetch('anon_key'),early['token'],png,binary:true),[200,201],'real avatar upload before preparation')
prepared=rpc(base,cfg,'prepare_c010_account_deletion',{'p_auth_user_id'=>early['id'],'p_request_id'=>early_request})
raise 'committed avatar missing from private job' unless prepared['avatar_paths']==[early_path]
raise 'early finalize falsely completed' unless rpc(base,cfg,'finalize_c010_account_deletion',{'p_request_id'=>early_request})['status']=='auth_removal_pending'
expect_status(http(base,'DELETE','/storage/v1/object/avatars',cfg.fetch('service_key'),cfg.fetch('service_key'),{'prefixes'=>[early_path]}),[200],'exact own avatar API cleanup')
hard_delete(base,cfg,early)
raise 'clean early upload did not finalize' unless rpc(base,cfg,'finalize_c010_account_deletion',{'p_request_id'=>early_request})['status']=='anonymized'
checks << 'completed avatar inventory requires exact Storage API cleanup before finalization'

puts JSON.generate({'status'=>'PASS','checks'=>checks.length,'cases'=>checks,'synthetic_only'=>true,'existing_accounts_changed'=>false,'reset'=>false})
