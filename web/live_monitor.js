// One instance per authenticated socket. Closing it never stops borrowed tracks.
window.openSkillSenseMonitor = function(url, role, camera, voice, video, reconnect, soundEnabled, report) {
  const socket = new WebSocket(url);
  let config, pc, controller, generation, closed = false, sound = soundEnabled;
  let watchdog, negotiation, borrowedCamera;
  const began = performance.now();
  function dropPeer() {
    clearTimeout(negotiation);
    controller?.abort();
    controller = null;
    pc?.close();
    pc = null;
    borrowedCamera = null;
    if (video) { video.onplaying = null; video.pause(); video.srcObject = null; }
  }
  function finish(state) {
    if (closed) return;
    closed = true;
    clearTimeout(watchdog);
    dropPeer();
    window.removeEventListener('pagehide', leave);
    socket.close();
    report(state);
  }
  const leave = () => finish('ended');
  window.addEventListener('pagehide', leave);
  function heartbeat() {
    clearTimeout(watchdog);
    watchdog = setTimeout(() => finish('reconnecting'), 8000);
  }
  heartbeat();
  async function sendDescription(peer, description) {
    await peer.setLocalDescription(description);
    if (peer.iceGatheringState !== 'complete') {
      await new Promise(resolve => {
        const done = () => {
          if (peer.iceGatheringState === 'complete' || controller?.signal.aborted || peer !== pc) {
            peer.removeEventListener('icegatheringstatechange', done);
            resolve();
          }
        };
        peer.addEventListener('icegatheringstatechange', done);
        controller?.signal.addEventListener('abort', resolve, {once: true});
        done();
      });
    }
    if (peer === pc && !closed) socket.send(JSON.stringify({
      type: description.type, generation, sdp: peer.localDescription.sdp
    }));
  }
  async function presence(next) {
    if (generation === next) {
      if (borrowedCamera && borrowedCamera !== camera()) finish('reconnecting');
      return;
    }
    dropPeer();
    generation = next;
    if (!next) { report('waiting'); return; }
    report('connecting');
    const peer = pc = new RTCPeerConnection(config);
    controller = new AbortController();
    negotiation = setTimeout(() => finish('reconnecting'), 22000);
    peer.onconnectionstatechange = async () => {
      if (pc !== peer || closed) return;
      if (['failed','disconnected'].includes(peer.connectionState)) finish('reconnecting');
      if (peer.connectionState === 'connected') {
        if (role === 'camera') { clearTimeout(negotiation); report('live'); }
      }
    };
    if (role === 'viewer') {
      const stream = new MediaStream();
      video.srcObject = stream;
      video.muted = !sound;
      video.onplaying = async () => {
        if (pc !== peer || closed) return;
        clearTimeout(negotiation);
        report('live');
        if (!peer.measured) {
          peer.measured = true;
          const stats = await peer.getStats().catch(() => null);
          if (pc !== peer || !stats) return;
          const transport = [...stats.values()].find(v => v.selectedCandidatePairId);
          const pair = stats.get(transport?.selectedCandidatePairId);
          const relay = [pair?.localCandidateId, pair?.remoteCandidateId].some(id => stats.get(id)?.candidateType === 'relay');
          if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({type:'metric', generation,
            milliseconds: Math.round(performance.now()-began), relay, reconnect}));
        }
      };
      peer.ontrack = ({track}) => {
        if (pc !== peer) return;
        stream.addTrack(track);
        if (stream.getTracks().length === 2) video.play().catch(async () => {
          if (pc !== peer) return;
          sound = false;
          video.muted = true;
          report('enableSound');
          await video.play().catch(() => {});
        });
      };
    } else {
      const track = borrowedCamera = camera();
      if (!track || !voice) throw new Error('Media unavailable');
      let audio;
      try { audio = await voice.monitorAudio(controller.signal, () => {
        if (pc === peer) finish('reconnecting');
      }); }
      catch (error) { if (pc === peer) throw error; return; }
      if (pc !== peer) return;
      const stream = new MediaStream([track, audio]);
      for (const item of [track, audio]) peer.addTransceiver(item, {direction:'sendonly', streams:[stream]});
      await sendDescription(peer, await peer.createOffer());
    }
  }
  socket.onmessage = async event => {
    let activeGeneration = generation;
    try {
      if (closed) return;
      const data = JSON.parse(event.data);
      if (data.type === 'ready') { config = data.config; report('waiting'); }
      else if (data.type === 'presence') { heartbeat(); activeGeneration = data.generation; await presence(data.generation); }
      else if (pc && data.generation === generation) {
        const peer = pc;
        await peer.setRemoteDescription({type:data.type, sdp:data.sdp});
        if (peer === pc && data.type === 'offer') {
          for (const transceiver of peer.getTransceivers()) transceiver.direction = 'recvonly';
          await sendDescription(peer, await peer.createAnswer());
        }
      }
    } catch (_) { if (!closed && activeGeneration === generation) finish('reconnecting'); }
  };
  socket.onclose = event => finish(event.code === 4410 ? 'ended' :
    event.code === 4401 ? 'renewing' : event.code === 4403 ? 'unavailable' :
    event.code === 4409 && role === 'viewer' && !reconnect ? 'busy' : 'reconnecting');
  return {
    dispose() { finish('ended'); },
    async sound(enabled) {
      sound = enabled;
      if (video) {
        video.muted = !enabled;
        try { await video.play(); return true; } catch (_) {
          sound = false;
          video.muted = true;
          await video.play().catch(() => {});
          return false;
        }
      }
      return false;
    }
  };
};
