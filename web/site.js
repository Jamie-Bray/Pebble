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

const routines = {
  leaving: {
    name: "Leaving home",
    steps: [
      { title: "Lock the back door", icon: "⌂" },
      { title: "Turn off the hob", icon: "⌁", photo: true },
      { title: "Take your keys", icon: "⌘" },
      { title: "Lock the front door", icon: "⌂", photo: true },
    ],
  },
  morning: {
    name: "Good morning",
    steps: [
      { title: "Drink some water", icon: "◡" },
      { title: "Take your vitamins", icon: "+" },
      { title: "Pack your bag", icon: "□" },
      { title: "Check today's plan", icon: "☼" },
    ],
  },
  bedtime: {
    name: "Bedtime reset",
    steps: [
      { title: "Set your alarm", icon: "◷" },
      { title: "Plug in your phone", icon: "ϟ" },
      { title: "Check the doors", icon: "⌂", photo: true },
      { title: "Put out tomorrow's clothes", icon: "◇" },
    ],
  },
};

let currentRoutine = "leaving";
let currentStep = 0;

const demo = {
  phone: document.querySelector(".demo-phone"),
  counter: document.querySelector(".demo-counter"),
  progress: document.querySelector(".demo-progress"),
  content: document.querySelector(".demo-content"),
  complete: document.querySelector(".demo-complete"),
  name: document.querySelector(".demo-routine-name"),
  icon: document.querySelector(".demo-step-icon"),
  title: document.querySelector(".demo-step-title"),
  photo: document.querySelector(".proof-chip"),
  back: document.querySelector(".demo-back"),
  done: document.querySelector(".demo-done"),
};

function renderRoutine() {
  if (!demo.phone) return;

  const routine = routines[currentRoutine];
  const isComplete = currentStep >= routine.steps.length;
  const step = routine.steps[Math.min(currentStep, routine.steps.length - 1)];

  demo.counter.textContent = isComplete ? "Complete" : `${currentStep + 1} of ${routine.steps.length}`;
  demo.name.textContent = routine.name;
  demo.icon.textContent = step.icon;
  demo.title.textContent = step.title;
  demo.photo.hidden = !step.photo || isComplete;
  demo.content.hidden = isComplete;
  demo.complete.hidden = !isComplete;
  demo.back.disabled = currentStep === 0;
  demo.done.innerHTML = isComplete
    ? 'Again <span aria-hidden="true">↺</span>'
    : 'Done <span aria-hidden="true">✓</span>';

  demo.progress.querySelectorAll("span").forEach((dot, index) => {
    dot.classList.toggle("is-done", index < currentStep);
    dot.classList.toggle("is-current", index === currentStep && !isComplete);
  });

  demo.phone.classList.remove("step-pop");
  requestAnimationFrame(() => demo.phone.classList.add("step-pop"));
}

document.querySelectorAll(".routine-choice").forEach((choice) => {
  choice.addEventListener("click", () => {
    currentRoutine = choice.dataset.routine;
    currentStep = 0;
    document.querySelectorAll(".routine-choice").forEach((button) => {
      const active = button === choice;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    renderRoutine();
  });
});

demo.done?.addEventListener("click", () => {
  const stepCount = routines[currentRoutine].steps.length;
  currentStep = currentStep >= stepCount ? 0 : currentStep + 1;
  renderRoutine();
});

demo.back?.addEventListener("click", () => {
  currentStep = Math.max(0, currentStep - 1);
  renderRoutine();
});

document.querySelector(".demo-reset")?.addEventListener("click", () => {
  currentStep = 0;
  renderRoutine();
});

const themeNames = {
  sandstone: "Sandstone",
  matcha: "Matcha",
  rose: "Rose Quartz",
  night: "Pebble Dark",
};

document.querySelectorAll(".theme-swatch").forEach((swatch) => {
  swatch.addEventListener("click", () => {
    const theme = swatch.dataset.previewTheme;
    if (!demo.phone) return;

    demo.phone.dataset.theme = theme;
    document.querySelector(".theme-name").textContent = `${themeNames[theme]} — plenty more inside`;
    document.querySelectorAll(".theme-swatch").forEach((button) => {
      const active = button === swatch;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    });
  });
});

renderRoutine();
