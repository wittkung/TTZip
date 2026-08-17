// TTZip App Icon Designer - Presets, Exports & Event Binding

function applyPreset(type) {
  if (type === 'standard') {
    state.strokeWidthT = 32;
    state.strokeWidthSlash = 32;
    state.slashLength = 100;
    state.lineCapT = 'round';
    state.lineCapSlash = 'round';
    state.overhangL = 30;
    state.overhangR = 30;
    state.gapTLBar = 40;
    state.gapTLWall = 40;
    state.gapBRWall = 40;
    state.gapBRBar = 40;
    state.liquidGlass = false;
    state.layered3DDepth = false;
    setLayerOrder('t-on-top');
  } else if (type === 'macos26-glass') {
    state.strokeWidthT = 34;
    state.strokeWidthSlash = 34;
    state.slashLength = 100;
    state.lineCapT = 'round';
    state.lineCapSlash = 'round';
    state.overhangL = 32;
    state.overhangR = 32;
    state.gapTLBar = 38;
    state.gapTLWall = 38;
    state.gapBRWall = 38;
    state.gapBRBar = 38;
    state.liquidGlass = true;
    state.layered3DDepth = true;
    setLayerOrder('t-on-top');
  } else if (type === 'sharp') {
    state.strokeWidthT = 32;
    state.strokeWidthSlash = 32;
    state.slashLength = 90;
    state.lineCapT = 'square';
    state.lineCapSlash = 'square';
    state.overhangL = 25;
    state.overhangR = 25;
    state.gapTLBar = 35;
    state.gapTLWall = 35;
    state.gapBRWall = 35;
    state.gapBRBar = 35;
    state.liquidGlass = false;
    state.layered3DDepth = false;
  } else if (type === 'bold') {
    state.strokeWidthT = 46;
    state.strokeWidthSlash = 46;
    state.slashLength = 115;
    state.lineCapT = 'round';
    state.lineCapSlash = 'round';
    state.overhangL = 45;
    state.overhangR = 45;
    state.gapTLBar = 50;
    state.gapTLWall = 50;
    state.gapBRWall = 50;
    state.gapBRBar = 50;
    state.liquidGlass = true;
    state.layered3DDepth = true;
  } else if (type === 'sleek') {
    state.strokeWidthT = 20;
    state.strokeWidthSlash = 20;
    state.slashLength = 85;
    state.lineCapT = 'round';
    state.lineCapSlash = 'round';
    state.overhangL = 20;
    state.overhangR = 20;
    state.gapTLBar = 30;
    state.gapTLWall = 30;
    state.gapBRWall = 30;
    state.gapBRBar = 30;
    state.liquidGlass = false;
    state.layered3DDepth = false;
  }

  syncInputsFromState();
  updateSVG();
}

function resetDefaults() {
  state.colorBamboo = '#789262';
  state.colorMustard = '#D4AF37';
  state.colorBg = '#F5F4F0';
  state.slashLength = 100;
  state.strokeWidthT = 32;
  state.strokeWidthSlash = 32;
  state.lineCapT = 'round';
  state.lineCapSlash = 'round';
  state.gapTLBar = 40;
  state.gapTLWall = 40;
  state.gapBRWall = 40;
  state.gapBRBar = 40;
  try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
  setThemeMode('light');
  applyPreset('standard');
}

// Export SVG File
function exportSVG() {
  const svgElement = document.getElementById('main-svg');
  const svgString = new XMLSerializer().serializeToString(svgElement);
  const blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  
  const themeSuffix = state.themeMode === 'light' ? 'Light' : 'Dark';
  const a = document.createElement('a');
  a.href = url;
  a.download = `TTZip_Icon_KintsugiGold_${themeSuffix}.svg`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// Export PNG File
function exportPNG(size = 1024) {
  const svgElement = document.getElementById('main-svg');
  const svgString = new XMLSerializer().serializeToString(svgElement);
  const svgBlob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
  const URLObj = window.URL || window.webkitURL || window;
  const blobURL = URLObj.createObjectURL(svgBlob);

  const themeSuffix = state.themeMode === 'light' ? 'Light' : 'Dark';
  const img = new Image();
  img.onload = function () {
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, size, size);
    
    const pngUrl = canvas.toDataURL('image/png');
    const a = document.createElement('a');
    a.href = pngUrl;
    a.download = `TTZip_AppIcon_${size}x${size}_${themeSuffix}.png`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URLObj.revokeObjectURL(blobURL);
  };
  img.src = blobURL;
}

// Bind Event Listeners & Initialize
function initEvents() {
  // Load saved parameters & custom presets from localStorage
  loadSavedState();
  syncInputsFromState();
  loadCustomPresets();

  document.getElementById('param-stroke-t').addEventListener('input', (e) => { state.strokeWidthT = parseInt(e.target.value); updateSVG(); });
  document.getElementById('param-stroke-slash').addEventListener('input', (e) => { state.strokeWidthSlash = parseInt(e.target.value); updateSVG(); });
  document.getElementById('param-slash-len').addEventListener('input', (e) => { state.slashLength = parseInt(e.target.value); updateSVG(); });
  document.getElementById('param-overhang-l').addEventListener('input', (e) => { state.overhangL = parseInt(e.target.value); updateSVG(); });
  document.getElementById('param-overhang-r').addEventListener('input', (e) => { state.overhangR = parseInt(e.target.value); updateSVG(); });
  
  document.getElementById('param-gap-tl-bar').addEventListener('input', (e) => { state.gapTLBar = parseInt(e.target.value); updateSVG(); });
  document.getElementById('param-gap-tl-wall').addEventListener('input', (e) => { state.gapTLWall = parseInt(e.target.value); updateSVG(); });
  document.getElementById('param-gap-br-wall').addEventListener('input', (e) => { state.gapBRWall = parseInt(e.target.value); updateSVG(); });
  document.getElementById('param-gap-br-bar').addEventListener('input', (e) => { state.gapBRBar = parseInt(e.target.value); updateSVG(); });

  document.getElementById('color-bamboo').addEventListener('input', (e) => { state.colorBamboo = e.target.value; updateSVG(); });
  document.getElementById('color-mustard').addEventListener('input', (e) => { state.colorMustard = e.target.value; updateSVG(); });
  document.getElementById('color-bg').addEventListener('input', (e) => { 
    state.colorBg = e.target.value; 
    const hex = e.target.value.toLowerCase();
    if (hex === '#000000' || hex === '#000') state.themeMode = 'dark-black';
    else if (hex === '#18181b' || hex === '#1a1a1a') state.themeMode = 'dark-slate';
    else if (hex === '#f5f4f0') state.themeMode = 'light';
    else state.themeMode = 'custom';
    updateSVG(); 
  });

  updateSVG();
}

// Safe DOM initialization
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initEvents);
} else {
  initEvents();
}
