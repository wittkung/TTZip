// TTZip App Icon Designer - Render Engine & SVG DOM Operations

function updateSVG() {
  const svgBg = document.getElementById('svg-bg');
  const svgLineZ = document.getElementById('svg-line-z');
  const svgTlBar = document.getElementById('svg-tl-bar');
  const svgTlWall = document.getElementById('svg-tl-wall');
  const svgBrBar = document.getElementById('svg-br-bar');
  const svgBrWall = document.getElementById('svg-br-wall');

  if (!svgBg || !svgLineZ || !svgTlBar) return;

  // Key Coordinates
  const L = state.boxLeft;
  const R = state.boxRight;
  const T = state.boxTop;
  const B = state.boxBottom;

  // Top-Left T Line Endpoints
  const tlBarX1 = L - state.overhangL;
  const tlBarX2 = R - state.gapTLBar;
  const tlWallY2 = B - state.gapTLWall;

  // Bottom-Right T Line Endpoints
  const brBarX1 = L + state.gapBRBar;
  const brBarX2 = R + state.overhangR;
  const brWallY1 = T + state.gapBRWall;

  // Update Top-Left Bar
  svgTlBar.setAttribute('x1', tlBarX1);
  svgTlBar.setAttribute('y1', T);
  svgTlBar.setAttribute('x2', tlBarX2);
  svgTlBar.setAttribute('y2', T);
  svgTlBar.setAttribute('stroke-width', state.strokeWidthT);
  svgTlBar.setAttribute('stroke-linecap', state.lineCapT);
  svgTlBar.setAttribute('stroke', state.colorBamboo);

  // Update Top-Left Wall
  svgTlWall.setAttribute('x1', L);
  svgTlWall.setAttribute('y1', T);
  svgTlWall.setAttribute('x2', L);
  svgTlWall.setAttribute('y2', tlWallY2);
  svgTlWall.setAttribute('stroke-width', state.strokeWidthT);
  svgTlWall.setAttribute('stroke-linecap', state.lineCapT);
  svgTlWall.setAttribute('stroke', state.colorBamboo);

  // Update Bottom-Right Bar
  svgBrBar.setAttribute('x1', brBarX1);
  svgBrBar.setAttribute('y1', B);
  svgBrBar.setAttribute('x2', brBarX2);
  svgBrBar.setAttribute('y2', B);
  svgBrBar.setAttribute('stroke-width', state.strokeWidthT);
  svgBrBar.setAttribute('stroke-linecap', state.lineCapT);
  svgBrBar.setAttribute('stroke', state.colorBamboo);

  // Update Bottom-Right Wall
  svgBrWall.setAttribute('x1', R);
  svgBrWall.setAttribute('y1', brWallY1);
  svgBrWall.setAttribute('x2', R);
  svgBrWall.setAttribute('y2', B);
  svgBrWall.setAttribute('stroke-width', state.strokeWidthT);
  svgBrWall.setAttribute('stroke-linecap', state.lineCapT);
  svgBrWall.setAttribute('stroke', state.colorBamboo);

  // Update Kintsugi Gold Z Line (with dynamic Slash Length scale)
  const cx = (L + R) / 2;
  const cy = (T + B) / 2;
  const slashScale = state.slashLength / 100;
  const halfDx = ((R - L) / 2) * slashScale;
  const halfDy = ((B - T) / 2) * slashScale;

  const zX1 = cx + halfDx;
  const zY1 = cy - halfDy;
  const zX2 = cx - halfDx;
  const zY2 = cy + halfDy;

  svgLineZ.setAttribute('x1', zX1);
  svgLineZ.setAttribute('y1', zY1);
  svgLineZ.setAttribute('x2', zX2);
  svgLineZ.setAttribute('y2', zY2);
  svgLineZ.setAttribute('stroke-width', state.strokeWidthSlash);
  svgLineZ.setAttribute('stroke-linecap', state.lineCapSlash);
  svgLineZ.setAttribute('stroke', state.colorMustard);

  // Update Layer Order in SVG Group
  const symbolGroup = document.getElementById('svg-symbol-group');
  if (symbolGroup && svgLineZ) {
    if (state.layerOrder === 't-on-top') {
      symbolGroup.insertBefore(svgLineZ, symbolGroup.firstChild);
    } else {
      symbolGroup.appendChild(svgLineZ);
    }
  }

  // Update Background Fill
  svgBg.setAttribute('fill', state.colorBg);

  // Update Liquid Glass Layer
  const glassOverlay = document.getElementById('glass-overlay');
  const glassShadingRect = document.getElementById('glass-shading-rect');
  const glassBevelRect = document.getElementById('glass-bevel-rect');
  const isDarkTheme = (state.themeMode === 'dark-black' || state.themeMode === 'dark-slate');

  if (glassOverlay) {
    glassOverlay.style.display = state.liquidGlass ? 'inline' : 'none';
  }
  if (glassShadingRect) {
    glassShadingRect.setAttribute('fill', isDarkTheme ? 'url(#glass-grad-dark)' : 'url(#glass-grad-light)');
  }
  if (glassBevelRect) {
    glassBevelRect.setAttribute('stroke', isDarkTheme ? 'url(#glass-border-dark)' : 'url(#glass-border-light)');
  }

  // Update 3D Layered Elevation Filter
  if (symbolGroup) {
    symbolGroup.setAttribute('filter', state.layered3DDepth ? 'url(#shadow-3d)' : 'url(#shadow)');
  }

  // Update UI Badges & Status Tags
  updateGlassUI();

  // Update Control Panel Text Displays
  if (document.getElementById('val-stroke-t')) document.getElementById('val-stroke-t').textContent = state.strokeWidthT + 'px';
  if (document.getElementById('val-stroke-slash')) document.getElementById('val-stroke-slash').textContent = state.strokeWidthSlash + 'px';
  if (document.getElementById('val-slash-len')) document.getElementById('val-slash-len').textContent = state.slashLength + '%';
  if (document.getElementById('val-overhang-l')) document.getElementById('val-overhang-l').textContent = state.overhangL + 'px';
  if (document.getElementById('val-overhang-r')) document.getElementById('val-overhang-r').textContent = state.overhangR + 'px';
  if (document.getElementById('val-gap-tl-bar')) document.getElementById('val-gap-tl-bar').textContent = state.gapTLBar + 'px';
  if (document.getElementById('val-gap-tl-wall')) document.getElementById('val-gap-tl-wall').textContent = state.gapTLWall + 'px';
  if (document.getElementById('val-gap-br-wall')) document.getElementById('val-gap-br-wall').textContent = state.gapBRWall + 'px';
  if (document.getElementById('val-gap-br-bar')) document.getElementById('val-gap-br-bar').textContent = state.gapBRBar + 'px';

  if (document.getElementById('text-bamboo')) document.getElementById('text-bamboo').textContent = state.colorBamboo.toUpperCase();
  if (document.getElementById('text-mustard')) document.getElementById('text-mustard').textContent = state.colorMustard.toUpperCase();
  if (document.getElementById('text-bg')) document.getElementById('text-bg').textContent = state.colorBg.toUpperCase();

  // Sync Active States on Buttons
  updateThemeUI();
  updateCapsUI();

  // Auto-save state to localStorage
  saveState();

  // Sync Dock Mini Preview
  syncMiniDock();
}

