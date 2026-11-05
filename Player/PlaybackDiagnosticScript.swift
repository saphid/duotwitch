import Foundation

enum PlaybackDiagnosticScript {
    static func source(session: String) -> String {
        // The generated UUID is the only interpolated value, never a URL/token.
        let literal = String(data: try! JSONEncoder().encode(session), encoding: .utf8)!
        return """
        (() => {
          if (location.protocol !== 'https:' || location.hostname !== 'player.twitch.tv' ||
              (location.port && location.port !== '443')) return;
          const session = \(literal);
          window.webkit?.messageHandlers.playbackDiagnostic?.postMessage({session, kind:'observerReady', hidden:document.hidden});
          const observed = new WeakMap();
          let nextVideo = 0;
          function attach(v) {
            const restart = observed.get(v);
            if (restart) { restart(); return; }
            const video = ++nextVideo;
            let samples = 0;
            let timer = null;
            const report = kind => {
              const quality = v.getVideoPlaybackQuality ? v.getVideoPlaybackQuality() : null;
              const handler = window.webkit && window.webkit.messageHandlers.playbackDiagnostic;
              if (!handler) return;
              handler.postMessage({session, kind, video, time:v.currentTime,
                paused:v.paused, ended:v.ended, muted:v.muted, volume:v.volume,
                ready:v.readyState, network:v.networkState, rate:v.playbackRate,
                width:v.videoWidth, height:v.videoHeight, hidden:document.hidden,
                error:v.error ? v.error.code : 0,
                decoded:quality ? quality.totalVideoFrames : -1,
                dropped:quality ? quality.droppedVideoFrames : -1});
            };
            const visibility = () => report('visibility');
            function start() {
              if (timer !== null || !v.isConnected) return;
              samples = 0;
              document.addEventListener('visibilitychange', visibility);
              report('attached');
              timer = setInterval(() => {
                if (!v.isConnected) {
                  clearInterval(timer);
                  timer = null;
                  document.removeEventListener('visibilitychange', visibility);
                  report('detached'); return;
                }
                // High resolution around a stop, slower steady-state sampling.
                if (samples++ < 40 || samples % 10 === 0) report('sample');
              }, 250);
            }
            ['play','playing','pause','waiting','stalled','ended','error','emptied','loadedmetadata']
              .forEach(kind => v.addEventListener(kind, () => { start(); samples = 0; report(kind); }));
            // Keep one listener set and stable ID when the same node is reused.
            observed.set(v, start);
            start();
          }
          const inspect = () => document.querySelectorAll('video').forEach(attach);
          // Capture discovers dynamically inserted videos without scanning every DOM mutation.
          document.addEventListener('loadstart', event => {
            if (event.target instanceof HTMLVideoElement) attach(event.target);
          }, true);
          inspect();
          window.addEventListener('pageshow', inspect);
        })();
        """
    }
}
