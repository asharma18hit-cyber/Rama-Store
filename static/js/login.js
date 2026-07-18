/* static/js/login.js */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Data defining the 9 store categories and their corresponding collage tile assignments
    // Tile 0: Staples (Grocery, Bakery, Medicine)
    // Tile 1: Dining (Foods & Restaurants)
    // Tile 2: Education & Office (Books, Copies, Stationary)
    // Tile 3: Lifestyle (Gift Store, Sports)
    const categories = [
        {
            name: "Bakery",
            desc: "Bakery — Fresh bread, pastries, and treats baked daily.",
            tileIndex: 0,
            image: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Books",
            desc: "Books — Curated novels, bestsellers, and timeless literature.",
            tileIndex: 2,
            image: "https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Copies",
            desc: "Copies — Bulk documents, thesis prints, and digital copying services.",
            tileIndex: 2,
            image: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Foods & Restaurants",
            desc: "Foods & Restaurants — Freshly prepared meals from top local kitchens.",
            tileIndex: 1,
            image: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Gift Store",
            desc: "Gift Store — Handcrafted gift wraps, collectibles, and souvenirs.",
            tileIndex: 3,
            image: "https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Grocery",
            desc: "Grocery — Fresh produce, dairy, and everyday kitchen essentials.",
            tileIndex: 0,
            image: "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Medicine",
            desc: "Medicine — Trusted over-the-counter essentials and health supplies.",
            tileIndex: 0,
            image: "https://images.unsplash.com/photo-1586015555751-63bb77f4322a?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Sports",
            desc: "Sports — Fitness gear, activewear, and athletic equipment.",
            tileIndex: 3,
            image: "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?auto=format&fit=crop&w=600&q=80"
        },
        {
            name: "Stationary",
            desc: "Stationary — High-quality notebooks, premium pens, and office supplies.",
            tileIndex: 2,
            image: "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=600&q=80"
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
        
        const prevCat = categories[activeIndex];
        const nextCat = categories[index];

        // 2a. Update tile active states
        if (prevCat.tileIndex !== nextCat.tileIndex) {
            tiles[prevCat.tileIndex].classList.remove('active');
        }
        
        // Update new tile's image source to match the active category
        const targetTile = tiles[nextCat.tileIndex];
        const targetImg = targetTile.querySelector('img');
        if (targetImg) {
            targetImg.src = nextCat.image;
            targetImg.alt = nextCat.name;
        }

        // Add active highlight to target tile
        targetTile.classList.add('active');

        // 2b. Update indicators active states (maps to category index, not tile index)
        indicators[activeIndex].classList.remove('active');
        indicators[index].classList.add('active');

        // Update main tracking index
        activeIndex = index;

        // 2c. Check prefers-reduced-motion for transition swapping
        const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        if (prefersReducedMotion) {
            // Instant swap
            captionTitle.innerText = nextCat.name;
            captionDesc.innerText = nextCat.desc;
        } else {
            // Smooth fade cross-transition for text
            captionDesc.style.opacity = '0';
            setTimeout(() => {
                captionTitle.innerText = nextCat.name;
                captionDesc.innerText = nextCat.desc;
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
    // Click on tiles directly: maps to the first category corresponding to this tile
    tiles.forEach((tile) => {
        tile.addEventListener('click', () => {
            const tileIdx = parseInt(tile.getAttribute('data-tile-index'));
            // Find first category matching this tile
            const catIndex = categories.findIndex(c => c.tileIndex === tileIdx);
            if (catIndex !== -1) {
                setActiveCategory(catIndex);
                resetTimer();
            }
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
