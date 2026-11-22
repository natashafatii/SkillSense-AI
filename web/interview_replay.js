(() => {
  const chunkLimit = 2 * 1024 * 1024;
  const queueLimit = 8 * 1024 * 1024;
  const formats = [
    'video/webm;codecs=vp8', 'video/webm;codecs=vp9',
    'video/mp4;codecs=avc1.42001f', 'video/mp4'
  ];
  const format = () => globalThis.MediaRecorder &&
    formats.find(type => MediaRecorder.isTypeSupported(type));

  window.skillSenseReplaySupported = () => Boolean(format() && globalThis.crypto?.subtle);

  window.skillSenseStartReplay = (track, notify, upload) => {
    const recorder = new MediaRecorder(new MediaStream([track]), {
      mimeType: format(), videoBitsPerSecond: 500000
    });
    const nonce = crypto.randomUUID();
    const start = performance.now();
    let stopTime;
    let bytes = 0, count = 0, dropped = false, uploadFailed = false, complete = true;
    let queued = Promise.resolve();
    const listeners = new AbortController();

    function stop(normal) {
      complete &&= normal;
      if (recorder.state === 'inactive' || stopTime !== undefined) return;
      stopTime = performance.now();
      recorder.stop();
    }

    recorder.ondataavailable = ({data}) => {
      if (!data.size || dropped || uploadFailed) return;
      if (data.size > chunkLimit || bytes + data.size > queueLimit) {
        complete = false;
        // This blob was dropped. Finish uploading the contiguous queued prefix.
        stop(false);
        dropped = true;
        return;
      }
      bytes += data.size;
      const elapsed = Math.round((stopTime ?? performance.now()) - start);
      queued = queued.then(async () => {
        try {
          if (uploadFailed) return;
          const payload = new Uint8Array(await data.arrayBuffer());
          const digest = [...new Uint8Array(await crypto.subtle.digest('SHA-256', payload))]
            .map(value => value.toString(16).padStart(2, '0')).join('');
          if (!await upload(count, elapsed, digest, payload)) {
            uploadFailed = true;
            stop(false);
            return;
          }
          count++;
        } catch (_) {
          uploadFailed = true;
          stop(false);
        } finally {
          bytes -= data.size;
        }
      });
    };
    recorder.onerror = () => stop(false);
    recorder.onstop = () => {
      listeners.abort();
      const elapsed = Math.round((stopTime ?? performance.now()) - start);
      queued.then(() => notify(JSON.stringify({
        elapsed_ms: elapsed,
        count,
        complete: complete && !dropped && !uploadFailed
      }))).catch(() => {});
    };
    track.addEventListener('ended', () => stop(false), {signal: listeners.signal});
    track.addEventListener('mute', () => stop(false), {signal: listeners.signal});
    recorder.start(4000);
    return {nonce, start, mime: recorder.mimeType.split(';')[0], stop};
  };
})();
