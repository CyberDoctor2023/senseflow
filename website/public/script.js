const stage = document.querySelector('.product-stage');
const historyWindow = document.querySelector('.history-window');
const track = document.querySelector('.history-track');
const sourceSet = document.querySelector('.card-set');
const duplicateSet = document.querySelector('.card-set[aria-hidden="true"]');
const filterButtons = [...document.querySelectorAll('.filter-button')];
const searchInput = document.querySelector('.search input');
const pinButton = document.querySelector('.pin-button');

const cloneVisibleCards = () => {
  duplicateSet.replaceChildren(...[...sourceSet.children].map(card => card.cloneNode(true)));
};

const applyFilter = () => {
  const selected = document.querySelector('.filter-button.is-active')?.dataset.filter || 'all';
  const query = searchInput.value.trim().toLowerCase();
  [...sourceSet.children].forEach(card => {
    const categoryMatches = selected === 'all' || card.dataset.kind === selected;
    const queryMatches = !query || card.textContent.toLowerCase().includes(query);
    card.hidden = !(categoryMatches && queryMatches);
  });
  cloneVisibleCards();
  track.classList.toggle('is-static', sourceSet.querySelectorAll('.clip-card:not([hidden])').length < 4);
};

filterButtons.forEach(button => button.addEventListener('click', () => {
  filterButtons.forEach(item => {
    const active = item === button;
    item.classList.toggle('is-active', active);
    item.setAttribute('aria-pressed', String(active));
  });
  applyFilter();
}));

searchInput.addEventListener('input', applyFilter);
pinButton.addEventListener('click', () => {
  const pinned = pinButton.getAttribute('aria-pressed') !== 'true';
  pinButton.setAttribute('aria-pressed', String(pinned));
  stage.classList.toggle('is-pinned', pinned);
});

const visibility = new IntersectionObserver(([entry]) => {
  stage.classList.toggle('is-offscreen', !entry.isIntersecting);
}, { threshold: 0.05 });
visibility.observe(stage);

const updatePageVisibility = () => {
  stage.classList.toggle('is-hidden', document.hidden);
};
document.addEventListener('visibilitychange', updatePageVisibility);
updatePageVisibility();

cloneVisibleCards();
