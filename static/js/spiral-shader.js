/* static/js/spiral-shader.js */

/**
 * SpiralShader - Custom WebGL spiral particle shader class using Three.js.
 * Displays a fluid, dynamic spiral texture mapped using warm literary tones.
 */
class SpiralShader {
    constructor(canvasContainer) {
        this.container = canvasContainer;
        this.width = this.container.clientWidth;
        this.height = this.container.clientHeight;
        
        // 1. Initialize Scene, Orthographic Camera, and Renderer
        this.scene = new THREE.Scene();
        this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
        this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        this.renderer.setSize(this.width, this.height);
        this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // Limit pixel ratio for performance
        this.container.appendChild(this.renderer.domElement);
        
        // 2. Uniform values for custom shader material
        this.uniforms = {
            u_time: { value: 0 },
            u_resolution: { value: new THREE.Vector2(this.width, this.height) },
            u_intensity: { value: 0 } // Stage 1 build-up intensity value
        };
        
        const vertexShader = `
            varying vec2 vUv;
            void main() {
                vUv = uv;
                gl_Position = vec4(position, 1.0);
            }
        `;
        
        // Recolored fragment shader representing premium literary bookstore brand
        // aged paper cream: vec3(0.98, 0.97, 0.95)
        // deep burgundy/maroon: vec3(0.42, 0.12, 0.16)
        // ink black: vec3(0.12, 0.13, 0.13)
        // warm gold: vec3(0.72, 0.54, 0.17)
        const fragmentShader = `
            uniform float u_time;
            uniform vec2 u_resolution;
            uniform float u_intensity;
            varying vec2 vUv;
            
            vec3 getColor(float t) {
                vec3 c_ink = vec3(0.12, 0.13, 0.13);
                vec3 c_burgundy = vec3(0.42, 0.12, 0.16);
                vec3 c_gold = vec3(0.72, 0.54, 0.17);
                vec3 c_cream = vec3(0.98, 0.97, 0.95);
                
                // Modulate colors dynamically based on angle and radius index
                float m = sin(t * 3.14159 * 2.0);
                if (m < -0.3) {
                    return mix(c_ink, c_burgundy, (m + 1.0) / 0.7);
                } else if (m < 0.4) {
                    return mix(c_burgundy, c_gold, (m + 0.3) / 0.7);
                } else {
                    return mix(c_gold, c_cream, (m - 0.4) / 0.6);
                }
            }
            
            void main() {
                vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / u_resolution.y;
                float r = length(uv);
                float theta = atan(uv.y, uv.x);
                
                // Spiral formula
                float spiral = sin(r * 22.0 - theta * 3.0 - u_time * 2.2) * 0.5 + 0.5;
                
                // Radial edge mask to prevent edge lines clipping
                float mask = smoothstep(0.75, 0.1, r);
                
                // Generate and mask final colors
                vec3 col = getColor(r * 2.5 - theta * 0.4 + u_time * 0.08);
                col *= spiral * u_intensity * mask;
                
                gl_FragColor = vec4(col, mask * u_intensity);
            }
        `;
        
        // 3. Create Custom Shader Material & Mesh
        this.material = new THREE.ShaderMaterial({
            vertexShader,
            fragmentShader,
            uniforms: this.uniforms,
            transparent: true
        });
        
        const geometry = new THREE.PlaneGeometry(2, 2);
        const mesh = new THREE.Mesh(geometry, this.material);
        this.scene.add(mesh);
        
        // Bind events & methods
        this.animate = this.animate.bind(this);
        this.resize = this.resize.bind(this);
        window.addEventListener('resize', this.resize);
    }
    
    setIntensity(val) {
        this.uniforms.u_intensity.value = val;
    }
    
    animate(timestamp) {
        this.animationFrameId = requestAnimationFrame(this.animate);
        this.uniforms.u_time.value = timestamp * 0.001;
        this.renderer.render(this.scene, this.camera);
    }
    
    resize() {
        if (!this.container) return;
        this.width = this.container.clientWidth;
        this.height = this.container.clientHeight;
        this.renderer.setSize(this.width, this.height);
        this.uniforms.u_resolution.value.set(this.width, this.height);
    }
    
    destroy() {
        cancelAnimationFrame(this.animationFrameId);
        window.removeEventListener('resize', this.resize);
        this.renderer.dispose();
        this.material.dispose();
        if (this.renderer.domElement.parentNode) {
            this.container.removeChild(this.renderer.domElement);
        }
    }
}
