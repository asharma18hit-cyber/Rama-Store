/* static/js/login.js */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Data defining the book categories
    const categories = [
        {
            title: "Fiction & Novels",
            desc: "Immersive stories, classic novels, and timeless prose."
        },
        {
            title: "Mystery & Thriller",
            desc: "Twist endings, dark shadows, and heart-pounding page-turners."
        },
        {
            title: "Non-Fiction & Self-Help",
            desc: "Master new skills, discover histories, and cultivate your mindset."
        },
        {
            title: "Poetry & Arts",
            desc: "Beautiful lines, creative reflections, and cultural reviews."
        }
    ];

    let activeIndex = 0;
    let autoAdvanceTimer = null;
    const intervalTime = 2800; // 2.8 seconds cycle

    const tiles = document.querySelectorAll('.collage-tile');
    const indicators = document.querySelectorAll('.indicator-pill');
    const captionTitle = document.getElementById('caption-title');
    const captionDesc = document.getElementById('caption-desc');
    const collageContainer = document.getElementById('interactive-collage');

    // 2. Main transition function to swap active slide
    function setActiveCategory(index) {
        if (index === activeIndex) return;
        
        // Remove active class from previous
        tiles[activeIndex].classList.remove('active');
        indicators[activeIndex].classList.remove('active');

        // Update index
        activeIndex = index;

        // Add active class to new
        tiles[activeIndex].classList.add('active');
        indicators[activeIndex].classList.add('active');

        // Check prefers-reduced-motion for transition swapping
        const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        if (prefersReducedMotion) {
            // Instant swap
            captionTitle.innerText = categories[activeIndex].title;
            captionDesc.innerText = categories[activeIndex].desc;
        } else {
            // Smooth fade cross-transition for text
            captionDesc.style.opacity = '0';
            setTimeout(() => {
                captionTitle.innerText = categories[activeIndex].title;
                captionDesc.innerText = categories[activeIndex].desc;
                captionDesc.style.opacity = '1';
            }, 250);
        }
    }

    // 3. Auto-advancer timer configuration
    function startTimer() {
        if (autoAdvanceTimer) clearInterval(autoAdvanceTimer);
        autoAdvanceTimer = setInterval(() => {
            const nextIndex = (activeIndex + 1) % categories.length;
            setActiveCategory(nextIndex);
        }, intervalTime);
    }

    function stopTimer() {
        if (autoAdvanceTimer) clearInterval(autoAdvanceTimer);
    }

    function resetTimer() {
        stopTimer();
        startTimer();
    }

    // 4. Interactive Event Handlers
    // Click on tiles directly
    tiles.forEach((tile) => {
        tile.addEventListener('click', () => {
            const index = parseInt(tile.getAttribute('data-index'));
            setActiveCategory(index);
            resetTimer();
        });
    });

    // Click on indicator pills
    indicators.forEach((pill) => {
        pill.addEventListener('click', () => {
            const index = parseInt(pill.getAttribute('data-index'));
            setActiveCategory(index);
            resetTimer();
        });
    });

    // Pause-on-hover on the collage grid
    if (collageContainer) {
        collageContainer.addEventListener('mouseenter', stopTimer);
        collageContainer.addEventListener('mouseleave', startTimer);
    }

    // Initialize
    startTimer();
});

// View Forms toggling logic between Login and Registration panel forms
function toggleFormView(view) {
    const loginForm = document.getElementById('login-form-container');
    const registerForm = document.getElementById('register-form-container');

    if (view === 'register') {
        loginForm.classList.remove('active');
        registerForm.classList.add('active');
    } else {
        registerForm.classList.remove('active');
        loginForm.classList.add('active');
    }
}
