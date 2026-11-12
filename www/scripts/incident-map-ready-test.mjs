import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../components/TrailReportMap.tsx', import.meta.url), 'utf8'), {
  compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX},
}).outputText;
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function session({runtimeFails=false}={}) {
  const refs=[],effects=[],timers=new Map(),states=[],sources=[];
  let resolveRoute,rejectRoute,instance,settled=0,timerId=0;
  const route=new Promise((resolve,reject)=>{resolveRoute=resolve;rejectRoute=reject;});
  class FakeMap {
    constructor(){instance=this;this.handlers=new Map();this.onceHandlers=new Map();}
    on(name,fn){this.handlers.set(name,fn);}
    once(name,fn){this.onceHandlers.set(name,fn);}
    emit(name,event={}){this.handlers.get(name)?.(event);const fn=this.onceHandlers.get(name);this.onceHandlers.delete(name);fn?.(event);}
    addControl(){} isStyleLoaded(){return false;}
    addSource(name){sources.push(name);} addLayer(){} triggerRepaint(){}
    fitBounds(_,options){this.fitOptions=options;} remove(){this.removed=true;}
  }
  const gl={Map:FakeMap,NavigationControl:class{},LngLatBounds:class{extend(){}}};
  const dependencies={
    react:{useRef:value=>{const ref={current:value};refs.push(ref);return ref;},useState:value=>[value,next=>states.push(next)],useEffect:fn=>effects.push(fn)},
    'react/jsx-runtime':{jsx:()=>null,jsxs:()=>null},
    '@/lib/trail-reports':{reportCategories:{},reportStatuses:[]},
    '@/components/ReportReview':{reportStatusLabels:{}},
    '@/lib/trail-route':{loadTrailRoute:()=>route},
    '@/lib/report-map-runtime':{preloadReportMap:()=>runtimeFails?Promise.reject(new Error('offline')):Promise.resolve({gl,accessToken:'synthetic'})},
  };
  const exports={};
  vm.runInNewContext(code,{exports,require:name=>dependencies[name] || {},Map,
    window:{setTimeout:fn=>{timers.set(++timerId,fn);return timerId;},clearTimeout:id=>timers.delete(id)}});
  exports.TrailReportMap({visible:true,trailId:'fixture',trailName:'Fixture',reports:[],selectedId:'',onSelect:()=>{},onSettled:()=>settled++});
  refs[0].current={};const stop=effects[0]();
  return {resolveRoute,rejectRoute,stop,timers,states,sources,get map(){return instance;},get settled(){return settled;}};
}
const ready=session();await tick();ready.map.emit('load');await tick();
assert.equal(ready.settled,0,'Style loading alone must not dismiss the progress bar');
ready.resolveRoute([[32,34],[33,35]]);await tick();
assert.deepEqual(ready.sources,['trail']);assert.equal(ready.settled,0,'Adding geometry is not the same as rendering it');
assert.equal(ready.map.fitOptions.duration,0,'Initial viewport fits behind the progress bar');
ready.map.emit('idle');assert.equal(ready.settled,1,'Reveal after the trail has rendered');assert.equal(ready.timers.size,0);ready.stop();
const failed=session();await tick();failed.map.emit('load');failed.rejectRoute(new Error('route unavailable'));await tick();
assert.equal(failed.settled,1,'Failed routes reveal a retry instead of leaving the page hidden');assert.ok(failed.states.some(s=>typeof s==='string' && s.includes('trail line')));failed.stop();
const offline=session({runtimeFails:true});await tick();assert.equal(offline.settled,1);offline.resolveRoute([]);offline.stop();
const slow=session();await tick();for(const expire of [...slow.timers.values()])expire();assert.equal(slow.settled,1,'Timeout reveals a retry');slow.resolveRoute([]);slow.stop();
const cancelled=session();await tick();cancelled.map.emit('load');cancelled.stop();cancelled.resolveRoute([[32,34],[33,35]]);await tick();
assert.equal(cancelled.settled,0,'Unmounted maps never reveal a different trail');assert.equal(cancelled.map.removed,true);
console.log('PASS: progress waits for route rendering, instant initial fit, route/runtime failures, timeout and unmount cleanup.');
