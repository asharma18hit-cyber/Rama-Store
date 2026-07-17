// Initialize Lucide Icons
document.addEventListener("DOMContentLoaded", () => {
  lucide.createIcons();

  // 1. User Profile Dropdown Toggle
  const avatarTrigger = document.getElementById("profile-avatar-trigger");
  const profileDropdown = document.getElementById("profile-dropdown");

  if (avatarTrigger && profileDropdown) {
    avatarTrigger.addEventListener("click", (e) => {
      e.stopPropagation();
      profileDropdown.classList.toggle("show");
    });

    // Close dropdown when clicking outside
    document.addEventListener("click", (e) => {
      if (!profileDropdown.contains(e.target) && !avatarTrigger.contains(e.target)) {
        profileDropdown.classList.remove("show");
      }
    });
  }

  // 2. Collapsible Left Sidebar Groups
  const sectionHeaders = document.querySelectorAll(".nav-section-header");
  sectionHeaders.forEach((header) => {
    header.addEventListener("click", () => {
      const section = header.parentElement;
      if (section) {
        section.classList.toggle("collapsed");
      }
    });
  });

  // 3. Navigation Item Active State Toggles
  const navItems = document.querySelectorAll(".nav-item");
  navItems.forEach((item) => {
    item.addEventListener("click", (e) => {
      // Allow navigation links but toggle active visually
      navItems.forEach((nav) => nav.classList.remove("active"));
      item.classList.add("active");
    });
  });

  // 4. Interactive Voting Counter Simulation
  const voteBlocks = document.querySelectorAll(".engagement-action-block");
  voteBlocks.forEach((block) => {
    const upBtn = block.querySelector(".vote-up");
    const downBtn = block.querySelector(".vote-down");
    const countEl = block.querySelector(".vote-count");

    if (upBtn && downBtn && countEl) {
      let initialCount = parseFloat(countEl.innerText.replace("k", "")) * (countEl.innerText.includes("k") ? 1000 : 1);
      let userVote = 0; // 0 = none, 1 = upvoted, -1 = downvoted

      const renderVoteState = () => {
        let currentCount = initialCount + userVote;
        
        // Format logic
        if (currentCount >= 1000) {
          countEl.innerText = (currentCount / 1000).toFixed(1) + "k";
        } else {
          countEl.innerText = currentCount;
        }

        upBtn.style.color = userVote === 1 ? "var(--primary)" : "";
        downBtn.style.color = userVote === -1 ? "#C1452E" : "";
      };

      upBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        if (userVote === 1) {
          userVote = 0;
        } else {
          userVote = 1;
        }
        renderVoteState();
      });

      downBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        if (userVote === -1) {
          userVote = 0;
        } else {
          userVote = -1;
        }
        renderVoteState();
      });
    }
  });

  // 5. Interactive Bookmark Unsave/Save Flag Toggles
  const bookmarkButtons = document.querySelectorAll(".bookmark-btn");
  bookmarkButtons.forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      btn.classList.toggle("active");
      
      // Update Lucide icon styling
      const icon = btn.querySelector("svg");
      if (icon) {
        if (btn.classList.contains("active")) {
          icon.classList.add("fill-current");
          btn.setAttribute("aria-label", "Unsave bookmark");
        } else {
          icon.classList.remove("fill-current");
          btn.setAttribute("aria-label", "Save bookmark");
        }
      }
    });
  });

  // 6. Join/Joined Community Toggle Simulation
  const joinBtns = document.querySelectorAll(".btn-join");
  joinBtns.forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      btn.classList.toggle("joined");
      if (btn.classList.contains("joined")) {
        btn.innerText = "Joined";
      } else {
        btn.innerText = "Join";
      }
    });
  });
});
