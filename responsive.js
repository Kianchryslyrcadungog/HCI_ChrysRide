// responsive.js

// Sidebar open/close logic
document.addEventListener('DOMContentLoaded', function() {
  // Hamburger button
  const menuToggle = document.getElementById('menu-toggle') || document.querySelector('.menu-toggle');
  const sidebar = document.getElementById('sidebar');
  if (menuToggle && sidebar) {
    menuToggle.addEventListener('click', () => {
      sidebar.classList.toggle('open');
    });
  }

  // Close button for sidebar (if present)
  const closeSidebar = document.getElementById('close-sidebar');
  if (closeSidebar && sidebar) {
    closeSidebar.addEventListener('click', () => {
      sidebar.classList.remove('open');
    });
  }

  // Highlight active menu item
  const links = document.querySelectorAll('.nav-list a, .sidebar-menu a');
  links.forEach(link => {
    if (link.href && link.href.split('/').pop() === window.location.pathname.split('/').pop()) {
      link.classList.add('active');
    }
  });

  // Centralized Logout logic (works for both passenger and driver)
  const logoutBtn = document.getElementById('logout') || document.getElementById('logout-link');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async function(e) {
      e.preventDefault();
      if (window.supabase) {
        const supabase = window.supabase.createClient(
          'https://klasvndqmhaioyzyedpg.supabase.co',
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtsYXN2bmRxbWhhaW95enllZHBnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzODIwNjIsImV4cCI6MjA2Mzk1ODA2Mn0.IhbTIgHda9LrY7EpbqwKfYjZHRPAIwFcxOxwi1srJ4U'
        );
        await supabase.auth.signOut();
      }
      // Redirect based on current role
      if (window.location.href.includes('driver')) {
        window.location.href = 'driver-login.html';
      } else {
        window.location.href = 'passenger-login.html';
      }
    });
  }
});
