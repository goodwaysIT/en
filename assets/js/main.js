document.addEventListener('DOMContentLoaded', function() {
  // Mobile navigation toggle
  const navTrigger = document.querySelector('.nav-trigger');
  const menuIcon = document.querySelector('.menu-icon');
  
  if (navTrigger && menuIcon) {
    menuIcon.addEventListener('click', function(e) {
      e.stopPropagation();
    });
  }
  
  // Smooth scrolling for anchor links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      e.preventDefault();
      
      const targetId = this.getAttribute('href');
      if (targetId === '#') return;
      
      const targetElement = document.querySelector(targetId);
      if (targetElement) {
        targetElement.scrollIntoView({
          behavior: 'smooth'
        });
      }
    });
  });
  
  // Add syntax highlighting to code blocks if Prism.js is available
  if (typeof Prism !== 'undefined') {
    Prism.highlightAll();
  }
});