function toggleLiquidGlass() {
  state.liquidGlass = !state.liquidGlass;
  updateSVG();
}

function toggle3DDepth() {
  state.layered3DDepth = !state.layered3DDepth;
  updateSVG();
}

function updateGlassUI() {
  const glassBtn = document.getElementById('toggle-glass-btn');
  const depthBtn = document.getElementById('toggle-depth-btn');
  const glassBadge = document.getElementById('glass-badge');
  const depthBadge = document.getElementById('depth-badge');
  const tag = document.getElementById('glass-status-tag');

  if (glassBtn) {
    glassBtn.className = state.liquidGlass 
      ? "px-3 py-2 bg-slate-900 border border-cyan-500/50 text-cyan-300 rounded-lg text-xs text-left transition-all cursor-pointer flex items-center justify-between shadow-sm shadow-cyan-950"
      : "px-3 py-2 bg-slate-900 border border-slate-800 text-slate-400 rounded-lg text-xs text-left transition-all cursor-pointer flex items-center justify-between";
  }
  if (depthBtn) {
    depthBtn.className = state.layered3DDepth
      ? "px-3 py-2 bg-slate-900 border border-amber-500/50 text-amber-300 rounded-lg text-xs text-left transition-all cursor-pointer flex items-center justify-between shadow-sm shadow-amber-950"
      : "px-3 py-2 bg-slate-900 border border-slate-800 text-slate-400 rounded-lg text-xs text-left transition-all cursor-pointer flex items-center justify-between";
  }

  if (glassBadge) glassBadge.className = state.liquidGlass ? "w-2 h-2 rounded-full bg-cyan-400 shadow-sm shadow-cyan-500" : "w-2 h-2 rounded-full bg-slate-600";
  if (depthBadge) depthBadge.className = state.layered3DDepth ? "w-2 h-2 rounded-full bg-amber-400 shadow-sm shadow-amber-500" : "w-2 h-2 rounded-full bg-slate-600";

  if (tag) {
    if (state.liquidGlass && state.layered3DDepth) tag.textContent = 'Liquid Glass + 3D 分层已开启';
    else if (state.liquidGlass) tag.textContent = 'Liquid Glass 已开启';
    else if (state.layered3DDepth) tag.textContent = '3D 景深已开启';
    else tag.textContent = '经典平面矢量';
  }
}

