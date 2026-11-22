// Uses only the maintained compatibility export in Retell 3.0.2 to join a call
// created by our backend. Never calls createWebCall or accepts an API key/video.
export function createRetellBridge(Client, notify) {
  let current = null;
  let disposed = false;
  let microphoneMuted = false;
  let releaseMix;
  let monitorMic;
  const stop = () => {
    releaseMix?.();
    microphoneMuted = false;
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
      const forward = (event) => () => { if (!disposed && current === client) notify(event, null, null); };
      for (const [name, event] of Object.entries({call_started:'started', call_ready:'audioReady',
        agent_start_talking:'agentStartedTalking', agent_stop_talking:'agentStoppedTalking',
        call_ended:'ended', error:'error'})) client.on(name, forward(event));
      client.on('update', (update) => {
        if (disposed || current !== client || !Array.isArray(update?.transcript)) return;
        const turns = update.transcript
          .filter(turn => (turn?.role === 'agent' || turn?.role === 'user') &&
            typeof turn.content === 'string' && !turn.metadata?.is_backchannel)
          .map(({role, content}) => ({role, content}));
        notify('transcript', JSON.stringify(turns), update.turntaking === 'agent_turn');
      });
      try {
        await client.startCall({accessToken: config.accessToken, callId: config.callId,
          ...(Array.isArray(config.iceServers) && config.iceServers.length ? {iceServers: config.iceServers.map(({urls,username,credential}) => ({urls,...(username?{username}:{}),...(credential?{credential}:{})}))} : {}),
          transport: config.transport, ...(config.url ? {url: config.url} : {}),
          baseURL:'https://api.retellai.com', sampleRate:24000, emitRawAudioSamples:config.monitorAudio === true});
      } catch (_) { if (!disposed && current === client) notify('error', null, null); }
      finally { if (disposed || current !== client) { client.removeAllListeners(); client.stopCall(); } }
    },
    async monitorAudio(signal, onLoss) {
      const owner = current;
      const analyser = owner?.analyzerComponent?.analyser;
      if (disposed || !analyser || signal.aborted) throw new Error('Audio unavailable');
      releaseMix?.();
      const mic = await navigator.mediaDevices.getUserMedia({audio: {
        channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: true
      }, video: false});
      let source, mixed;
      const release = () => {
        signal.removeEventListener('abort', release);
        if (releaseMix === release) { releaseMix = undefined; monitorMic = undefined; }
        mic.getTracks().forEach(track => track.stop());
        source?.disconnect();
        if (mixed) {
          try { analyser.disconnect(mixed); } catch (_) {}
          mixed.stream.getTracks().forEach(track => track.stop());
        }
      };
      try {
        if (disposed || current !== owner || signal.aborted) throw new Error('Audio ended');
        releaseMix = release;
        signal.addEventListener('abort', release, {once:true});
        monitorMic = mic.getAudioTracks()[0];
        monitorMic.enabled = !microphoneMuted;
        monitorMic.addEventListener('ended', onLoss, {signal});
        monitorMic.addEventListener('mute', onLoss, {signal});
        const context = analyser.context;
        await context.resume();
        if (signal.aborted || current !== owner) throw new Error('Audio ended');
        source = context.createMediaStreamSource(mic);
        mixed = context.createMediaStreamDestination();
        source.connect(mixed);
        analyser.connect(mixed);
        return mixed.stream.getAudioTracks()[0];
      } catch (error) { release(); throw error; }
    },
    async resumeAudio() { if (current && !disposed) await current.startAudioPlayback(); },
    setMicrophoneMuted(muted) {
      if (!current || disposed) return false;
      microphoneMuted = muted;
      if (monitorMic) monitorMic.enabled = !muted;
      if (muted) current.mute();
      else current.unmute();
      return true;
    },
    stop,
    dispose() { disposed = true; stop(); },
  };
}
