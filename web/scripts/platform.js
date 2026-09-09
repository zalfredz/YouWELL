window.wellDownload = (name, base64, mime) => {
  const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
  const url = URL.createObjectURL(new Blob([bytes], {type: mime}));
  const a = document.createElement('a'); a.href = url; a.download = name; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
};
window.wellOpen = url => window.open(url, '_blank', 'noopener,noreferrer');
window.wellPhoto = () => new Promise(resolve => {
  const input = document.createElement('input'); input.type = 'file'; input.accept = 'image/jpeg,image/png,image/webp';
  input.oncancel = () => resolve('');
  input.onchange = () => {
    const file = input.files[0]; if (!file || file.size > 12000000) { resolve(''); return; }
    const reader = new FileReader(); reader.onerror = () => resolve('');
    reader.onload = () => {
      const image = new Image(); image.onerror = () => resolve('');
      image.onload = () => {
        const c = document.createElement('canvas'), scale = Math.min(1, 640 / Math.max(image.width, image.height));
        c.width = image.width * scale; c.height = image.height * scale;
        c.getContext('2d').drawImage(image, 0, 0, c.width, c.height);
        resolve(c.toDataURL('image/jpeg', .65));
      }; image.src = reader.result;
    }; reader.readAsDataURL(file);
  }; input.click();
});
let audio, sources = [], stops, soundGain, customTrack;
window.wellSound = name => {
  clearTimeout(stops); sources.forEach(s => { try { s.stop(); } catch (_) {} }); sources = [];
  if (customTrack) { customTrack.pause(); customTrack = null; }
  if (name === 'stop') return;
  audio ||= new (window.AudioContext || window.webkitAudioContext)(); audio.resume();
  const gain = audio.createGain(); soundGain = gain; gain.gain.value = name === 'release' ? .06 : .035; gain.connect(audio.destination);
  if (name === 'rain' || name === 'release') {
    const buffer = audio.createBuffer(1, audio.sampleRate * 3, audio.sampleRate);
    const values = buffer.getChannelData(0); for (let i=0;i<values.length;i++) values[i]=Math.random()*2-1;
    const source = audio.createBufferSource(); source.buffer = buffer; source.loop = true;
    const filter = audio.createBiquadFilter(); filter.type = 'lowpass'; filter.frequency.value = 1100;
    source.connect(filter); filter.connect(gain); source.start(); sources.push(source);
  } else {
    [174, 220, 261.63].forEach(f => { const s = audio.createOscillator(); s.frequency.value = f; s.type='sine'; s.connect(gain); s.start(); sources.push(s); });
  }
  if (name === 'release') stops = setTimeout(() => window.wellSound('stop'), 650);
};
window.wellSoundVolume = value => { if (soundGain) soundGain.gain.value = Math.max(0, Math.min(1, value)) * .12; if (customTrack) customTrack.volume = value; };
window.wellAudioPick = () => new Promise(resolve => {
  const input = document.createElement('input'); input.type = 'file'; input.accept = 'audio/*';
  input.oncancel = () => resolve('');
  input.onchange = () => {
    const file = input.files && input.files[0]; if (!file) { resolve(''); return; }
    const url = URL.createObjectURL(file); resolve(JSON.stringify({ name: file.name, url }));
  }; input.click();
});
window.wellCustomAudio = source => {
  window.wellSound('stop');
  if (customTrack) customTrack.pause();
  customTrack = new Audio(source); customTrack.loop = true; customTrack.volume = .35;
  customTrack.play().catch(() => {});
};
window.wellCustomAudioPause = () => { if (customTrack) customTrack.pause(); };
window.addEventListener('pagehide', () => window.wellSound('stop'));
