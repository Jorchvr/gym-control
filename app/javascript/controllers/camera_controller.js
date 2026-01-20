import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "video", "canvas", "preview", "input", "startBtn", "captureBtn", "retakeBtn" ]

  connect() {
    console.log("🟢 Camera Controller Conectado");
    this.stream = null;
  }

  disconnect() {
    this.stopCamera();
  }

  async start(event) {
    if (event) event.preventDefault();
    console.log("🔌 Intentando encender cámara...");

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
      
      this.videoTarget.srcObject = this.stream;
      this.videoTarget.style.display = "block";
      this.videoTarget.play();
      
      this.startBtnTarget.style.display = "none";
      this.captureBtnTarget.style.display = "inline-block";
      this.previewTarget.style.display = "none";
      
      console.log("✅ Cámara encendida correctamente");
    } catch (error) {
      console.error("❌ Error de cámara:", error);
      alert("No se pudo encender la cámara. \n\n1. Revisa que 'Brave Shields' esté DESACTIVADO.\n2. Asegúrate de dar permiso en el aviso del navegador.");
    }
  }

  capture(event) {
    if (event) event.preventDefault();
    
    // Configurar canvas
    this.canvasTarget.width = this.videoTarget.videoWidth;
    this.canvasTarget.height = this.videoTarget.videoHeight;
    
    // Dibujar foto
    const context = this.canvasTarget.getContext("2d");
    context.drawImage(this.videoTarget, 0, 0);
    
    // Convertir a archivo
    this.canvasTarget.toBlob((blob) => {
      const file = new File([blob], "webcam_photo.jpg", { type: "image/jpeg" });
      
      // Asignar al input
      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(file);
      this.inputTarget.files = dataTransfer.files;
      
      // Mostrar preview
      const url = URL.createObjectURL(blob);
      this.previewTarget.src = url;
      this.previewTarget.style.display = "block";
      
      // Cambiar interfaz
      this.videoTarget.style.display = "none";
      this.captureBtnTarget.style.display = "none";
      this.retakeBtnTarget.style.display = "inline-block";
      
      this.stopCamera(); // Apagar para ahorrar recursos
    }, 'image/jpeg', 0.95);
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }
  }
}