function setThemeMode(mode) {
  state.themeMode = mode;
  if (mode === 'light') {
    state.colorBg = '#F5F4F0';
    setBambooMode('light');
    setKintsugiMode('light');
  } else if (mode === 'dark-black') {
    state.colorBg = '#000000';
    setBambooMode('dark');
    setKintsugiMode('dark');
  } else if (mode === 'dark-slate') {
    state.colorBg = '#18181B';
    setBambooMode('dark');
    setKintsugiMode('dark');
  }
  if (document.getElementById('color-bg')) document.getElementById('color-bg').value = state.colorBg;
  updateSVG();
}

function updateThemeUI() {
  const btnLight = document.getElementById('theme-btn-light');
  const btnDarkBlack = document.getElementById('theme-btn-dark-black');
  const btnDarkSlate = document.getElementById('theme-btn-dark-slate');
  const qLight = document.getElementById('quick-light-btn');
  const qDarkBlack = document.getElementById('quick-dark-black-btn');
  const tag = document.getElementById('current-theme-tag');

  const activeClass = "px-2.5 py-1.5 rounded-lg border text-xs font-medium flex items-center justify-center gap-1.5 transition-all cursor-pointer bg-slate-900 border-emerald-500/50 text-emerald-400 shadow-sm shadow-emerald-950";
  const inactiveClass = "px-2.5 py-1.5 rounded-lg border text-xs font-medium flex items-center justify-center gap-1.5 transition-all cursor-pointer bg-slate-900 border-slate-800 text-slate-400 hover:text-white";

  const quickActiveClass = "px-2.5 py-1 rounded text-xs font-medium transition-all cursor-pointer flex items-center gap-1 bg-emerald-500/20 text-emerald-400 border border-emerald-500/30";
  const quickInactiveClass = "px-2.5 py-1 rounded text-xs font-medium transition-all cursor-pointer flex items-center gap-1 text-slate-400 hover:text-white border border-transparent";

  if (btnLight) btnLight.className = (state.themeMode === 'light') ? activeClass : inactiveClass;
  if (btnDarkBlack) btnDarkBlack.className = (state.themeMode === 'dark-black') ? activeClass : inactiveClass;
  if (btnDarkSlate) btnDarkSlate.className = (state.themeMode === 'dark-slate') ? activeClass : inactiveClass;

  if (qLight) qLight.className = (state.themeMode === 'light') ? quickActiveClass : quickInactiveClass;
  if (qDarkBlack) qDarkBlack.className = (state.themeMode === 'dark-black') ? quickActiveClass : quickInactiveClass;

  if (tag) {
    if (state.themeMode === 'light') tag.textContent = '浅色模式 (#F5F4F0)';
    else if (state.themeMode === 'dark-black') tag.textContent = '深色模式 (纯黑 #000000)';
    else if (state.themeMode === 'dark-slate') tag.textContent = '深色模式 (石墨 #18181B)';
    else tag.textContent = '自定义底色 (' + state.colorBg.toUpperCase() + ')';
  }
}

