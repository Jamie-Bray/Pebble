const navToggle = document.querySelector(".nav-toggle");
const yearTargets = document.querySelectorAll("[data-year]");

yearTargets.forEach((target) => {
  target.textContent = String(new Date().getFullYear());
});

navToggle?.addEventListener("click", () => {
  const isOpen = document.body.classList.toggle("nav-open");
  navToggle.setAttribute("aria-expanded", String(isOpen));
});

document.querySelectorAll(".site-nav a").forEach((link) => {
  link.addEventListener("click", () => {
    document.body.classList.remove("nav-open");
    navToggle?.setAttribute("aria-expanded", "false");
  });
});
