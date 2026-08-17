// TTZip App Icon Designer - State Management & Persistence

const STORAGE_KEY = 'ttzip_app_icon_designer_state_v1';
const PRESETS_STORAGE_KEY = 'ttzip_app_icon_designer_custom_presets_v1';

// Default State Variables
let state = {
  strokeWidthT: 32,     // T lines stroke thickness
  strokeWidthSlash: 32, // Gold slash line stroke thickness
  slashLength: 100,     // 30% to 160% diagonal extension
  lineCapT: 'round',    // 'round' | 'square' for T bars
  lineCapSlash: 'round',// 'round' | 'square' for Gold Slash
  overhangL: 30,
  overhangR: 30,
  gapTLBar: 40,         // Top-Left T Bar Right Gap
  gapTLWall: 40,        // Top-Left T Wall Bottom Gap
  gapBRWall: 40,        // Bottom-Right T Wall Top Gap
  gapBRBar: 40,         // Bottom-Right T Bar Left Gap
  colorBamboo: '#789262', // Color.bambooGreen Light Mode Default
  colorMustard: '#D4AF37',// Color.kintsugiGold Light Mode Default
  colorBg: '#F5F4F0',
  bambooMode: 'light',
  kintsugiMode: 'light',
  themeMode: 'light',   // 'light' | 'dark-black' | 'dark-slate' | 'custom'
  layerOrder: 't-on-top',// 't-on-top' | 'slash-on-top'
  liquidGlass: true,    // macOS 26 Liquid Glass Translucency & Specular Bevel
  layered3DDepth: true, // 3D Elevation Parallax Drop Shadows
  boxLeft: 136,
  boxRight: 376,
  boxTop: 136,
  boxBottom: 376
};

let customPresets = [];

function saveState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (e) {
    console.warn('Unable to save state to localStorage:', e);
  }
}

function loadSavedState() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      const parsed = JSON.parse(saved);
      // Migrate legacy single strokeWidth to strokeWidthT / strokeWidthSlash
      if (parsed.strokeWidth !== undefined) {
        if (parsed.strokeWidthT === undefined) parsed.strokeWidthT = parsed.strokeWidth;
        if (parsed.strokeWidthSlash === undefined) parsed.strokeWidthSlash = parsed.strokeWidth;
      }
      // Migrate legacy 2-gap system to 4-gap system
      if (parsed.gapTR !== undefined && parsed.gapTLBar === undefined) {
        parsed.gapTLBar = parsed.gapTR;
        parsed.gapBRWall = parsed.gapTR;
      }
      if (parsed.gapBL !== undefined && parsed.gapTLWall === undefined) {
        parsed.gapTLWall = parsed.gapBL;
        parsed.gapBRBar = parsed.gapBL;
      }
      state = Object.assign(state, parsed);
    }
  } catch (e) {
    console.warn('Unable to load state from localStorage:', e);
  }
}

function syncInputsFromState() {
  if (document.getElementById('param-stroke-t')) document.getElementById('param-stroke-t').value = state.strokeWidthT;
  if (document.getElementById('param-stroke-slash')) document.getElementById('param-stroke-slash').value = state.strokeWidthSlash;
  if (document.getElementById('param-slash-len')) document.getElementById('param-slash-len').value = state.slashLength;
  if (document.getElementById('param-overhang-l')) document.getElementById('param-overhang-l').value = state.overhangL;
  if (document.getElementById('param-overhang-r')) document.getElementById('param-overhang-r').value = state.overhangR;
  if (document.getElementById('param-gap-tl-bar')) document.getElementById('param-gap-tl-bar').value = state.gapTLBar;
  if (document.getElementById('param-gap-tl-wall')) document.getElementById('param-gap-tl-wall').value = state.gapTLWall;
  if (document.getElementById('param-gap-br-wall')) document.getElementById('param-gap-br-wall').value = state.gapBRWall;
  if (document.getElementById('param-gap-br-bar')) document.getElementById('param-gap-br-bar').value = state.gapBRBar;
  if (document.getElementById('color-bamboo')) document.getElementById('color-bamboo').value = state.colorBamboo;
  if (document.getElementById('color-mustard')) document.getElementById('color-mustard').value = state.colorMustard;
  if (document.getElementById('color-bg')) document.getElementById('color-bg').value = state.colorBg;
}

function loadCustomPresets() {
  try {
    const saved = localStorage.getItem(PRESETS_STORAGE_KEY);
    if (saved) {
      customPresets = JSON.parse(saved);
    } else {
      customPresets = [];
    }
  } catch (e) {
    customPresets = [];
  }
  renderCustomPresets();
}

function saveCustomPresetsToStorage() {
  try {
    localStorage.setItem(PRESETS_STORAGE_KEY, JSON.stringify(customPresets));
  } catch (e) {
    console.warn('Unable to save custom presets:', e);
  }
}

function saveCurrentPreset() {
  const defaultName = `方案 ${customPresets.length + 1} (${new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })})`;
  const presetName = prompt('请输入自定义预设的名称:', defaultName);
  if (!presetName || !presetName.trim()) return;

  const newPreset = {
    id: 'preset_' + Date.now(),
    name: presetName.trim(),
    createdAt: new Date().toISOString(),
    state: JSON.parse(JSON.stringify(state))
  };

  customPresets.push(newPreset);
  saveCustomPresetsToStorage();
  renderCustomPresets();
}

function deleteCustomPreset(presetId, event) {
  if (event) event.stopPropagation();
  customPresets = customPresets.filter(p => p.id !== presetId);
  saveCustomPresetsToStorage();
  renderCustomPresets();
}

function applyCustomPreset(presetId) {
  const preset = customPresets.find(p => p.id === presetId);
  if (!preset) return;
  state = Object.assign(state, JSON.parse(JSON.stringify(preset.state)));
  syncInputsFromState();
  updateSVG();
}

function renderCustomPresets() {
  const container = document.getElementById('custom-presets-container');
  const list = document.getElementById('custom-presets-list');
  if (!container || !list) return;

  if (customPresets.length === 0) {
    container.classList.add('hidden');
    list.innerHTML = '';
    return;
  }

  container.classList.remove('hidden');
  list.innerHTML = customPresets.map(preset => `
    <div onclick="applyCustomPreset('${preset.id}')" class="group relative px-3 py-2 bg-slate-900 hover:bg-slate-800 border border-slate-800 hover:border-emerald-500/50 rounded-lg text-xs text-slate-200 transition-all cursor-pointer flex items-center justify-between shadow-sm">
      <div class="truncate pr-3">
        <span class="font-bold block text-emerald-400 truncate">${escapeHtml(preset.name)}</span>
        <span class="text-[9px] text-slate-400">已保存配置</span>
      </div>
      <button onclick="deleteCustomPreset('${preset.id}', event)" title="删除此预设" class="opacity-60 group-hover:opacity-100 p-1 text-slate-500 hover:text-rose-400 transition-opacity cursor-pointer">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
      </button>
    </div>
  `).join('');
}

function escapeHtml(str) {
  return str.replace(/[&<>"']/g, function(m) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[m];
  });
}
