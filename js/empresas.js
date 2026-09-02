const rows = document.querySelectorAll('.projeto-row');

function toggleRow(row) {
  const wasExpanded = row.classList.contains('is-expanded');
  rows.forEach((r) => r.classList.remove('is-expanded'));
  if (!wasExpanded) row.classList.add('is-expanded');
}

rows.forEach((row) => {
  row.addEventListener('click', () => toggleRow(row));
  row.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleRow(row);
    }
  });
});
