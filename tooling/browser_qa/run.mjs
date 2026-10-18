// Test-only isolated headless browser runner. Never attaches to a user's profile.
import {spawn,spawnSync} from 'node:child_process';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import os from 'node:os';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const sdk=process.env.FLUTTER_ROOT;
if(!sdk)throw Error('Set FLUTTER_ROOT to the installed Flutter SDK');
const dart=path.join(sdk,'bin/cache/dart-sdk/bin/dart.exe');
const browserPath=process.env.QA_BROWSER || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const output=path.join(root,'.dart_tool/interview-analysis-browser');
const profile=path.join(root,'.dart_tool',`interview-analysis-qa-profile-${Date.now()}`);
const reportName=process.env.QA_REPORT || 'interview_analysis_validation_browser';
if(!/^[a-zA-Z0-9_-]+$/.test(reportName))throw Error('Invalid QA report name');
const report={fixture_only:true,physical_media:false,real_provider:false,real_backend:false,
  platform:{platform:os.platform(),release:os.release(),arch:os.arch(),logical_processors:os.availableParallelism()}};
let host,browser,cdp;
let sessionForDiagnostics;
let consoleMessages=0,sensitiveConsoleMessages=0,exceptions=0,blockedExternalRequests=0;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(fn,ms=30000){const end=Date.now()+ms;while(Date.now()<end){const result=await fn();if(result)return result;await sleep(100);}throw Error('QA timeout');}
class CDP {
  constructor(ws){this.ws=ws;this.id=0;this.pending=new Map();this.handlers=[];
    ws.addEventListener('message',({data})=>{const msg=JSON.parse(data);
      if(msg.id){const task=this.pending.get(msg.id);if(task){this.pending.delete(msg.id);clearTimeout(task.timer);msg.error?task.reject(Error('CDP operation failed')):task.resolve(msg.result);}}
      else for(const handler of this.handlers)handler(msg);
    });
  }
  call(method,params={},sessionId){return new Promise((resolve,reject)=>{const id=++this.id;
    const timer=setTimeout(()=>{this.pending.delete(id);reject(Error('CDP timeout'));},10000);
    this.pending.set(id,{resolve,reject,timer});this.ws.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}));});}
}
function processCpu(pid){
  const script=`$qaAll=Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId; $qaIds=@(${pid}); do { $qaNext=@($qaAll | Where-Object { $qaIds -contains $_.ParentProcessId -and $qaIds -notcontains $_.ProcessId } | ForEach-Object { $_.ProcessId }); $qaIds+=$qaNext } while ($qaNext.Count -gt 0); @(Get-Process -Id $qaIds -ErrorAction SilentlyContinue | ForEach-Object { @{pid=$_.Id;seconds=$_.TotalProcessorTime.TotalSeconds} }) | ConvertTo-Json -Compress`;
  const result=spawnSync('powershell.exe',['-NoProfile','-Command',script],{windowsHide:true,encoding:'utf8',timeout:10000});
  try {const data=JSON.parse(result.stdout.trim());return {processes:Array.isArray(data)?data:[data],sampled_at_ms:Date.now()};}catch{return null;}
}
try {
  await mkdir(profile,{recursive:true});
  const fontPath=path.join(output,'assets/FontManifest.json');
  const fonts=JSON.parse(await readFile(fontPath,'utf8'));
  if(!fonts.some(font=>font.family==='Roboto')){
    fonts.push({family:'Roboto',fonts:[{asset:'assets/fonts/Inter.ttf'}]});
    await writeFile(fontPath,JSON.stringify(fonts));
  }
  report.test_font_alias='Local Inter font registered as Roboto only in the isolated test output; no CDN fonts.';
  // Minimal local-only test bootstrap. Production Clerk/provider loaders are not run.
  // Flutter registers transitive passkeys even for this media-only target.
  // Stub registration only; this isolated target never runs authentication.
  report.authentication='not_exercised; test-only passkeys registration stub';
  await writeFile(path.join(output,'index.html'),'<!doctype html><meta charset="utf-8"><title>Interview Analysis TEST ONLY</title><script>window.PasskeyAuthenticator={init(){}};</script><script src="flutter_bootstrap.js" async></script>');
  host=spawn(dart,[path.join(root,'tooling/browser_qa/serve.dart'),output],{cwd:root,windowsHide:true,stdio:['ignore','pipe','ignore'],env:{...process.env,CI:'true',FLUTTER_SUPPRESS_ANALYTICS:'true'}});
  let ready='';host.stdout.on('data',data=>ready+=data.toString());
  const port=await until(()=>{try{return JSON.parse(ready.split('\n')[0]).port;}catch{return null;}});
  const base=`http://127.0.0.1:${port}`;
  report.stage='browser_start';
  browser=spawn(browserPath,['--headless=new','--no-first-run','--no-default-browser-check',
    '--disable-background-networking','--disable-component-update','--disable-sync','--disable-extensions',
    '--disable-background-mode',`--user-data-dir=${profile}`,'--remote-debugging-port=0','about:blank'],
    {windowsHide:true,stdio:'ignore'});
  const debugPort=await until(async()=>{try{return (await readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch{return null;}});
  const version=await (await fetch(`http://127.0.0.1:${debugPort}/json/version`)).json();
  report.browser={executable:path.basename(browserPath),product:version.Browser,engine:version['V8-Version'],user_agent:version['User-Agent'],headless:true,gpu_disabled:false};
  const ws=new WebSocket(version.webSocketDebuggerUrl);await new Promise((r,j)=>{ws.addEventListener('open',r,{once:true});ws.addEventListener('error',j,{once:true});});
  cdp=new CDP(ws);
  const {targetId}=await cdp.call('Target.createTarget',{url:'about:blank'});
  const {sessionId}=await cdp.call('Target.attachToTarget',{targetId,flatten:true});
  sessionForDiagnostics=sessionId;
  cdp.handlers.push(msg=>{
    if(msg.sessionId!==sessionId)return;
    if(msg.method==='Network.webSocketHandshakeResponseReceived')report.socket_handshake_status=msg.params.response.status;
    if(msg.method==='Network.webSocketFrameError')report.socket_error='websocket_frame_error';
    if(msg.method==='Runtime.consoleAPICalled'){
      consoleMessages++;
      const text=msg.params.args.map(a=>typeof a.value==='string'?a.value:'').join(' ');
      if(/data:image|\/9j\/|Bearer\s|ticket=|test-only-(?:ticket|provider-token)/i.test(text))sensitiveConsoleMessages++;
    }
    if(msg.method==='Runtime.exceptionThrown'){
      exceptions++;
      report.last_exception_type=msg.params.exceptionDetails.exception?.className || 'Exception';
      const description=msg.params.exceptionDetails.exception?.description || '';
      report.last_exception_category=/font|Roboto/i.test(description)?'font':/WebGL/i.test(description)?'webgl':/fetch/i.test(description)?'fetch':/CanvasKit/i.test(description)?'canvaskit':'other';
      if(report.stage==='flutter_boot')report.boot_exception_summary=description.split('\n')[0]
        .replace(/https?:\/\/\S+/g,'<url>').replace(/[A-Za-z0-9+/=_-]{40,}/g,'<redacted>').slice(0,240);
      if(report.stage==='flutter_boot')report.boot_stack=description.split('\n').slice(1,9)
        .map(line=>line.replace(/https?:\/\/[^/]+/g,'<local-origin>').replace(/\?[^\s)]*/g,'?<redacted>'));
    }
    if(msg.method==='Fetch.requestPaused'){
      const request=msg.params;
      const url=new URL(request.request.url);
      if(['127.0.0.1','localhost'].includes(url.hostname) || ['data:','blob:'].includes(url.protocol)){
        void cdp.call('Fetch.continueRequest',{requestId:request.requestId},sessionId).catch(()=>{});
      }else{blockedExternalRequests++;
        report.blocked_external_hosts=[...new Set([...(report.blocked_external_hosts||[]),url.hostname])];
        void cdp.call('Fetch.failRequest',{requestId:request.requestId,errorReason:'BlockedByClient'},sessionId).catch(()=>{});}
    }
  });
  await cdp.call('Runtime.enable',{},sessionId);await cdp.call('Page.enable',{},sessionId);await cdp.call('Network.enable',{},sessionId);
  await cdp.call('Performance.enable',{},sessionId);
  await cdp.call('Fetch.enable',{patterns:[{urlPattern:'*',requestStage:'Request'}]},sessionId);
  const evaluate=async expression=>(await cdp.call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true,userGesture:true},sessionId)).result.value;
  await cdp.call('Page.navigate',{url:base},sessionId);await cdp.call('Target.activateTarget',{targetId});
  report.stage='flutter_boot';
  await until(async()=>{if(exceptions)throw Error('Browser boot exception');return await evaluate('window.__interviewAnalysisQaPhase === "idle"');},60000);
  report.permission_query=await evaluate(`(async()=>{const result={physical_acquisition_attempted:false};for(const name of ['camera','microphone']){try{result[name]=(await navigator.permissions.query({name})).state;}catch{result[name]='unavailable';}}try{const devices=await navigator.mediaDevices.enumerateDevices();result.video_inputs=devices.filter(d=>d.kind==='videoinput').length;result.audio_inputs=devices.filter(d=>d.kind==='audioinput').length;}catch{result.device_enumeration='unavailable';}return result;})()`);
  // Test-only entrypoint with CDP userGesture; no hardware permission acquisition.
  await evaluate('window.__interviewAnalysisQaStart()');
  report.stage='fixture_start';
  await until(async()=>await evaluate('window.__interviewAnalysisQaPhase === "sampling"'),30000);
  const before=await cdp.call('Performance.getMetrics',{},sessionId);const cpuBefore=processCpu(browser.pid);const started=Date.now();
  await until(async()=>await evaluate('window.__interviewAnalysisQaPhase === "await_background" || window.__interviewAnalysisQaPhase === "done"'),30000);
  const ended=Date.now();const cpuAfter=processCpu(browser.pid);const after=await cdp.call('Performance.getMetrics',{},sessionId);
  const metric=(data,name)=>data.metrics.find(m=>m.name===name)?.value;
  report.performance={wall_seconds:(ended-started)/1000,
    renderer_main_thread_busy_percent:100*(metric(after,'TaskDuration')-metric(before,'TaskDuration'))/(metric(after,'Timestamp')-metric(before,'Timestamp')),
    renderer_js_heap_bytes:metric(after,'JSHeapUsedSize'),
    renderer_metrics_wall_seconds:metric(after,'Timestamp')-metric(before,'Timestamp')};
  if(cpuBefore && cpuAfter){
    const baseline=new Map(cpuBefore.processes.map(p=>[p.pid,p.seconds]));
    const seconds=cpuAfter.processes.reduce((sum,p)=>sum+Math.max(0,p.seconds-(baseline.get(p.pid)??0)),0);
    const cpuWindow=(cpuAfter.sampled_at_ms-cpuBefore.sampled_at_ms)/1000;
    report.performance.isolated_browser_cpu_seconds=seconds;
    report.performance.isolated_browser_one_core_equivalent_percent=100*seconds/cpuWindow;
    report.performance.cpu_window_seconds=cpuWindow;
    report.performance.cpu_note='Approximate live isolated browser process tree, including collection overhead; exited child CPU is not included.';
  }else report.performance.process_cpu='unavailable';
  report.stage='background';
  const other=await cdp.call('Target.createTarget',{url:'about:blank'});await cdp.call('Target.activateTarget',{targetId:other.targetId});await sleep(700);
  report.tab_background_observed=await evaluate('document.hidden');
  await cdp.call('Target.activateTarget',{targetId});await cdp.call('Page.bringToFront',{},sessionId);await sleep(300);
  await evaluate('window.__interviewAnalysisQaContinue="background_done"');
  await until(async()=>await evaluate('window.__interviewAnalysisQaPhase === "done"'),30000);
  report.probe=await evaluate('window.__interviewAnalysisQaResult');
  report.transport_fixture=await (await fetch(`${base}/qa/metrics`)).json();
  report.console={messages:consoleMessages,sensitive_messages:sensitiveConsoleMessages,unhandled_exceptions:exceptions,external_requests_blocked:blockedExternalRequests};
  report.passed=report.probe?.passed===true && sensitiveConsoleMessages===0 && exceptions===0 && report.transport_fixture.active_sockets===0;
}catch(error){report.passed=false;report.runner_failure=error.message==='QA timeout'?'QA timeout':error.constructor.name;
  if(cdp && sessionForDiagnostics){try{report.boot_diagnostics=(await cdp.call('Runtime.evaluate',{expression:'({ready:document.readyState,views:document.querySelectorAll("flutter-view").length,phase:window.__interviewAnalysisQaPhase||null})',returnByValue:true},sessionForDiagnostics)).result.value;}catch{}}
}
finally {
  report.console={messages:consoleMessages,sensitive_messages:sensitiveConsoleMessages,unhandled_exceptions:exceptions,external_requests_blocked:blockedExternalRequests};
  if(cdp){try{await cdp.call('Browser.close');}catch{}cdp.ws.close();}
  browser?.kill();host?.kill();
  await writeFile(path.join(root,'verification',`${reportName}.json`),JSON.stringify(report,null,2));
  process.stdout.write(JSON.stringify(report,null,2)+'\n');
  if(!report.passed)process.exitCode=1;
}
