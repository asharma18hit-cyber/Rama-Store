document.addEventListener("DOMContentLoaded", () => {
  // ==========================================================
  // TWINKLING STAR CANVAS BACKGROUND ANIMATION
  // ==========================================================
  const canvas = document.getElementById("pixel-stars-canvas");
  if (canvas) {
    const ctx = canvas.getContext("2d");
    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    window.addEventListener("resize", () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });

    const gridSize = 20;
    const colors = [
      "#E8A33D", // marigold
      "#C1452E", // vermilion
      "#F472B6", // pink
      "#A78BFA", // violet
      "#34D399", // emerald
      "#FFFFFF"  // white
    ];

    class Star {
      constructor() {
        this.reset();
        this.opacity = Math.random();
        this.fadeDir = Math.random() > 0.5 ? 1 : -1;
      }

      reset() {
        const cols = Math.floor(width / gridSize);
        const rows = Math.floor(height / gridSize);
        this.gridX = Math.floor(Math.random() * cols);
        this.gridY = Math.floor(Math.random() * rows);
        this.x = this.gridX * gridSize + Math.floor(gridSize / 2) - 2;
        this.y = this.gridY * gridSize + Math.floor(gridSize / 2) - 2;
        this.size = 3.5;
        this.color = colors[Math.floor(Math.random() * colors.length)];
        this.opacity = 0;
        this.fadeSpeed = 0.004 + Math.random() * 0.012;
        this.fadeDir = 1;
        this.delay = Math.random() * 120;
      }

      update() {
        if (this.delay > 0) {
          this.delay--;
          return;
        }
        this.opacity += this.fadeSpeed * this.fadeDir;
        if (this.opacity >= 0.95) {
          this.opacity = 0.95;
          this.fadeDir = -1;
        } else if (this.opacity <= 0) {
          this.reset();
        }
      }

      draw() {
        if (this.delay > 0 || this.opacity <= 0) return;
        ctx.fillStyle = this.color;
        ctx.globalAlpha = this.opacity;
        ctx.fillRect(this.x, this.y, this.size, this.size);
      }
    }

    const starCount = 50;
    const stars = Array.from({ length: starCount }, () => new Star());

    function animate() {
      ctx.clearRect(0, 0, width, height);
      stars.forEach(star => {
        star.update();
        star.draw();
      });
      requestAnimationFrame(animate);
    }
    animate();
  }

  const form = document.getElementById("signin-form");
  const emailInput = document.getElementById("input-email");
  const passwordInput = document.getElementById("input-password");
  const btnGithub = document.getElementById("btn-github");
  const btnGoogle = document.getElementById("btn-google");
  const linkSignup = document.getElementById("link-signup");
  const linkReset = document.getElementById("link-reset");

  // Helper for displaying notifications
  const showToast = (msg) => {
    const container = document.getElementById("toast-container");
    if (!container) return;

    const toast = document.createElement("div");
    toast.className = "toast";
    toast.innerHTML = `<span>⚙️</span> <span>${msg}</span>`;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = "0";
      toast.style.transition = "opacity 0.25s";
      setTimeout(() => toast.remove(), 250);
    }, 2500);
  };

  // Form submission validator
  if (form) {
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      
      // Clear errors
      document.getElementById("error-email").innerText = "";
      document.getElementById("error-password").innerText = "";

      const email = emailInput.value.trim();
      const password = passwordInput.value;

      let valid = true;

      if (!email.includes("@")) {
        document.getElementById("error-email").innerText = "Please enter a valid email address.";
        valid = false;
      }
      if (password.length < 6) {
        document.getElementById("error-password").innerText = "Password must contain at least 6 characters.";
        valid = false;
      }

      if (valid) {
        showToast("Signed in successfully to Rama Store!");
      }
    });
  }

  // Social OAuth Simulation Clickers
  if (btnGithub) {
    btnGithub.addEventListener("click", () => {
      showToast("Redirecting to GitHub OAuth...");
    });
  }

  if (btnGoogle) {
    btnGoogle.addEventListener("click", () => {
      showToast("Redirecting to Google OAuth...");
    });
  }

  // Navigation link click hooks
  if (linkSignup) {
    linkSignup.addEventListener("click", (e) => {
      e.preventDefault();
      showToast("Sign up flow initiated!");
    });
  }

  if (linkReset) {
    linkReset.addEventListener("click", (e) => {
      e.preventDefault();
      showToast("Reset password email sent!");
    });
  }
});
