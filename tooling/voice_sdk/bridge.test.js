import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import test from 'node:test';
import {createRetellBridge} from './bridge.js';
class FakeClient extends EventEmitter {
  static instances=[];
  constructor(){super();FakeClient.instances.push(this);this.stops=0;}
  async startCall(options){this.options=options;if(this.gate)await this.gate;}
  stopCall(){this.stops++;this.emit('call_ended');}
  async startAudioPlayback(){this.played=true;}
}
const credential={accessToken:'test-only-token',callId:'call-test',transport:'gateway',apiKey:'forbidden-test-key',video:'forbidden-test-image'};
test('join options are audio-only and no live state is manufactured',async()=>{
  const events=[];const bridge=createRetellBridge(FakeClient,e=>events.push(e));
  await bridge.start(credential);const client=FakeClient.instances.at(-1);
  assert.deepEqual(events,[]);
  assert.deepEqual(Object.keys(client.options).sort(),['accessToken','baseURL','callId','emitRawAudioSamples','sampleRate','transport'].sort());
  assert.equal(client.options.emitRawAudioSamples,false);
  client.emit('call_started');client.emit('agent_start_talking');
  assert.deepEqual(events,['started','agentStartedTalking']);
  await bridge.resumeAudio();assert.equal(client.played,true);bridge.dispose();
});
test('raw error and transcript payloads are never forwarded',async()=>{
  const events=[];const bridge=createRetellBridge(FakeClient,e=>events.push(e));await bridge.start(credential);
  const client=FakeClient.instances.at(-1);client.emit('update',{transcript:'test-only-sensitive'});client.emit('error',{access_token:'test-only-secret'});
  assert.deepEqual(events,['error']);bridge.dispose();
});
test('stop and replacement fence old events; cleanup does not emit completion',async()=>{
  const events=[];const bridge=createRetellBridge(FakeClient,e=>events.push(e));await bridge.start(credential);
  const old=FakeClient.instances.at(-1);const stale=old.listeners('call_started')[0];
  await bridge.start(credential);stale();old.emit('call_ended');assert.deepEqual(events,[]);
  bridge.dispose();assert.deepEqual(events,[]);assert.ok(old.stops>=1);
  await assert.rejects(bridge.start(credential));
});
test('late provider connect is stopped after cancellation',async()=>{
  let resolve;const gate=new Promise(r=>resolve=r);
  class PendingClient extends FakeClient {async startCall(options){this.options=options;await gate;}}
  const bridge=createRetellBridge(PendingClient,()=>assert.fail('stale event'));
  const pending=bridge.start(credential);const client=FakeClient.instances.at(-1);bridge.dispose();resolve();await pending;
  assert.equal(client.stops,2);
});
