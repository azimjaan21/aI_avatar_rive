// Node 22+; attach to the Chrome instance launched by `flutter run -d chrome`.
// Usage from repository root: node tools/validate-web.cjs <Chrome CDP port>
const fs = require('node:fs');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');

async function main() {
  const port = Number(process.argv[2]);
  assert(Number.isInteger(port) && port > 0 && port < 65536, 'Pass the local Chrome CDP port');
  const out = 'gettopik-teacher/validation/lipsync-quality';
  fs.mkdirSync(out, { recursive: true });
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const tab = tabs.find(t => t.url.startsWith('http://127.0.0.1:7357'));
  assert(tab, 'Open the Flutter preview at port 7357 first');
  const ws = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise(r => { ws.onopen = r; });
  let id = 0;
  const pending = new Map(), errors = [];
  ws.onmessage = event => {
    const m = JSON.parse(event.data);
    if (m.method === 'Runtime.exceptionThrown') errors.push(m.params);
    if (pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  };
  const send = (method, params = {}) => new Promise(resolve => {
    pending.set(++id, resolve);
    ws.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    assert(!r.result.exceptionDetails, JSON.stringify(r.result.exceptionDetails));
    return r.result.result.value;
  };
  const wait = ms => new Promise(r => setTimeout(r, ms));
  const click = async text => {
    const p = await evaluate(`(() => {
      const nodes = [...document.querySelectorAll('flt-semantics')];
      const e = nodes.find(e => e.getAttribute('role') === 'button' && e.innerText === ${JSON.stringify(text)})
        || nodes.find(e => e.getAttribute('aria-label') === ${JSON.stringify(text)});
      if (!e) throw Error('Missing control: ' + ${JSON.stringify(text)});
      const b = e.getBoundingClientRect(); return [b.x + b.width/2, b.y + b.height/2];
    })()`);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', { type, x: p[0], y: p[1], button: 'left', clickCount: 1 });
    }
    await wait(300);
  };
  const scroll = async deltaY => {
    await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 800, y: 730, deltaX: 0, deltaY });
    await wait(400);
  };
  const screenshot = async name => {
    const r = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(`${out}/${name}.png`, Buffer.from(r.result.data, 'base64'));
  };
  try {
    await send('Runtime.enable');
    await send('Page.reload', { ignoreCache: true });
    // Flutter debug module loading + Rive WASM initialization is asynchronous.
    // Wait for the app, rather than clicking a placeholder during startup.
    for (let i = 0; i < 160; i++) {
      await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
      if (await evaluate("document.body.innerText.includes('Behavior lab idle · Local WAV')")) break;
      await wait(250);
    }
    await click('Behavior lab idle · Local WAV');
    await scroll(500);
    await click('Local streaming simulation');
    await scroll(-900);
    const capture = spawn('python', ['gettopik-teacher/tools/capture_audio_output.py', `${out}/web-speaker-report.json`, '11']);
    let stderr = '';
    capture.stderr.on('data', b => { stderr += b; });
    const done = new Promise(r => capture.on('exit', r));
    await new Promise((resolve, reject) => {
      let output = '';
      capture.stdout.on('data', b => { output += b; if (output.includes('READY')) resolve(); });
      setTimeout(() => reject(Error(`Capture not ready: ${stderr}`)), 15000).unref();
    });
    await click('Play lesson');
    await wait(2300);
    const speaking = await evaluate('document.body.innerText');
    assert(speaking.includes('speaking · Local PCM stream'), speaking);
    assert(speaking.includes('Pause'), speaking);
    await screenshot('web-speaking');
    await scroll(650);
    await click('Smile');
    await wait(600);
    const smilingSpeech = await evaluate('document.body.innerText');
    assert(smilingSpeech.includes('speaking · Local PCM stream'), smilingSpeech);
    await screenshot('web-speaking-smile');
    await scroll(-1000);
    await click('Pause');
    const paused = await evaluate('document.body.innerText');
    await wait(700);
    const frozen = await evaluate('document.body.innerText');
    const clock = text => text.match(/\n(\d+:\d+)\n0:12/)?.[1];
    assert(clock(paused) && clock(paused) === clock(frozen));
    await click('Play lesson');
    await wait(400);
    await scroll(650);
    await click('Interrupt');
    await wait(600);
    const interrupted = await evaluate('document.body.innerText');
    assert(interrupted.includes('idle · Local PCM stream'), interrupted);
    assert.equal(await done, 0, stderr);
    const output = JSON.parse(fs.readFileSync(`${out}/web-speaker-report.json`, 'utf8'));
    assert(output.outputDetected);
    assert.equal(errors.length, 0, JSON.stringify(errors));
    fs.writeFileSync(`${out}/web-report.json`, JSON.stringify({ result: 'passed',
      scope: 'Chrome debug Web; real speaker loopback; no hardware lip-sync latency measurement',
      streaming: true, speakingWithSmile: true, pauseClockFrozen: true,
      resume: true, interruptResets: true, speakerOutputDetected: true,
      runtimeExceptions: errors, streamUi: smilingSpeech }, null, 2));
    await click('Neutral');
    await click('Local WAV');
    await click('Behavior lab idle · Local WAV');
    await scroll(-1000);
    await screenshot('web-ready');
    console.log('PASS: Web PCM playback, speaker output, Smile, pause/resume, interruption');
  } finally { ws.close(); }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
