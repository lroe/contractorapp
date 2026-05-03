// Modal helpers
function openModal(id) { document.getElementById(id).classList.add('open'); }
function closeModal(id) { document.getElementById(id).classList.remove('open'); }

// Close modal on overlay click
document.querySelectorAll('.modal-overlay').forEach(overlay => {
  overlay.addEventListener('click', e => {
    if (e.target === overlay) overlay.classList.remove('open');
  });
});

// PO dynamic item rows
function addPOItem() {
  const container = document.getElementById('po-items');
  const materials = window._materials || [];
  const idx = container.children.length;
  const row = document.createElement('div');
  row.className = 'po-item-row';
  row.innerHTML = `
    <select name="material_id[]" required>
      <option value="">Select material...</option>
      ${materials.map(m => `<option value="${m.id}">${m.name} (${m.unit})</option>`).join('')}
    </select>
    <input type="number" name="quantity[]" placeholder="Qty" min="0.01" step="0.01" required />
    <input type="number" name="unit_price[]" placeholder="₹ per unit" min="0" step="0.01" />
    <button type="button" class="remove-row" onclick="this.closest('.po-item-row').remove()">×</button>
  `;
  container.appendChild(row);
}

// Auto-dismiss flashes
setTimeout(() => {
  document.querySelectorAll('.flash').forEach(el => {
    el.style.transition = 'opacity .4s';
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 400);
  });
}, 4000);
