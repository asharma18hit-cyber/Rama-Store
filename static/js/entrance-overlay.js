/* static/js/entrance-overlay.js */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Session Storage Gate: Play once per session
    if (sessionStorage.getItem('has_seen_entrance') === 'true') {
        const overlay = document.getElementById('entrance-overlay');
        if (overlay) overlay.remove();
        return;
    }
    
    // Add entrance-active flag to body to trigger blur/scale on page background elements
    document.body.classList.add('entrance-active');
    
    const overlay = document.getElementById('entrance-overlay');
    const canvasContainer = document.getElementById('shader-canvas-container');
    const wordmark = document.getElementById('entrance-wordmark');
    const tagline = document.getElementById('entrance-tagline');
    const enterBtn = document.getElementById('btn-enter-store');
    const skipBtn = document.getElementById('btn-skip-entrance');
    
    if (!overlay || !canvasContainer) return;
    
    // 2. Accessibility Check: prefers-reduced-motion
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    
    let shader = null;
    
    if (prefersReducedMotion) {
        // Skip choreography animations entirely, instantly reveal static entrance
        wordmark.classList.remove('stage-hidden');
        wordmark.classList.add('stage-visible');
        tagline.classList.remove('stage-hidden');
        tagline.classList.add('stage-visible');
        enterBtn.classList.remove('stage-hidden');
        enterBtn.classList.add('stage-visible');
        
        enterBtn.addEventListener('click', dismissEntrance);
        skipBtn.addEventListener('click', dismissEntrance);
        return;
    }
    
    // 3. WebGL Spiral Animation Setup
    if (typeof SpiralShader !== 'undefined') {
        shader = new SpiralShader(canvasContainer);
        shader.animate(0);
    }
    
    // 4. Choreographed Sequence Timeline
    
    // Stage 1: Shader build-up intensity sweep
    let intensity = 0;
    const intensityInterval = setInterval(() => {
        if (intensity < 1.0) {
            intensity += 0.04;
            if (shader) shader.setIntensity(intensity);
        } else {
            clearInterval(intensityInterval);
        }
    }, 40);
    
    // Stage 2: Wordmark "Rama Store" blur-to-focus reveal
    setTimeout(() => {
        wordmark.classList.remove('stage-hidden');
        wordmark.classList.add('stage-visible');
    }, 1200);
    
    // Stage 3: Tagline and Enter CTA fade-in
    setTimeout(() => {
        tagline.classList.remove('stage-hidden');
        tagline.classList.add('stage-visible');
        enterBtn.classList.remove('stage-hidden');
        enterBtn.classList.add('stage-visible');
    }, 2600);
    
    // Stage 4: Auto-dismiss backup after 8 seconds
    const autoDismissTimeout = setTimeout(() => {
        dismissEntrance();
    }, 8000);
    
    // Click-to-dismiss handlers
    enterBtn.addEventListener('click', () => {
        clearTimeout(autoDismissTimeout);
        dismissEntrance();
    });
    
    skipBtn.addEventListener('click', () => {
        clearTimeout(autoDismissTimeout);
        dismissEntrance();
    });
    
    function dismissEntrance() {
        // Fade out overlay container
        overlay.style.opacity = '0';
        overlay.style.pointerEvents = 'none';
        
        // Scale down overlay shader canvas slightly for dynamic depth feel
        canvasContainer.style.transform = 'scale(0.95)';
        
        // Remove entrance active body class to trigger page blur-out/reveal underneath
        document.body.classList.remove('entrance-active');
        
        // Set seen flag in sessionStorage
        sessionStorage.setItem('has_seen_entrance', 'true');
        
        // Destroy WebGL objects and remove DOM node after transition completes
        setTimeout(() => {
            if (shader) {
                shader.destroy();
            }
            overlay.remove();
        }, 1200);
    }
});
