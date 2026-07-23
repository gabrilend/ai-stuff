// Easter Eggs - Fun Hidden Features
// Extracted from base.njk for cleaner template

// Easter Egg 1: Konami Code (↑↑↓↓←→←→BA)
(() => {
    const konamiCode = ['ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight', 'b', 'a'];
    let konamiIndex = 0;

    document.addEventListener('keydown', (e) => {
        const expectedKey = konamiCode[konamiIndex];
        const actualKey = e.key;

        // Check if the key matches (case-insensitive for letters)
        if (actualKey === expectedKey || actualKey.toLowerCase() === expectedKey.toLowerCase()) {
            konamiIndex++;
            if (konamiIndex === konamiCode.length) {
                triggerKonamiEasterEgg();
                konamiIndex = 0;
            }
        } else {
            konamiIndex = 0;
        }
    });

    function triggerKonamiEasterEgg() {
        // Create floating icons
        const icons = ['star', 'heart', 'zap', 'award', 'sparkles', 'gift', 'coffee', 'music'];
        for (let i = 0; i < 20; i++) {
            setTimeout(() => {
                createFloatingIcon(icons[Math.floor(Math.random() * icons.length)]);
            }, i * 100);
        }

        // Show celebratory message
        const msg = document.createElement('div');
        msg.innerHTML = `
      <div style="position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                  background: rgba(251, 191, 36, 0.95); color: black; padding: 2rem 3rem; 
                  border-radius: 1rem; font-size: 2rem; font-weight: bold; z-index: 9999;
                  box-shadow: 0 10px 40px rgba(0,0,0,0.3); animation: bounce 0.5s;">
        🎉 You found the Konami Code! 🎮
      </div>
    `;
        document.body.appendChild(msg);
        setTimeout(() => msg.remove(), 3000);
    }

    function createFloatingIcon(iconName) {
        const icon = document.createElement('div');
        const svgIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-${iconName}">
      ${getIconPath(iconName)}
    </svg>`;

        icon.innerHTML = svgIcon;
        icon.style.position = 'fixed';
        icon.style.left = Math.random() * window.innerWidth + 'px';
        icon.style.top = '-50px';
        icon.style.fontSize = (Math.random() * 20 + 20) + 'px';
        icon.style.color = getRandomColor();
        icon.style.zIndex = '9999';
        icon.style.pointerEvents = 'none';
        icon.style.animation = `float ${Math.random() * 3 + 3}s ease-in`;

        document.body.appendChild(icon);
        setTimeout(() => icon.remove(), 6000);
    }

    function getIconPath(name) {
        const paths = {
            'star': '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon>',
            'heart': '<path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>',
            'zap': '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>',
            'award': '<circle cx="12" cy="8" r="7"></circle><polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"></polyline>',
            'gift': '<polyline points="20 12 20 22 4 22 4 12"></polyline><rect x="2" y="7" width="20" height="5"></rect><line x1="12" y1="22" x2="12" y2="7"></line><path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z"></path><path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"></path>',
            'coffee': '<path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path><line x1="6" y1="1" x2="6" y2="4"></line><line x1="10" y1="1" x2="10" y2="4"></line><line x1="14" y1="1" x2="14" y2="4"></line>',
            'music': '<path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle>',
            'sparkles': '<path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"></path>'
        };
        return paths[name] || paths['star'];
    }

    function getRandomColor() {
        const colors = ['#f59e0b', '#ec4899', '#8b5cf6', '#3b82f6', '#10b981', '#ef4444', '#06b6d4'];
        return colors[Math.floor(Math.random() * colors.length)];
    }
})();

// Easter Egg 2: Secret Message on Double-Click Site Title
(() => {
    document.addEventListener('DOMContentLoaded', () => {
        const siteTitles = document.querySelectorAll('nav a[href="/"]');

        siteTitles.forEach(titleLink => {
            let lastClickTime = 0;

            titleLink.addEventListener('click', (e) => {
                const currentTime = new Date().getTime();
                const timeDiff = currentTime - lastClickTime;

                if (timeDiff < 400 && timeDiff > 0) {
                    // Double click detected
                    e.preventDefault();
                    showSecretMessage();
                    lastClickTime = 0; // Reset to prevent triple click
                } else {
                    lastClickTime = currentTime;
                }
            });
        });
    });

    function showSecretMessage() {
        const messages = [
            '🎭 You found a secret!',
            '🚀 Keep exploring!',
            '💎 Hidden gem unlocked!',
            '🎨 The devil is in the details!',
            '🔍 Curiosity rewarded!',
            '✨ Easter egg discovered!'
        ];

        const msg = document.createElement('div');
        const randomMsg = messages[Math.floor(Math.random() * messages.length)];
        msg.innerHTML = `
      <div style="position: fixed; bottom: 2rem; right: 2rem; 
                  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                  color: white; padding: 1rem 1.5rem; border-radius: 0.5rem; 
                  font-weight: 600; z-index: 9999; box-shadow: 0 4px 20px rgba(0,0,0,0.2);
                  animation: slideIn 0.3s ease-out;">
        ${randomMsg}
      </div>
    `;
        document.body.appendChild(msg);
        setTimeout(() => {
            msg.style.animation = 'slideOut 0.3s ease-in';
            setTimeout(() => msg.remove(), 300);
        }, 2500);
    }
})();

// Easter Egg 3: Sparkle Trail on Mouse Move (activated by triple-clicking footer)
(() => {
    let sparkleMode = false;
    let footerClickCount = 0;
    let footerClickTimer;

    document.addEventListener('DOMContentLoaded', () => {
        const footer = document.querySelector('footer');

        if (footer) {
            footer.addEventListener('click', (e) => {
                footerClickCount++;
                clearTimeout(footerClickTimer);

                if (footerClickCount === 3) {
                    sparkleMode = !sparkleMode;
                    footerClickCount = 0;
                    showSparkleNotification(sparkleMode);
                } else {
                    footerClickTimer = setTimeout(() => {
                        footerClickCount = 0;
                    }, 500);
                }
            });
        }

        document.addEventListener('mousemove', (e) => {
            if (sparkleMode && Math.random() > 0.9) {
                createSparkle(e.clientX, e.clientY);
            }
        });
    });

    function createSparkle(x, y) {
        const sparkle = document.createElement('div');
        sparkle.innerHTML = '✨';
        sparkle.style.position = 'fixed';
        sparkle.style.left = x + 'px';
        sparkle.style.top = y + 'px';
        sparkle.style.pointerEvents = 'none';
        sparkle.style.fontSize = (Math.random() * 10 + 10) + 'px';
        sparkle.style.zIndex = '9999';
        sparkle.style.animation = 'sparkle 1s ease-out forwards';

        document.body.appendChild(sparkle);
        setTimeout(() => sparkle.remove(), 1000);
    }

    function showSparkleNotification(isActive) {
        const msg = document.createElement('div');
        msg.innerHTML = `
      <div style="position: fixed; top: 2rem; left: 50%; transform: translateX(-50%); 
                  background: rgba(251, 191, 36, 0.95); color: black; padding: 0.75rem 1.5rem; 
                  border-radius: 0.5rem; font-weight: 600; z-index: 9999;
                  box-shadow: 0 4px 15px rgba(0,0,0,0.2);">
        ✨ Sparkle mode ${isActive ? 'ON' : 'OFF'}!
      </div>
    `;
        document.body.appendChild(msg);
        setTimeout(() => msg.remove(), 2000);
    }
})();

// Easter Egg 4: Secret Click Counter (Shift + Click on theme slider)
(() => {
    document.addEventListener('DOMContentLoaded', () => {
        let secretClicks = parseInt(localStorage.getItem('secretClicks') || '0');
        const themeSlider = document.querySelector('input[type="range"]');

        if (themeSlider) {
            themeSlider.addEventListener('click', (e) => {
                if (e.shiftKey) {
                    secretClicks++;
                    localStorage.setItem('secretClicks', secretClicks);

                    if (secretClicks % 10 === 0) {
                        showMilestone(secretClicks);
                    }
                }
            });
        }

        function showMilestone(count) {
            const msg = document.createElement('div');
            const achievements = {
                10: '🥉 Bronze Clicker!',
                50: '🥈 Silver Clicker!',
                100: '🥇 Gold Clicker!',
                500: '💎 Diamond Clicker!',
                1000: '👑 Legendary Clicker!'
            };

            const achievement = achievements[count] || `🎯 ${count} Secret Clicks!`;

            msg.innerHTML = `
        <div style="position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); 
                    color: white; padding: 2rem 3rem; border-radius: 1rem; 
                    font-size: 1.5rem; font-weight: bold; z-index: 9999;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.3); animation: bounce 0.5s;
                    text-align: center;">
          ${achievement}<br>
          <span style="font-size: 1rem; opacity: 0.9;">Total: ${count} clicks</span>
        </div>
      `;
            document.body.appendChild(msg);
            setTimeout(() => msg.remove(), 3000);
        }
    });
})();

// Add CSS animations for Easter Eggs
const style = document.createElement('style');
style.textContent = `
  @keyframes float {
    0% { transform: translateY(-50px) rotate(0deg); opacity: 1; }
    100% { transform: translateY(100vh) rotate(360deg); opacity: 0; }
  }
  @keyframes bounce {
    0%, 100% { transform: translate(-50%, -50%) scale(1); }
    50% { transform: translate(-50%, -50%) scale(1.1); }
  }
  @keyframes slideIn {
    from { transform: translateX(100%); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
  }
  @keyframes slideOut {
    from { transform: translateX(0); opacity: 1; }
    to { transform: translateX(100%); opacity: 0; }
  }
  @keyframes sparkle {
    0% { transform: scale(0) rotate(0deg); opacity: 1; }
    50% { transform: scale(1) rotate(180deg); opacity: 1; }
    100% { transform: scale(0) rotate(360deg); opacity: 0; }
  }
  .animate-spin-slow {
    animation: spin 8s linear infinite;
  }
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
`;
document.head.appendChild(style);
