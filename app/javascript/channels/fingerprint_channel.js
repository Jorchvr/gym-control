import consumer from "channels/consumer"

consumer.subscriptions.create("FingerprintChannel", {
  connected() {
    console.log("🟢 OIDO CONECTADO: Esperando huellas...");
  },

  disconnected() {
    console.log("🔴 Desconectado.");
  },

  received(data) {
    console.log("📨 SEÑAL RECIBIDA:", data);

    if (data.action === 'login') {
      // ESTO ES LO QUE HACE QUE LA PÁGINA SE MUEVA
      window.location.href = `/clients/${data.client_id}`;
    } 
    else if (data.action === 'registered') {
      location.reload();
    }
    else if (data.action === 'unknown') {
      // Solo mostramos error si NO estamos en la pantalla de registro
      if (!window.location.href.includes('clients/')) {
         alert("❌ Huella no reconocida en el sistema");
      }
    }
  }
});