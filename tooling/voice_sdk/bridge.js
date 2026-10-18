// Uses only the maintained compatibility export in Retell 3.0.2 to join a call
// created by our backend. Never calls createWebCall or accepts an API key/video.
export function createRetellBridge(Client, notify) {
  let current = null;
  let disposed = false;
  const stop = () => {
    const client = current;
    current = null;
    if (client) { client.removeAllListeners(); client.stopCall(); }
  };
  return {
    async start(config) {
      if (disposed || !config || typeof config.accessToken !== 'string' || !config.accessToken ||
          typeof config.callId !== 'string' || !['gateway', 'livekit'].includes(config.transport)) {
        throw new Error('Backend voice credentials are unavailable.');
      }
      stop();
      const client = new Client(); current = client;
      const forward = (event) => () => { if (!disposed && current === client) notify(event); };
      for (const [name, event] of Object.entries({call_started:'started', call_ready:'audioReady',
        agent_start_talking:'agentStartedTalking', agent_stop_talking:'agentStoppedTalking',
        call_ended:'ended', error:'error'})) client.on(name, forward(event));
      try {
        await client.startCall({accessToken: config.accessToken, callId: config.callId,
          ...(Array.isArray(config.iceServers) && config.iceServers.length ? {iceServers: config.iceServers.map(({urls,username,credential}) => ({urls,...(username?{username}:{}),...(credential?{credential}:{})}))} : {}),
          transport: config.transport, ...(config.url ? {url: config.url} : {}),
          baseURL:'https://api.retellai.com', sampleRate:24000, emitRawAudioSamples:false});
      } catch (_) { if (!disposed && current === client) notify('error'); }
      finally { if (disposed || current !== client) { client.removeAllListeners(); client.stopCall(); } }
    },
    async resumeAudio() { if (current && !disposed) await current.startAudioPlayback(); },
    stop,
    dispose() { disposed = true; stop(); },
  };
}
