// ============================================================================
// ui_shop.js — the Shop tab: eggs, resource exchange, staff.
// ============================================================================

import { CONFIG, ELEMENTS } from './config.js';
import { S } from './state.js';
import { eggPrice, buyEgg, sellEssence, buyEssence, breakRelic, forgeRelic, STAFF, hireStaff, staffUnlocked } from './shop.js';
import { registerTab, fmt, esc, toast, renderResources, renderActiveTab } from './ui.js';
import { rarityColor } from './creature.js';
import { saveGame } from './save.js';

registerTab('shop', render);

const SH = CONFIG.shop;

function render(panel) {
  panel.innerHTML = `
    <div class="section">
      <h2>🥚 Eggs <span class="dim">— hatch instantly into a tier-1 creature (reserve pen)</span></h2>
      <div class="row">
        <button id="buy-egg" class="primary">Mystery egg — ${fmt(eggPrice())} 🪙</button>
        <span class="dim">Price rises with every egg bought (${S.counters.eggsBought} so far).</span>
      </div>
      <div class="row" style="margin-top:8px" id="element-eggs">
        ${Object.entries(ELEMENTS).map(([k, e]) =>
          `<button data-el="${k}" title="Guaranteed ${e.label} egg (+50% price)">${e.icon}</button>`).join('')}
        <span class="dim">Element-guaranteed eggs cost +50%.</span>
      </div>
    </div>

    <div class="section">
      <h2>♻️ Exchange <span class="dim">— all conversions are lossy; trade with intent</span></h2>
      <div class="shop-grid">
        ${xchg('sell-essence', '💠 → 🪙', `Sell 1 essence for ${SH.coinsPerEssence} coins`, S.resources.essence >= 1)}
        ${xchg('buy-essence', '🪙 → 💠', `Buy 1 essence for ${SH.essenceCostCoins} coins`, S.resources.coins >= SH.essenceCostCoins)}
        ${xchg('break-relic', '🏺 → 💠', `Break 1 relic into ${SH.essencePerRelic} essence`, S.resources.relics >= 1)}
        ${xchg('forge-relic', '💠 → 🏺', `Forge 1 relic from ${SH.relicCostEssence} essence`, S.resources.essence >= SH.relicCostEssence)}
      </div>
      <div class="dim" style="margin-top:6px">Relics come from milestones — forging them is a late-game essence sink.</div>
    </div>

    <div class="section">
      <h2>🧑‍🤝‍🧑 Staff & automation <span class="dim">— one-time hires, permanent effects</span></h2>
      <div class="shop-grid">
        ${STAFF.map(s => {
          const locked = !staffUnlocked(s);
          return `
          <div class="shop-item" ${locked ? 'style="opacity:.65"' : ''}>
            <h3>${locked ? '🔒' : ''} ${s.name}</h3>
            <div class="desc">${locked ? `Unlocks when you: <b>${s.unlock.label}</b> (${S.counters[s.unlock.counter] || 0}/${s.unlock.at})` : s.desc}</div>
            ${S.upgrades[s.key]
              ? '<button disabled>✅ Hired</button>'
              : locked
                ? '<button disabled>🔒 Locked</button>'
                : `<button data-staff="${s.key}">Hire — ${costLabel(s.cost)}</button>`}
          </div>`;
        }).join('')}
      </div>
    </div>`;

  panel.querySelector('#buy-egg').addEventListener('click', () => doEgg(null));
  panel.querySelector('#element-eggs').querySelectorAll('button[data-el]').forEach(b =>
    b.addEventListener('click', () => doEgg(b.dataset.el)));

  const wire = (id, fn) => panel.querySelector('#' + id)?.addEventListener('click', () => {
    const res = fn();
    if (!res.ok) return toast(res.why, 'bad');
    saveGame(); renderResources(); renderActiveTab();
  });
  wire('sell-essence', sellEssence);
  wire('buy-essence', buyEssence);
  wire('break-relic', breakRelic);
  wire('forge-relic', forgeRelic);

  panel.querySelectorAll('button[data-staff]').forEach(b =>
    b.addEventListener('click', () => {
      const res = hireStaff(b.dataset.staff);
      if (!res.ok) return toast(res.why, 'bad');
      toast(`${res.item.name} joins the menagerie!`, 'gold');
      saveGame(); renderResources(); renderActiveTab();
    }));
}

function doEgg(element) {
  // Element-guaranteed eggs cost +50% — spend the difference up front.
  if (element) {
    const surcharge = Math.round(eggPrice() * 0.5);
    if (S.resources.coins < eggPrice() + surcharge) return toast('Not enough coins.', 'bad');
    S.resources.coins -= surcharge;
  }
  const res = buyEgg(element);
  if (!res.ok) return toast(res.why, 'bad');
  const c = res.creature;
  toast(`🥚 Hatched <b style="color:${rarityColor(c)}">${esc(c.name)}</b>!` +
    (res.isNew ? ' <span class="gold">✦ New species!</span>' : ''), 'gold');
  saveGame(); renderResources(); renderActiveTab();
}

function xchg(id, arrow, desc, enabled) {
  return `<div class="shop-item">
    <h3>${arrow}</h3><div class="desc">${desc}</div>
    <button id="${id}" ${enabled ? '' : 'disabled'}>Exchange</button>
  </div>`;
}

function costLabel(cost) {
  const parts = [];
  if (cost.coins) parts.push(`${fmt(cost.coins)} 🪙`);
  if (cost.essence) parts.push(`${fmt(cost.essence)} 💠`);
  if (cost.relics) parts.push(`${fmt(cost.relics)} 🏺`);
  return parts.join(' + ');
}