function setBambooMode(mode) {
  state.bambooMode = mode;
  if (mode === 'light') {
    state.colorBamboo = '#789262';
  } else {
    state.colorBamboo = '#8FA876';
  }
  if (document.getElementById('color-bamboo')) document.getElementById('color-bamboo').value = state.colorBamboo;

  const btnLight = document.getElementById('bamboo-mode-light');
  const btnDark = document.getElementById('bamboo-mode-dark');
  if (btnLight && btnDark) {
    btnLight.className = (mode === 'light') ? "px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
    btnDark.className = (mode === 'dark') ? "px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
  }
  updateSVG();
}

function setKintsugiMode(mode) {
  state.kintsugiMode = mode;
  if (mode === 'light') {
    state.colorMustard = '#D4AF37';
  } else {
    state.colorMustard = '#E6C35C';
  }
  if (document.getElementById('color-mustard')) document.getElementById('color-mustard').value = state.colorMustard;

  const btnLight = document.getElementById('mode-light');
  const btnDark = document.getElementById('mode-dark');
  if (btnLight && btnDark) {
    btnLight.className = (mode === 'light') ? "px-2 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30 font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
    btnDark.className = (mode === 'dark') ? "px-2 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30 font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
  }
  updateSVG();
}

function setLayerOrder(order) {
  state.layerOrder = order;
  const btnTTop = document.getElementById('layer-t-top');
  const btnSlashTop = document.getElementById('layer-slash-top');
  if (btnTTop && btnSlashTop) {
    btnTTop.className = (order === 't-on-top') ? "px-2 py-0.5 rounded bg-[#789262] text-white font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
    btnSlashTop.className = (order === 'slash-on-top') ? "px-2 py-0.5 rounded bg-amber-500/80 text-white font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
  }
  updateSVG();
}

function setLineCapT(cap) {
  state.lineCapT = cap;
  updateSVG();
}

function setLineCapSlash(cap) {
  state.lineCapSlash = cap;
  updateSVG();
}

function updateCapsUI() {
  const btnTRound = document.getElementById('cap-t-round');
  const btnTSquare = document.getElementById('cap-t-square');
  const btnSlashRound = document.getElementById('cap-slash-round');
  const btnSlashSquare = document.getElementById('cap-slash-square');

  if (btnTRound && btnTSquare) {
    btnTRound.className = (state.lineCapT === 'round') ? "px-2 py-0.5 rounded bg-[#789262] text-white font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
    btnTSquare.className = (state.lineCapT === 'square') ? "px-2 py-0.5 rounded bg-[#789262] text-white font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
  }

  if (btnSlashRound && btnSlashSquare) {
    btnSlashRound.className = (state.lineCapSlash === 'round') ? "px-2 py-0.5 rounded bg-amber-500/80 text-white font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
    btnSlashSquare.className = (state.lineCapSlash === 'square') ? "px-2 py-0.5 rounded bg-amber-500/80 text-white font-medium cursor-pointer" : "px-2 py-0.5 rounded text-slate-400 hover:text-white cursor-pointer";
  }
}

function syncMiniDock() {
  const mainSvgContent = document.getElementById('main-svg').innerHTML;
  const dockSvg = document.getElementById('dock-mini-svg');
  const dockWrapper = document.getElementById('dock-icon-wrapper');
  if (dockSvg) {
    dockSvg.innerHTML = mainSvgContent;
  }
  if (dockWrapper) {
    dockWrapper.style.backgroundColor = state.colorBg;
  }
}
