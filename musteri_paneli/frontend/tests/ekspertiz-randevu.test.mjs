import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';
const require = createRequire(import.meta.url);
const ts = require('typescript');
function load(path, extra = {}) {
 const file = new URL(path, import.meta.url);
 if (!existsSync(file)) return {};
 const module = { exports: {} };
 vm.runInNewContext(ts.transpileModule(readFileSync(file, 'utf8'), { compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020} }).outputText,
 { module, exports: module.exports, Date, Intl, process: {env:{}}, require: () => ({getToken: () => 'session'}), ...extra });
 return module.exports;
}
test('İstanbul randevu sınırları ve gösterimi cihaz saat diliminden bağımsızdır', () => {
 const h = load('../src/lib/ekspertizRandevu.ts');
 assert.equal(typeof h.randevuSinirlari, 'function');
 assert.deepEqual(JSON.parse(JSON.stringify(h.randevuSinirlari(new Date('2026-11-09T10:00:20Z')))), { min:'2026-11-09T15:01', max:'2026-12-09T13:00' });
 assert.equal(h.randevuZamani('2026-11-09T15:30').toISOString(), '2026-11-09T12:30:00.000Z');
 assert.equal(h.randevuMetni('2026-11-09T15:30'), h.randevuMetni('2026-11-09T12:30:00Z'));
 assert.match(h.randevuMetni('2026-11-09T12:30:00Z'), /15:30/);
 assert.equal(h.randevuZamani('2026-02-30T15:30'), null);
});
test('hizmet alanı yalnız sunucunun iznini kullanır; kapalı il ve zorunlu onay doğrulanır', () => {
 const h = load('../src/lib/ekspertizRandevu.ts');
 assert.equal(typeof h.randevuDogrula, 'function');
 const cities = [{il:'İstanbul', durum:'acik', talep_acabilir:false}, {il:'Ankara',durum:'test',talep_acabilir:true}];
 const valid = {city:'Ankara', appointment_at:'2026-11-09T16:00',address:'Örnek Mahallesi 12',seller_phone:'+90 532 123 45 67',not_found_accepted:true};
 const now = new Date('2026-11-09T10:00Z');
 assert.equal(Object.keys(h.randevuDogrula(valid, cities, now)).length, 0);
 for (const seller_phone of ['08501234567', '+908501234567', '8501234567']) assert.equal(h.randevuDogrula({...valid,seller_phone}, cities, now).seller_phone, undefined, seller_phone);
 assert.match(h.randevuDogrula({...valid,city:'İstanbul',not_found_accepted:false},cities,now).city,/henüz hizmet yok/);
 assert.ok(h.randevuDogrula({...valid,not_found_accepted:false},cities,now).not_found_accepted);
 assert.ok(h.randevuDogrula({...valid,appointment_at:'2026-11-09T14:59'},cities,now).appointment_at);
 assert.ok(h.randevuDogrula({...valid,appointment_at:'2026-12-09T13:01'},cities,now).appointment_at);
 for (const [code,field] of Object.entries({il_kapali:'city',randevu_gecersiz:'appointment_at',adres_eksik:'address',satici_telefon_gecersiz:'seller_phone',bulunamama_onayi_gerekli:'not_found_accepted'})) assert.equal(h.randevuHataAlani(code),field);
});
test('kimlikli hizmet alanı, ödemeli talep ve ayrı ödemesiz test ucu', async () => {
 const calls=[];
 const api=load('../src/lib/api.ts',{fetch:async(url,options)=>{calls.push({url,options});return{ok:true,json:async()=>({success:true})};}});
 assert.equal(typeof api.getExpertizServiceArea,'function');
 await api.getExpertizServiceArea();
 assert.equal(calls[0].url,'/api/v1/expertiz/service-area');
 assert.equal(calls[0].options.headers.Authorization,'Bearer session');
 await api.createExpertizRequest({city:'Ankara'});
 assert.equal(calls[1].url,'/api/v1/expertiz/requests');
 await api.createUnpaidExpertizRequest({city:'Ankara'});
 assert.equal(calls[2].url,'/api/v1/expertiz/requests/unpaid');
});
test('422 yapılandırılmış kod Error uyumluluğunu korur', async () => {
 const api=load('../src/lib/api.ts',{fetch:async()=>({ok:false,status:422,json:async()=>({detail:{message:'Telefonu kontrol edin',code:'satici_telefon_gecersiz'}})})});
 await assert.rejects(api.createExpertizRequest({}), e=>e.message==='Telefonu kontrol edin'&&e.status===422&&e.code==='satici_telefon_gecersiz');
});

test('panel randevu tarihini, adresi ve satıcıyı gösterir; bulunamama ile tamamlanmış iadeyi ayırır', () => {
 const h = load('../src/lib/ekspertizRandevu.ts');
 assert.equal(typeof h.bulunamamaDurumu, 'function');
 assert.equal(h.bulunamamaDurumu('vehicle_not_found','pending'), 'Araç adreste bulunamadı — paket ücreti iade sürecinde');
 assert.equal(h.bulunamamaDurumu('vehicle_not_found','partially_refunded'), 'Araç adreste bulunamadı — paket ücreti iade edildi');
 assert.equal(h.bulunamamaDurumu(undefined,'paid'), null);
 const file = new URL('../src/bilesenler/TalepRandevusu.tsx',import.meta.url);
 assert.ok(existsSync(file));
 const module={exports:{}};
 vm.runInNewContext(ts.transpileModule(readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020,jsx:ts.JsxEmit.ReactJSX}}).outputText,{module,exports:module.exports,require:(name)=>name==='react/jsx-runtime'?require(name):h});
 const {renderToStaticMarkup}=require('react-dom/server');
 const {createElement}=require('react');
 const markup=renderToStaticMarkup(createElement(module.exports.default,{randevu:{tarih_saat:'2026-11-09T12:30:00Z',adres:'Örnek Cadde No 8',satici_adi:'Ayşe',satici_telefon:'05321234567'},durumKodu:'vehicle_not_found',paymentStatus:'partially_refunded'}));
 for(const text of ['15:30','İstanbul saati','Örnek Cadde No 8','Ayşe','05321234567','paket ücreti iade edildi']) assert.ok(markup.includes(text), text);
});
