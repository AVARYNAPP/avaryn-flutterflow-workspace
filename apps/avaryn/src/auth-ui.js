import {esc,icon} from './components.js';
import {PRODUCT} from './product-config.js';
const emailField=value=>`<label class="form-field">E-mailadres<input type="email" name="email" value="${esc(value)}" autocomplete="email" autocapitalize="none" required></label>`;
const passwordField=(fresh=false)=>`<label class="form-field">${fresh?'Kies een wachtwoord':'Wachtwoord'}<input type="password" name="password" autocomplete="${fresh?'new-password':'current-password'}"${fresh?' minlength="12"':''} required></label>${fresh?'<p class="horse-muted">Gebruik minstens 12 tekens.</p>':''}`;
export function renderAuth({mode='login',message='',busy=false,email='',tokenHash=false}={}){
 const modes={login:['Welkom terug.','Log in om je paarden en je dag te bekijken.','Inloggen'],signup:['Welkom bij AVARYN.','Maak je eigen account aan. Daarna bevestig je je e-mailadres.','Account aanmaken'],recover:['Wachtwoord vergeten?','Je ontvangt een e-mail waarmee je een nieuw wachtwoord kunt kiezen.','Herstelmail versturen'],verify:['Controleer je e-mail.','Bevestig je e-mailadres via de ontvangen link of vul de bevestigingscode in.','E-mailadres bevestigen'],recovery:['Bevestig je herstelverzoek.','Gebruik de ontvangen herstellink of code.','Verder'],reset:['Een nieuw wachtwoord.','Kies een nieuw wachtwoord voor je account.','Wachtwoord opslaan']};
 const [title,intro,button]=modes[mode]||modes.login;
 let fields=['login','signup','recover'].includes(mode)?emailField(email):'';
 if(['login','signup','reset'].includes(mode))fields+=passwordField(mode!=='login');
 if(['verify','recovery'].includes(mode)&&!tokenHash)fields+=`${emailField(email)}<label class="form-field">Code uit de e-mail<input name="token" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6,10}" minlength="6" maxlength="10" required></label>`;
 return `<div class="access-page"><section class="access-card"><a class="wordmark" href="#/vandaag">AVARYN</a><p class="eyebrow">Je paarden dichtbij</p><h1>${title}</h1><p>${intro}</p>${message?`<p class="${mode==='verify'||mode==='recovery'?'access-note':'form-error'}" role="status">${esc(message)}</p>`:''}<form id="auth-${mode}-form">${fields}<button class="button-primary" type="submit"${busy?' disabled':''}>${icon('arrow-right',17)} ${busy?'Even wachten…':button}</button></form>${mode==='login'?'<button class="text-link" data-action="auth-signup">Een account aanmaken</button><button class="text-link" data-action="auth-recover">Wachtwoord vergeten?</button>':'<button class="text-link" data-action="auth-login">Terug naar inloggen</button>'}${mode==='verify'?'<button class="text-link" data-action="auth-resend">Bevestigingsmail opnieuw versturen</button>':''}${PRODUCT.demo?'<button class="text-link" data-action="enter-demo">Bekijk het visuele voorbeeld</button>':''}<p class="access-note">Je persoonlijke gegevens horen bij jouw account. Anderen krijgen alleen toegang wanneer die afzonderlijk is toegekend.</p></section><div class="access-photo"><img src="assets/orion.png" alt="Paard"><p>Rust in je dag.<br>Ruimte voor je paard.</p></div></div>`;
}

/** Consume only first-party email callbacks; never display or persist their secrets. */
export function consumeEmailCallback(location,history){
 const url=new URL(location.href);
 if(!['/auth/callback','/auth/reset-password'].includes(url.pathname))return null;
 const token=url.searchParams.get('token_hash'),type=url.searchParams.get('type');
 history.replaceState(null,'','/#/vandaag');
 if(!['email','recovery'].includes(type)||typeof token!=='string'||token.length<16||token.length>2048||/[\s\x00-\x1f]/.test(token))return {invalid:true};
 return {tokenHash:token,type};
}
