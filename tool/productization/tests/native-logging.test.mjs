import test from 'node:test';
import assert from 'node:assert/strict';
import capacitor from '../../../apps/avaryn/capacitor.config.json' with {type:'json'};

// Native bridge debug logs include SecureStorage request/response payloads.
// Test builds use real Pilot sessions, so the production default is insufficient.
test('native bridge logging is disabled even for signed debug test builds',()=>{
 assert.equal(capacitor.loggingBehavior,'none');
});
for(const platform of ['android','ios'])test(platform+' cannot override the private bridge logging boundary',()=>{
 assert.equal(capacitor[platform]?.loggingBehavior??capacitor.loggingBehavior,'none');
});
