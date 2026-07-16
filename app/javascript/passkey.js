// Minimal WebAuthn browser flow for passkey registration and sign in.
// Talks to the JSON endpoints exposed by RegistrationsController and SessionsController.

function base64urlToBuffer(value) {
  const padding = "=".repeat((4 - (value.length % 4)) % 4);
  const base64 = (value + padding).replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function bufferToBase64url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content;
}

async function postJson(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": csrfToken()
    },
    body: JSON.stringify(body)
  });
  const data = await response.json().catch(() => ({}));
  return { ok: response.ok, data };
}

function showError(form, message) {
  const target = form.querySelector("[data-passkey-error]");
  if (target) target.textContent = message;
}

function serializeCreate(credential) {
  return {
    type: credential.type,
    id: credential.id,
    rawId: bufferToBase64url(credential.rawId),
    response: {
      attestationObject: bufferToBase64url(credential.response.attestationObject),
      clientDataJSON: bufferToBase64url(credential.response.clientDataJSON)
    },
    clientExtensionResults: credential.getClientExtensionResults()
  };
}

function serializeGet(assertion) {
  return {
    type: assertion.type,
    id: assertion.id,
    rawId: bufferToBase64url(assertion.rawId),
    response: {
      authenticatorData: bufferToBase64url(assertion.response.authenticatorData),
      clientDataJSON: bufferToBase64url(assertion.response.clientDataJSON),
      signature: bufferToBase64url(assertion.response.signature),
      userHandle: assertion.response.userHandle ? bufferToBase64url(assertion.response.userHandle) : null
    },
    clientExtensionResults: assertion.getClientExtensionResults()
  };
}

async function register(form) {
  showError(form, "");
  const username = form.querySelector('[name="username"]').value;
  const started = await postJson(form.dataset.optionsUrl, { username });
  if (!started.ok) return showError(form, started.data.error || "Could not start registration.");

  const options = started.data;
  options.challenge = base64urlToBuffer(options.challenge);
  options.user.id = base64urlToBuffer(options.user.id);
  (options.excludeCredentials || []).forEach((c) => (c.id = base64urlToBuffer(c.id)));

  let credential;
  try {
    credential = await navigator.credentials.create({ publicKey: options });
  } catch (error) {
    return showError(form, "Passkey registration was cancelled.");
  }

  const finished = await postJson(form.dataset.callbackUrl, { credential: serializeCreate(credential) });
  if (finished.ok) window.location.assign(finished.data.redirect_url);
  else showError(form, finished.data.error || "Registration failed.");
}

async function authenticate(form) {
  showError(form, "");
  const username = form.querySelector('[name="username"]').value;
  const started = await postJson(form.dataset.optionsUrl, { username });
  if (!started.ok) return showError(form, started.data.error || "Could not start sign in.");

  const options = started.data;
  options.challenge = base64urlToBuffer(options.challenge);
  (options.allowCredentials || []).forEach((c) => (c.id = base64urlToBuffer(c.id)));

  let assertion;
  try {
    assertion = await navigator.credentials.get({ publicKey: options });
  } catch (error) {
    return showError(form, "Passkey sign in was cancelled.");
  }

  const finished = await postJson(form.dataset.callbackUrl, { credential: serializeGet(assertion) });
  if (finished.ok) window.location.assign(finished.data.redirect_url);
  else showError(form, finished.data.error || "Sign in failed.");
}

document.addEventListener("submit", (event) => {
  const form = event.target;
  if (form.matches("[data-passkey='register']")) {
    event.preventDefault();
    register(form);
  } else if (form.matches("[data-passkey='authenticate']")) {
    event.preventDefault();
    authenticate(form);
  }
});
